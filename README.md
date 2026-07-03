# RTSP Camera Server

A camera **aggregation hub** for the edge, built on **MediaMTX**. It serves a
video source over **RTSP, WebRTC, and HLS** at the same time, so the same stream
can be consumed by browsers *and* by applications such as AI/ML inspection
pipelines.

## What works today

- **MediaMTX streaming hub**, run with Docker Compose.
- Three sources, each served over RTSP/WebRTC/HLS at once:
  - **`demo`** — a synthetic test pattern (no hardware).
  - **`virtualcam`** — loops a video file from `media/`, a stand-in camera (no hardware).
  - **`usbcam`** — a physical USB webcam (needs a camera + device passthrough).
- **Remote access** from another PC or network, over Tailscale.
- A standalone virtual-camera script: [`utils/virtual_rtsp_camera.sh`](utils/virtual_rtsp_camera.sh).

```
source ─▶ MediaMTX ─▶ RTSP (apps / OpenCV / AI) · WebRTC (browser) · HLS (browser)
```

## Quick start

```bash
cp .env.example .env        # adjust ports if needed
docker compose up -d        # starts MediaMTX
```

Verify the synthetic **demo** stream (a test pattern, no hardware needed):

- RTSP:  `rtsp://localhost:8554/demo`
- WebRTC: http://localhost:8889/demo
- HLS:   http://localhost:8888/demo

### Virtual camera (loop a video file)

The hub also has a **`virtualcam`** path that loops a clip from `media/`:

```bash
utils/virtual_rtsp_camera.sh --make-sample   # or drop your own .mp4 in media/
VIRTUALCAM_FILE=sample.mp4 docker compose up -d
ffplay -rtsp_transport tcp rtsp://localhost:8554/virtualcam
```

See [Virtual camera](docs/virtual-camera.md). To consume from another PC or
network, see [Remote access](docs/remote-access.md).

## Documentation

- [Getting started](docs/getting-started.md)
- [Virtual camera](docs/virtual-camera.md) — hardware-free looping-video source
- [USB camera](docs/usb-camera.md) — stream a physical USB webcam
- [Tailscale setup](docs/tailscale-setup.md) — install, log in, and stream over a mesh VPN (step by step)
- [Remote access](docs/remote-access.md) — reach streams from another PC / network (Tailscale)
- [GitHub repository configuration](docs/github/github-branch-protection.md)
- [GitHub Actions](docs/github/Github_Actions.md)

## Contributing

1. Create short-lived feature branches from the protected base branch.
2. Use commit messages like `[SUBSYSTEM] action: description`.
3. Open a PR with the provided template and apply `type_*`, `sys_*`, and
   `PRIORITY_*` labels.
4. Request review and resolve all conversations before merge.
5. Use squash or rebase merge only; merge commits stay disabled.

See [`AGENTS.md`](AGENTS.md) for the full Git/GitHub conventions.
