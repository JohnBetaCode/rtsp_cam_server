#!/bin/sh
# Always-on multi-camera demo: publish every video in /media as a looping
# RTSP stream to MediaMTX, one path per file (media/<filename>).
#
# Runs as the `media_publisher` compose service. Streams stay live whether or
# not anyone is watching, unlike the on-demand paths in config/mediamtx.yml.
# Files are scanned once at startup — restart the service to pick up clips
# added later:  docker compose restart media_publisher
set -u

RTSP_PORT="${RTSP_PORT:-8554}"
RTSP_HOST="${RTSP_HOST:-localhost}"

publish() {
  file="$1"
  name="media/$(basename "$file")"
  while true; do
    ffmpeg -nostdin -loglevel error -re -stream_loop -1 -i "$file" \
      -c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -g 50 \
      -c:a aac -ar 48000 -b:a 128k \
      -f rtsp "rtsp://${RTSP_HOST}:${RTSP_PORT}/${name}" \
      && echo "publisher for ${name} exited cleanly" >&2 \
      || echo "publisher for ${name} died; restarting in 2s" >&2
    sleep 2
  done
}

found=0
for f in /media/*.mp4 /media/*.mkv /media/*.mov /media/*.avi /media/*.webm; do
  [ -e "$f" ] || continue
  found=1
  echo "publishing ${f} -> rtsp://${RTSP_HOST}:${RTSP_PORT}/media/$(basename "$f")" >&2
  publish "$f" &
done

if [ "$found" -eq 0 ]; then
  echo "no video files found in /media — nothing to publish" >&2
  exit 1
fi

wait
