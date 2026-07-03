# media/

Video clips served by the hub. **Every file here becomes its own always-on
stream** at `media/<filename>` (the multi-camera demo), and one chosen file is
also looped by the `virtualcam` path and
[`utils/virtual_rtsp_camera.sh`](../utils/virtual_rtsp_camera.sh).

`sample.mp4` is committed as a ready-to-use test clip. Any other video file you
drop here (`*.mp4`, `*.mkv`, `*.mov`, `*.avi`, `*.webm`) is **gitignored** — keep
your own clips out of the repo.

## Quick start

```bash
# From the repo root — every clip in media/ streams at media/<filename>:
docker compose up -d                        # or restart media_publisher after adding files
ffplay -rtsp_transport tcp rtsp://localhost:8554/media/sample.mp4

# Single-clip virtual camera (loops the clip named by VIRTUALCAM_FILE):
VIRTUALCAM_FILE=sample.mp4 docker compose up -d
ffplay -rtsp_transport tcp rtsp://localhost:8554/virtualcam
```

Generate a fresh synthetic clip with `utils/virtual_rtsp_camera.sh --make-sample`.

Full details: [docs/multi-camera.md](../docs/multi-camera.md) (one stream per
file) and [docs/virtual-camera.md](../docs/virtual-camera.md) (single clip,
standalone no-hub script).
