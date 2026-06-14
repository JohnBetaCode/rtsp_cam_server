# Project Context — RTSP Camera Server

## Goal

Build an application that turns a machine into an RTSP camera server / camera
aggregation hub: it ingests local USB webcams and native RTSP cameras and
re-publishes them through standard streaming protocols so they can be consumed
by many kinds of clients — a browser is only one of them.

The real purpose is to act as a **camera gateway for downstream AI/ML
applications** (e.g. visual reasoning, inspection, monitoring). It must be easy
to **host and deploy on a server or on embedded devices** installed in places
that have multiple USB or RTSP cameras, redirecting those streams to other
applications.

## Functional Requirements

1. **USB webcam → local RTSP**
   Read a USB webcam (`/dev/video*`) and expose it as an RTSP stream locally.

2. **Local RTSP → public / multi-client access**
   If one or several local RTSP cameras exist, expose them so they can be
   accessed remotely (potentially from anywhere in the world). The machine
   running this application acts as the server that performs the handshake
   between the client and the camera — whether the camera is natively RTSP or
   virtually exposed as RTSP here through another process. Consumers are not
   limited to browsers: other applications (including AI/ML pipelines) should be
   able to pull the streams too.

3. **Python client example**
   Provide an example Python client file that connects to the server and
   consumes a stream, demonstrating how a downstream application (e.g. an AI/ML
   inspection pipeline) would integrate with the server.

4. **Virtual clock video device (debug / example only)**
   Create a script that generates a virtual clock with dynamic date and time and
   exposes it as a virtual video device. This exists **for debugging and as a
   built-in example source** for the repo (so the app can be demonstrated
   without a physical camera) — it is not a core production feature.

5. **Project structure**
   Properly structure scripts, documentation, and other utilities within the
   project's layout.

6. **Documentation**
   Keep the root `README.md` updated on every change, but the detailed
   instructions for using the repo must live in the `docs/` folder.

7. **Easy hosting & deployment**
   The application must be easy to host and deploy on a server or on embedded
   devices, in locations with multiple USB/RTSP cameras, to redirect streams to
   downstream AI/ML applications.

## Requirements

1. Containerize the application with Docker inside a `.devcontainer/` folder, and
   also provide the Docker Compose YAML.

## Decisions (chosen)

| Area | Decision |
|------|----------|
| Orchestration stack | **Python (FastAPI)** — backend, control API, and web UI; controls `ffmpeg`/MediaMTX via subprocess. |
| Streaming engine | **MediaMTX** — multi-protocol: ingests RTSP/USB and serves RTSP, WebRTC, HLS from one binary. |
| Browser playback | **WebRTC** — sub-second latency for live monitoring in the browser. |
| Programmatic consumers | **RTSP via OpenCV (`cv2.VideoCapture`)** is the primary interface for the Python client and downstream AI/ML pipelines; HLS is the fallback. |
| Public exposure | **Tunnel (Cloudflare/ngrok)** — no public IP or port forwarding required. |
| Access control | **HTTP Basic Auth** on the UI and streams. |
| Target hardware | **ARM platforms** — NVIDIA Jetson and Raspberry Pi — in addition to x86 servers. Builds must be multi-arch (`linux/arm64`, `linux/amd64`); base images must have ARM variants. |

## Architecture Notes & Gotchas

- **Browsers cannot play raw RTSP** → MediaMTX re-publishes RTSP sources as
  WebRTC for the browser.
- **`v4l2loopback`** (used for the virtual clock device) is a *host kernel
  module* — it must be loaded on the host; the container only mounts the
  resulting `/dev/videoN` device. This shapes the devcontainer/compose design.
- **Docker Compose** must pass through `/dev/video*` devices for USB and virtual
  cameras.
- The USB-camera and v4l2loopback flows can only be truly tested on a Linux host
  with a real webcam and the kernel module loaded.
- **ARM deployment targets** (NVIDIA Jetson, Raspberry Pi): all images must be
  built multi-arch. On Jetson, hardware-accelerated encode/decode uses NVIDIA's
  L4T stack (`nvv4l2` / `nvenc`) rather than generic `ffmpeg` software codecs;
  on Raspberry Pi, prefer hardware H.264 where available to keep CPU usage low.
  Keep codec selection configurable so the same app runs on x86 (software) and
  ARM (hardware) without code changes.

## Proposed Project Structure

```
rtsp_cam_server/
├── .devcontainer/        # Dockerfile + devcontainer config
├── docker-compose.yml    # MediaMTX, FastAPI app, Cloudflare Tunnel services
├── src/ (or app/)        # FastAPI app: control API + web UI
├── scripts/              # virtual clock (debug/example), v4l2 helpers, utilities
├── examples/             # Python client example consuming a stream (AI/ML integration)
├── config/               # MediaMTX config, tunnel config, cameras.yaml
├── docs/                 # all setup & usage instructions
└── README.md             # high-level overview only
```

## Suggested Build Order

1. USB → RTSP → WebRTC locally, with Basic Auth.
2. Virtual clock video device (debug/example source).
3. External/native RTSP source registration.
4. Python client example consuming a stream (RTSP/HLS).
5. Cloudflare Tunnel public exposure.
6. Docker / devcontainer / compose packaging for easy server/embedded deployment.

(Each step should leave the project in a runnable state.)

## Open Items

- Camera-list persistence: suggested **`config/cameras.yaml`** (vs. SQLite or
  in-memory).
- Deployment targets confirmed: x86 Linux servers + **ARM64** (NVIDIA Jetson,
  Raspberry Pi). Decide which Jetson/Pi models to validate against first.
