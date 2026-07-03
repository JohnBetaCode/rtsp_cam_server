#!/usr/bin/env bash
###############################################################################
# virtual_rtsp_camera.sh
#
# Turns a local video file into a virtual RTSP camera that loops forever, so the
# RTSP Camera Server can be developed and tested without real hardware.
#
# How it works:
#   It runs a tiny, self-contained MediaMTX RTSP server (the same
#   bluenviron/mediamtx:latest-ffmpeg image the project already uses) in its own
#   container. That server has a single path whose on-demand hook runs ffmpeg to
#   loop your video and publish it over RTSP. The result is a real RTSP endpoint
#   that behaves exactly like a native IP camera:
#
#       rtsp://localhost:<port>/<mount>
#
#   This is independent of the project's MediaMTX hub and touches none of its
#   configs. The hub can later ingest this virtual camera as an RTSP source,
#   just like it would a real one.
#
#   (We use MediaMTX rather than a bare `ffmpeg -rtsp_flags listen` server
#   because ffmpeg's RTSP listen mode is missing/broken in many builds.)
#
# The video lives in ../media (video files are gitignored). Drop your own clip
# there, or generate a synthetic test clip with:  ./virtual_rtsp_camera.sh --make-sample
#
# Requirements: docker; ffmpeg only for --make-sample (see utils/requirements.txt).
#
# Usage:
#   ./virtual_rtsp_camera.sh [options]
#
#   -i, --input FILE     Video file to loop. Default: newest *.mp4 in ../media
#   -m, --mount NAME     Stream path / mount name.           Default: virtualcam
#   -p, --port PORT      Host RTSP port to serve on.         Default: 8554
#       --copy           Copy codecs instead of re-encoding (needs H.264 source).
#       --no-audio       Drop the audio track.
#       --make-sample    Generate a 20s synthetic test clip into ../media and exit.
#       --stop           Stop and remove the virtual camera container and exit.
#   -h, --help           Show this help and exit.
#
# Examples:
#   ./virtual_rtsp_camera.sh --make-sample          # create media/sample.mp4
#   ./virtual_rtsp_camera.sh                          # serve newest media/*.mp4
#   ./virtual_rtsp_camera.sh -i ../media/loop.mp4 -m frontdoor -p 8555
#   ./virtual_rtsp_camera.sh --stop
#
# Watch it:
#   ffplay rtsp://localhost:8554/virtualcam
#   vlc    rtsp://localhost:8554/virtualcam
###############################################################################

set -euo pipefail

# ----- Constants / resolved paths --------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
MEDIA_DIR="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)/media"
IMAGE="bluenviron/mediamtx:latest-ffmpeg"
CONTAINER="rtsp_virtualcam"

# ----- Defaults --------------------------------------------------------------
INPUT=""
MOUNT="virtualcam"
PORT="8554"
COPY_CODECS=0
NO_AUDIO=0
MAKE_SAMPLE=0
STOP=0

# ----- Helpers ---------------------------------------------------------------
log()  { printf '\033[0;36m[virtual-cam]\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33m[virtual-cam]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[0;31m[virtual-cam] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,54p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

newest_mp4() {
  find "${MEDIA_DIR}" -maxdepth 1 -type f -name '*.mp4' -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -n1 | cut -d' ' -f2-
}

# ----- Parse arguments -------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input)    INPUT="${2:?--input needs a value}"; shift 2 ;;
    -m|--mount)    MOUNT="${2:?--mount needs a value}"; shift 2 ;;
    -p|--port)     PORT="${2:?--port needs a value}"; shift 2 ;;
    --copy)        COPY_CODECS=1; shift ;;
    --no-audio)    NO_AUDIO=1; shift ;;
    --make-sample) MAKE_SAMPLE=1; shift ;;
    --stop)        STOP=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *) die "Unknown option: $1 (use --help)" ;;
  esac
done

# ----- --stop: tear down and exit --------------------------------------------
if [[ "${STOP}" -eq 1 ]]; then
  command -v docker >/dev/null 2>&1 || die "docker not found."
  if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
    log "Stopping and removing container '${CONTAINER}'."
    docker rm -f "${CONTAINER}" >/dev/null
  else
    log "No '${CONTAINER}' container running."
  fi
  exit 0
fi

# ----- --make-sample: generate a synthetic clip and exit ---------------------
if [[ "${MAKE_SAMPLE}" -eq 1 ]]; then
  command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg not found on host (needed for --make-sample)."
  mkdir -p "${MEDIA_DIR}"
  SAMPLE="${MEDIA_DIR}/sample.mp4"
  log "Generating 20s synthetic test clip -> ${SAMPLE}"
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "testsrc=size=1280x720:rate=25" \
    -f lavfi -i "sine=frequency=1000:sample_rate=48000" \
    -t 20 -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac \
    "${SAMPLE}"
  log "Done. Serve it with: ${BASH_SOURCE[0]} -i ${SAMPLE}"
  exit 0
fi

command -v docker >/dev/null 2>&1 || die "docker not found. Install Docker (see utils/requirements.txt)."

# ----- Resolve the input video -----------------------------------------------
if [[ -z "${INPUT}" ]]; then
  INPUT="$(newest_mp4)"
  [[ -n "${INPUT}" ]] || die "No video given and no *.mp4 in ${MEDIA_DIR}.
Drop a clip there, pass -i FILE, or generate one with --make-sample."
  log "No --input given; using newest clip: ${INPUT}"
fi
[[ -f "${INPUT}" ]] || die "Input file not found: ${INPUT}"
INPUT_ABS="$(cd -- "$(dirname -- "${INPUT}")" && pwd)/$(basename -- "${INPUT}")"
INPUT_DIR="$(dirname -- "${INPUT_ABS}")"
INPUT_BASE="$(basename -- "${INPUT_ABS}")"

# ----- Build the ffmpeg codec string (runs inside the container) -------------
# Re-encoding (default) guarantees clean, monotonic timestamps across loop
# boundaries and browser-friendly H.264/AAC. --copy is cheaper but assumes the
# source is already H.264 (+ AAC) and can glitch at each loop restart.
if [[ "${COPY_CODECS}" -eq 1 ]]; then
  ENC="-c copy"
  [[ "${NO_AUDIO}" -eq 1 ]] && ENC="${ENC} -an"
else
  ENC="-c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -g 50"
  if [[ "${NO_AUDIO}" -eq 1 ]]; then
    ENC="${ENC} -an"
  else
    ENC="${ENC} -c:a aac -ar 48000 -b:a 128k"
  fi
fi

# ----- Generate a throwaway MediaMTX config ----------------------------------
# RTSP-only (TCP), all other protocols disabled. The path's on-demand hook loops
# the mounted video and publishes it back into this same server. $MTX_PATH is
# provided by MediaMTX at runtime; the server always listens on 8554 *inside*
# the container and is mapped to the chosen host port.
CFG="$(mktemp -t vcam-mediamtx-XXXXXX.yml)"
cleanup() {
  docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
  rm -f "${CFG}" 2>/dev/null || true
}
trap 'echo; log "Stopping."; cleanup; exit 0' INT TERM

cat > "${CFG}" <<EOF
logLevel: info
api: no
metrics: no
pprof: no
playback: no
rtmp: no
hls: no
webrtc: no
srt: no
rtsp: yes
rtspTransports: [tcp]
rtspAddress: :8554
paths:
  ${MOUNT}:
    runOnDemand: >
      ffmpeg -re -stream_loop -1 -i /media/${INPUT_BASE}
      ${ENC}
      -f rtsp -rtsp_transport tcp rtsp://localhost:8554/\$MTX_PATH
    runOnDemandRestart: yes
    runOnDemandCloseAfter: 10s
EOF

# ----- Pre-flight: warn on an occupied port ----------------------------------
if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ":${PORT}\b"; then
  die "Port ${PORT} is already in use (the project hub also uses 8554).
Stop that service or pick another port with -p, e.g. -p 8555."
fi

# ----- Run the virtual camera ------------------------------------------------
docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true

log "Virtual RTSP camera starting — looping: ${INPUT_ABS}"
log "Serving at:  rtsp://localhost:${PORT}/${MOUNT}"
log "Watch it:    ffplay rtsp://localhost:${PORT}/${MOUNT}"
log "Press Ctrl+C to stop."

# Foreground so Ctrl+C tears everything down via the trap. The stream starts
# on demand when the first client connects, then loops forever.
docker run --rm --name "${CONTAINER}" \
  -p "${PORT}:8554" \
  -v "${CFG}:/mediamtx.yml:ro" \
  -v "${INPUT_DIR}:/media:ro" \
  "${IMAGE}"

cleanup
