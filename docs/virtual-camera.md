# Virtual Camera (hardware-free test source)

The project ships a **virtual camera**: it loops a local video file and serves it
over RTSP/WebRTC/HLS, so the whole pipeline can be exercised without a physical
USB or RTSP camera. It behaves like a real camera to every downstream consumer.

There are **two ways** to run one. Use the first for normal work.

> **Want every file in `media/` streaming at once?** That's the multi-camera
> setup — one always-on stream per file at `media/<filename>` — covered in
> [Multiple cameras](multi-camera.md). `virtualcam` loops a *single* chosen clip.

---

## Method 1 (recommended): the hub's `virtualcam` path

The MediaMTX hub started by `docker compose` has a built-in `virtualcam` path
that loops a clip from the `media/` folder. This is the one to use — it serves
the clip on **all three protocols at once** and needs no extra process.

### Steps

```bash
# 1. Put an .mp4 in media/ (video files are gitignored). Or generate a test clip:
utils/virtual_rtsp_camera.sh --make-sample     # creates media/sample.mp4

# 2. Choose the clip (defaults to sample.mp4) and start the hub:
VIRTUALCAM_FILE=video1.mp4 docker compose up -d
```

### Watch it

| Protocol | URL |
|----------|-----|
| RTSP (apps / OpenCV / AI) | `rtsp://localhost:8554/virtualcam` |
| WebRTC (browser, low latency) | http://localhost:8889/virtualcam |
| HLS (browser / wide compat) | http://localhost:8888/virtualcam |

```bash
ffplay -rtsp_transport tcp rtsp://localhost:8554/virtualcam
```

### Change the clip

`VIRTUALCAM_FILE` selects the file (filename only — the folder is mounted at
`/media` inside the container). To make it stick across restarts and reboots,
set it in `.env`:

```bash
echo "VIRTUALCAM_FILE=video3.mp4" >> .env   # or edit the existing line
docker compose up -d
```

A running stream picks up the change on the **next client connect** (the
on-demand process restarts), or force it now with `docker compose restart mediamtx`.

### How it works

The path is defined in [`config/mediamtx.yml`](../config/mediamtx.yml). When the
first client connects, MediaMTX runs (on demand):

```
ffmpeg -re -stream_loop -1 -i /media/${VIRTUALCAM_FILE} \
       -c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -g 50 \
       -c:a aac -ar 48000 -b:a 128k \
       -f rtsp rtsp://localhost:$RTSP_PORT/$MTX_PATH
```

- `-stream_loop -1` loops the file forever; `runOnDemandRestart: yes` re-arms it.
- It **re-encodes** to H.264/AAC so timestamps stay clean across loop boundaries
  and the output is browser-friendly, regardless of the source clip's codec.
- `runOnDemandCloseAfter: 10s` stops ffmpeg ~10s after the last client leaves, so
  an idle hub uses no CPU. The first connect therefore takes 1–2s to spin up.

`docker-compose.yml` mounts `./media` read-only at `/media` and passes
`VIRTUALCAM_FILE` into the container.

---

## Method 2: the standalone script (no hub required)

[`utils/virtual_rtsp_camera.sh`](../utils/virtual_rtsp_camera.sh) runs a
**self-contained** virtual camera — its own throwaway MediaMTX RTSP server in a
container — without touching the project hub. Handy for a quick one-off stream or
when the hub isn't running.

```bash
cd utils
./virtual_rtsp_camera.sh --make-sample                 # create media/sample.mp4
./virtual_rtsp_camera.sh                                # loop newest media/*.mp4 on :8554
./virtual_rtsp_camera.sh -i ../media/video1.mp4 -m frontdoor -p 8555
./virtual_rtsp_camera.sh --stop                         # tear down
```

See `--help` for all options. Requirements are in
[`utils/requirements.txt`](../utils/requirements.txt) (Docker; ffmpeg only for
`--make-sample`).

> **Port note:** the standalone server defaults to `8554`, the same port as the
> hub. Don't run both on `8554` at once — stop one, or pass `-p 8555`.

> **Why a MediaMTX container and not bare `ffmpeg`?** `ffmpeg`'s own RTSP listen
> mode (`-rtsp_flags listen`) is missing/broken in many builds (it tries to
> *connect* instead of *listen*), so a real RTSP server is used instead.
