# Tailscale Setup — install, log in, and stream

Step-by-step instructions to reach the hub's streams (including the `usbcam`
path) from another PC on any network, over a [Tailscale](https://tailscale.com)
mesh VPN. No port forwarding, encrypted end to end, and — unlike an HTTP tunnel —
it carries **RTSP** as well as WebRTC and HLS.

For the *why* and deeper troubleshooting, see [Remote access](remote-access.md).

## Prerequisites

- The hub is already running: `docker compose up -d` (see the [README](../README.md)).
- A Tailscale account (free) and, optionally, a pre-generated **auth key** for
  non-interactive login (admin console → Settings → Keys → *Generate auth key*).
- `sudo` on each machine — install and `tailscale up` require root.

## 1. Install Tailscale (hub AND each consumer)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale version        # confirm it installed
```

## 2. Log in / connect

Pick one:

**Interactive** — prints a URL; open it in a browser and authenticate:

```bash
sudo tailscale up
```

**Non-interactive** — with a pre-generated auth key (good for headless hubs):

```bash
sudo tailscale up --auth-key=tskey-auth-XXXXXXXXXXXX
```

> Treat the auth key like a password. After the machine is registered, revoke or
> rotate the key in the admin console (Settings → Keys). One-time keys expire
> after first use; reusable keys should be rotated.

Log **every** machine into the **same Tailscale account** — that removes all
sharing/ACL steps. (Different accounts? See *Cross-account* below.)

## 3. Find the hub's Tailscale IP

On the hub:

```bash
tailscale ip -4          # e.g. 100.121.97.59
tailscale status         # lists every device on the tailnet
```

Use this `100.x.y.z` IP in the stream URLs below.

## 4. Stream from any consumer

No hub config change is needed — MediaMTX already listens on all interfaces
(host networking), so every path is reachable at the hub's Tailscale IP.

| Consumer | Protocol | URL |
|----------|----------|-----|
| Browser, low latency | WebRTC | `http://100.x.y.z:8889/usbcam` |
| Browser, wide compatibility | HLS | `http://100.x.y.z:8888/usbcam` |
| App / OpenCV / AI pipeline | RTSP | `rtsp://100.x.y.z:8554/usbcam` |

Swap `usbcam` for `demo` or `virtualcam` to reach the other sources.

Command-line check:

```bash
ffplay -rtsp_transport tcp rtsp://100.x.y.z:8554/usbcam
```

OpenCV — force TCP for a robust link over a long/relayed path:

```python
import cv2, os
os.environ["OPENCV_FFMPEG_CAPTURE_OPTIONS"] = "rtsp_transport;tcp"
cap = cv2.VideoCapture("rtsp://100.x.y.z:8554/usbcam", cv2.CAP_FFMPEG)
```

## 5. Verify connectivity

```bash
tailscale ping 100.x.y.z         # direct = peer-to-peer; via DERP(...) = relayed (still works)
curl -sI http://100.x.y.z:8888/usbcam/index.m3u8   # HLS reachable over the tailnet
```

## Cross-account (consumer on a different tailnet)

If a consumer is on a **different** Tailscale account, share the hub to it:

- Admin console → Machines → the hub → *Share…* → send the link → the other
  side **accepts**. Sharing is **one-directional**.
- Across a share, use the **`100.x.y.z` IP**, not the MagicDNS name.
- If you use custom ACLs, allow the stream ports for that user:

  ```json
  { "action": "accept", "src": ["them@example.com"],
    "dst": ["100.x.y.z:8554", "100.x.y.z:8888", "100.x.y.z:8889", "100.x.y.z:8189"] }
  ```

## Keep it reliable

- **Disable key expiry** on an always-on hub (admin console → the machine →
  *Disable key expiry*) so it doesn't drop off the tailnet every ~6 months.
- **Keep the hub awake** — no host sleep/suspend, or the stream drops.
- **Don't run `tailscale serve --tcp=8554 …`** — it squats the port and wraps
  RTSP in TLS, breaking plain RTSP and blocking MediaMTX. Prefer direct access;
  clear a stray rule with `sudo tailscale serve reset`.
- **Mind bandwidth over distance** — a cross-planet link works (~150–300 ms);
  keep the stream bitrate within both ends' upload/download.
