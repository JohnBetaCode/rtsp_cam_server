# Getting Started

## Prerequisites

- **Docker** with the Compose plugin (`docker compose version`).

## 1. Configure

```bash
cp .env.example .env
```

Edit `.env` to set ports if the defaults clash. Defaults work for local testing.

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

## 4. Stream your own video (virtual camera)

To exercise the pipeline with real footage instead of the test pattern, the hub
has a **`virtualcam`** path that loops a clip from the `media/` folder:

```bash
# Drop an .mp4 in media/ (video files are gitignored), or make a test clip:
utils/virtual_rtsp_camera.sh --make-sample     # creates media/sample.mp4

# Pick the clip (default sample.mp4) and start:
VIRTUALCAM_FILE=sample.mp4 docker compose up -d

# Watch it (same three protocols as demo, path = virtualcam):
ffplay -rtsp_transport tcp rtsp://localhost:8554/virtualcam
```

Full details — changing the clip, how it works, and a standalone no-hub script —
are in [Virtual camera](virtual-camera.md).

## 5. Use a USB camera (optional)

If the host has a USB webcam, the hub can stream it at the **`usbcam`** path.
Uncomment the `devices:` block in `docker-compose.yml` to pass the camera in,
then:

```bash
docker compose up -d
ffplay -rtsp_transport tcp rtsp://localhost:8554/usbcam
```

Finding the device, MJPEG cameras, permissions, and multiple cameras are covered
in [USB camera](usb-camera.md).

## 6. Consume from another machine (Tailscale)

Streams reach another PC / network over a [Tailscale](https://tailscale.com) mesh
VPN — it carries RTSP (which an HTTP tunnel can't). Install it on the hub **and**
each consumer, bring it up, and note the hub's address:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale ip -4          # the hub's 100.x.y.z address
```

Then from the other machine:

```bash
ffplay -rtsp_transport tcp rtsp://100.x.y.z:8554/virtualcam
```

Cross-network sharing between different Tailscale accounts, ACLs, and other
gotchas are covered in [Remote access](remote-access.md).

## 7. Stop

```bash
docker compose down
```
