# Getting Started

## Prerequisites

- **Docker** with the Compose plugin (`docker compose version`).
- A Linux host (required later for USB / `v4l2loopback` camera passthrough).

## 1. Configure

```bash
cp .env.example .env
```

Edit `.env` to set ports and the Basic Auth credentials. Defaults work for local
testing.

## 2. Start the streaming engine

```bash
docker compose up -d
docker compose ps
docker compose logs -f mediamtx
```

This starts **MediaMTX** with a synthetic `demo` source (a test pattern), which
lets you verify the whole pipeline without a real camera.

## 3. Verify the demo stream

The `demo` path starts **on demand** — it begins streaming as soon as a client
connects.

| Protocol | How to test |
|----------|-------------|
| **WebRTC** (browser) | Open <http://localhost:8889/demo> |
| **HLS** (browser/player) | Open <http://localhost:8888/demo/index.m3u8> |
| **RTSP** (ffplay/VLC) | `ffplay rtsp://localhost:8554/demo` |
| **RTSP** (OpenCV) | `python -c "import cv2; c=cv2.VideoCapture('rtsp://localhost:8554/demo'); print(c.read()[0])"` |

You should see a moving colour test pattern (and hear a 1 kHz tone on protocols
that carry audio).

## 4. Stop

```bash
docker compose down
```

## Next steps

The FastAPI control plane, real USB/RTSP camera registration, the virtual clock
source, Python client examples, the Cloudflare tunnel, and multi-arch packaging
are added in later build steps — see the
[implementation plan](implementation-plan.md).
