# Remote Access — consuming streams from another PC / another network

How to reach the hub from a second machine, including one on the other side of
the world.

## First: browsers can't play RTSP

There is no RTSP protocol in browsers. MediaMTX takes the **one** ingest and
re-serves it as **WebRTC** (low latency) and **HLS** (universal) as well as
**RTSP** — all at once. So the question isn't "which protocol", it's "how does
the network reach the hub":

- **App / OpenCV / AI pipeline** → RTSP (`rtsp://host:8554/<path>`)
- **Browser** → WebRTC (`http://host:8889/<path>`) or HLS (`http://host:8888/<path>`)

## Recommended: Tailscale (mesh VPN)

For "browser **and** an app on another PC on another network", the reliable
approach is the hub over a [Tailscale](https://tailscale.com) mesh VPN. It gives
every machine a stable private IP on one flat network, works across NAT with no
port-forwarding, is encrypted, and — unlike an HTTP tunnel — **carries RTSP**.

### Setup

```bash
# On the hub AND on each consumer machine:
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Find the hub's Tailscale IP: `tailscale ip -4` (e.g. `100.x.y.z`). Then from any
consumer, on any network:

```bash
ffplay -rtsp_transport tcp rtsp://100.x.y.z:8554/virtualcam     # app / RTSP
# browser: http://100.x.y.z:8888/virtualcam                      # HLS
```

In OpenCV, force TCP (more robust over a long/relayed link than the UDP default):

```python
import cv2, os
os.environ["OPENCV_FFMPEG_CAPTURE_OPTIONS"] = "rtsp_transport;tcp"
cap = cv2.VideoCapture("rtsp://100.x.y.z:8554/virtualcam", cv2.CAP_FFMPEG)
```

### Gotchas (learned in practice)

- **Two separate tailnets → use device sharing, and mind the direction.** If the
  consumer is on a *different* Tailscale account/tailnet, the hub must be
  **shared to it** (admin console → Machines → the hub → *Share…* → send link →
  the other side *accepts*). Sharing is **one-directional**: being able to reach
  *them* does **not** mean they can reach *you*. Symptom of the missing share:
  `tailscale ping` says **"no matching peer"**. Simpler alternative: put both
  machines on the **same tailnet** (log the consumer into the same account, or
  invite the other user), which removes all sharing/ACL steps.
- **Use the IP, not the name, across a share.** MagicDNS names resolve cleanly
  only within your own tailnet; across a share the bare name fails — use the
  `100.x.y.z` IP.
- **Custom ACLs must allow the port.** If a connection is refused/blocked after
  the peer is visible, grant the user access to the hub's stream ports:
  ```json
  { "action": "accept", "src": ["them@example.com"],
    "dst": ["100.x.y.z:8554", "100.x.y.z:8888", "100.x.y.z:8889"] }
  ```
  (Add `100.x.y.z:8189` too for low-latency WebRTC media, which uses UDP.)
- **Don't let another service squat on the port.** A leftover
  `tailscale serve --tcp=8554 …` rule binds the Tailscale IP's `:8554` and both
  (a) blocks MediaMTX from starting (`bind: address already in use`) and
  (b) wraps the port in TLS, breaking plain RTSP. Clear it with
  `sudo tailscale serve --tcp=8554 off` (or `sudo tailscale serve reset`). For
  this project, prefer **direct** access (no `serve`).
- **Disable key expiry on an always-on hub** (admin console → the machine →
  *Disable key expiry*) so it doesn't drop off the tailnet every ~6 months.
- **Distance = latency + bandwidth, not failure.** A cross-planet link works;
  expect ~150–300 ms and check `tailscale ping 100.x.y.z` — `via DERP(...)` means
  it's using a relay (fine for modest bitrates), `direct` is peer-to-peer. Keep
  the stream bitrate low enough for both ends' upload/download. The `virtualcam`
  path re-encodes at a modest rate, which helps.
- **The hub must stay awake.** No host sleep/suspend, or the stream drops.

## Which protocol from where

| Consumer | Protocol | URL |
|----------|----------|-----|
| App / OpenCV / AI pipeline | RTSP | `rtsp://100.x.y.z:8554/virtualcam` |
| Browser, low latency | WebRTC | `http://100.x.y.z:8889/virtualcam` |
| Browser, wide compatibility | HLS | `http://100.x.y.z:8888/virtualcam` |

> Note: an HTTP-only tunnel (e.g. Cloudflare) can expose HLS but **cannot carry
> RTSP**, which is why Tailscale is used here — it carries every protocol,
> including the RTSP that apps and AI pipelines need.
