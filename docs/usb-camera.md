# USB Camera

Stream a physical USB webcam through the hub. MediaMTX reads the camera with
ffmpeg on demand and re-serves it over RTSP/WebRTC/HLS at the `usbcam` path,
exactly like the other sources.

> Requires a **Linux host with a USB camera**. This path can't be exercised on a
> machine without a camera — `demo` and `virtualcam` cover that case.

## 1. Find your camera device

```bash
ls /dev/video*                 # e.g. /dev/video0, /dev/video1
v4l2-ctl --list-devices        # optional, nicer output (sudo apt install v4l-utils)
```

Note the device node (usually `/dev/video0`).

## 2. Pass the device into the container

The hub can't see host hardware unless it's mapped in. In
[`docker-compose.yml`](../docker-compose.yml), **uncomment** the `devices:` block
under the `mediamtx` service and set it to your node:

```yaml
    devices:
      - /dev/video0:/dev/video0
```

> Keep it commented when you have no camera — Docker refuses to start if the
> device node doesn't exist.

If your node isn't `/dev/video0`, change it **both** here and in the `usbcam`
`runOnDemand` command in [`config/mediamtx.yml`](../config/mediamtx.yml).

## 3. Start and view

```bash
docker compose up -d
ffplay -rtsp_transport tcp rtsp://localhost:8554/usbcam
```

| Protocol | URL |
|----------|-----|
| RTSP (apps / OpenCV / AI) | `rtsp://localhost:8554/usbcam` |
| WebRTC (browser) | http://localhost:8889/usbcam |
| HLS (browser) | http://localhost:8888/usbcam |

The stream starts on demand when the first client connects (1–2s to spin up) and
stops ~10s after the last client leaves.

## Troubleshooting

- **`/dev/video0: No such file or directory`** — the device isn't passed in
  (step 2) or the node is wrong (step 1).
- **Immediate failure / bad pixel format** — many webcams output MJPEG. Add
  `-input_format mjpeg` before `-i /dev/video0` in the `usbcam` command in
  `config/mediamtx.yml`.
- **Permission denied on the device** — add your user to the `video` group:
  `sudo usermod -aG video "$USER"` (log out/in), or check the device permissions.
- **Wrong resolution / frame rate** — set them explicitly, e.g.
  `-video_size 1280x720 -framerate 30` before `-i`.
- **Multiple cameras** — add another path (copy the `usbcam` block, rename it,
  point it at `/dev/video1`) and map that device too.

## Remote access

To consume the USB stream from another PC or network, it's the same as any other
path — see [Remote access](remote-access.md): `rtsp://<tailscale-ip>:8554/usbcam`.
