# media/

Video clips looped by the virtual camera (the hub's `virtualcam` path and
[`utils/virtual_rtsp_camera.sh`](../utils/virtual_rtsp_camera.sh)).

`sample.mp4` is committed as a ready-to-use test clip. Any other video file you
drop here (`*.mp4`, `*.mkv`, `*.mov`, `*.avi`, `*.webm`) is **gitignored** — keep
your own clips out of the repo.

## Quick start

```bash
# From the repo root — the hub loops the clip named by VIRTUALCAM_FILE:
VIRTUALCAM_FILE=sample.mp4 docker compose up -d
ffplay -rtsp_transport tcp rtsp://localhost:8554/virtualcam
```

Generate a fresh synthetic clip with `utils/virtual_rtsp_camera.sh --make-sample`.

Full details — changing the clip, how it works, and the standalone no-hub
script — are in [docs/virtual-camera.md](../docs/virtual-camera.md).
