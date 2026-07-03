# Multiple Cameras (one stream per media file)

The hub streams **every video file in `media/` as its own camera**, all on the
same server and port, distinguished by path — the same "channel" model a real
NVR uses. A clip named `media/video1.mp4` is served at the path
`media/video1.mp4` over all three protocols at once:

| Protocol | URL |
|----------|-----|
| RTSP (apps / OpenCV / AI) | `rtsp://<host>:8554/media/video1.mp4` |
| WebRTC (browser, low latency) | `http://<host>:8889/media/video1.mp4/` |
| HLS (browser / wide compat) | `http://<host>:8888/media/video1.mp4/index.m3u8` |

No per-file configuration is needed — any `*.mp4`, `*.mkv`, `*.mov`, `*.avi`,
or `*.webm` dropped into `media/` gets a stream automatically.

## Quick start

```bash
docker compose up -d                # starts mediamtx + media_publisher

# List the live streams:
curl -s http://localhost:9997/v3/paths/list | \
  python3 -c "import json,sys; [print(p['name']) for p in json.load(sys.stdin)['items'] if p['ready']]"

ffplay -rtsp_transport tcp rtsp://localhost:8554/media/sample.mp4
```

## Adding / removing clips

Drop files into `media/` (video files are gitignored), then restart the
publisher so it rescans the folder:

```bash
docker compose restart media_publisher
```

## How it works

Two cooperating pieces:

1. **Always-on publisher** — the `media_publisher` service in
   [`docker-compose.yml`](../docker-compose.yml) runs
   [`scripts/publish_media.sh`](../scripts/publish_media.sh), which starts one
   looping ffmpeg per file and pushes it to the hub at `media/<filename>`.
   Streams are live **whether or not anyone is watching**, and the service
   restarts with the stack (`restart: unless-stopped`). A crashed publisher is
   respawned after 2 s.

2. **On-demand fallback** — a regex path in
   [`config/mediamtx.yml`](../config/mediamtx.yml) (`~^media/(.+)$`) serves any
   `media/<file>` on demand if the publisher isn't running: MediaMTX spins up
   ffmpeg when the first client connects and stops it ~10 s after the last one
   leaves.

Both re-encode to H.264/AAC (`libx264 ultrafast` + `aac`) so timestamps stay
clean across loop boundaries and playback works in browsers regardless of the
source codec.

## Notes

- **CPU:** each active stream costs roughly one core for its x264 encode.
  Budget accordingly when adding many clips, or ask for stream-copy of
  already-H.264 files if CPU becomes the bottleneck.
- **Always-on vs on-demand:** if you don't need streams running without
  viewers, stop the publisher (`docker compose stop media_publisher`) — the
  on-demand regex path keeps every URL working, spinning streams up per client.
- **Single-clip alternative:** the original `virtualcam` path still loops one
  chosen clip (`VIRTUALCAM_FILE`); see [Virtual camera](virtual-camera.md).
- **Remote viewing:** replace `<host>` with the hub's LAN or Tailscale address;
  see [Remote access](remote-access.md).
