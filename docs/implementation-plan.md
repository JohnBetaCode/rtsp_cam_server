# Implementation Plan — RTSP Camera Server

> Companion to [Project Context.md](Project%20Context.md). This document defines
> the architecture, file layout, and per-component design before coding begins.

## 1. High-level architecture

```
            ┌─────────────────────────────────────────────────────────┐
            │                     Host / Edge device                   │
            │            (x86 server  •  Jetson  •  Raspberry Pi)       │
            │                                                           │
  USB cams  │   /dev/video*  ─┐                                         │
            │                 │                                         │
            │                 ▼                                         │
            │        ┌──────────────────┐      control API (:9997)      │
            │        │     MediaMTX      │◀───────────────┐             │
 RTSP cams ─┼──────▶ │  (ingest + serve) │                │             │
 (native)   │        │  RTSP  WebRTC HLS │                │             │
            │        └──────────────────┘                │             │
            │           ▲   :8554/:8889/:8888             │             │
            │           │                          ┌──────────────┐     │
  virtual   │  ffmpeg drawtext ──(RTSP publish)──▶ │   FastAPI    │     │
  clock     │                                      │ control plane│     │
            │                                      │  + web UI    │     │
            │                                      │  Basic Auth  │     │
            │                                      └──────────────┘     │
            │                                            ▲ :8000        │
            └────────────────────────────────────────────┼─────────────┘
                                                          │
                              ┌───────────────────────────┴───────────┐
                              │            cloudflared tunnel          │
                              └───────────────────────────┬───────────┘
                                                          │
                  ┌───────────────────────────────────────┼───────────────┐
                  ▼                       ▼                ▼               ▼
            Browser (WebRTC)      Python client     AI/ML pipeline    Other apps
                                  (OpenCV RTSP)     (OpenCV RTSP)
```

**Key idea:** MediaMTX is the data plane (does all ingest and multi-protocol
serving); FastAPI is only the control plane (registers cameras, drives MediaMTX
via its HTTP API, serves the UI, enforces auth). Frame data never flows through
Python — that keeps it light enough for ARM edge devices.

## 2. How each source is ingested

| Source type | Mechanism | Why |
|-------------|-----------|-----|
| **Native RTSP camera** | MediaMTX path with `source: rtsp://<cam>` — MediaMTX pulls it directly. | Zero extra processes; most efficient. |
| **USB webcam** | MediaMTX path with `runOnDemand:` launching `ffmpeg -f v4l2 -i /dev/videoN ... -f rtsp rtsp://localhost:$RTSP_PORT/<path>`. Started only when a client connects. | No idle CPU; MediaMTX manages process lifecycle. |
| **Virtual clock** | `ffmpeg` with `drawtext` (live `localtime`) publishing to a MediaMTX path. Optional `v4l2loopback` variant for a real `/dev/videoN`. | Container-friendly default; loopback only when a real device node is required. |

> Note on the clock: the Project Context asks for a *virtual video device*. We
> provide **two modes**: (a) **RTSP-published clock** (default, no kernel module,
> works in containers/ARM) and (b) **v4l2loopback device** (`/dev/videoN`, needs
> the host module). Both are debug/example tools.

## 3. Multi-protocol output (served by MediaMTX)

| Protocol | Port | Consumer | URL shape |
|----------|------|----------|-----------|
| RTSP | 8554 | Python client, AI/ML (OpenCV) | `rtsp://host:8554/<path>` |
| WebRTC (WHEP) | 8889 | Browser UI | `http://host:8889/<path>/whep` |
| HLS | 8888 | Fallback / wide compatibility | `http://host:8888/<path>/index.m3u8` |

## 4. Proposed file layout

```
rtsp_cam_server/
├── README.md                      # high-level overview only (kept in sync)
├── docker-compose.yml             # mediamtx + app + cloudflared
├── .env.example                   # ports, auth creds, codec profile, tunnel token
├── .devcontainer/
│   ├── devcontainer.json
│   └── Dockerfile                 # multi-arch python + ffmpeg + v4l-utils
├── pyproject.toml                 # (or requirements.txt) deps + tooling
├── config/
│   ├── mediamtx.yml               # base MediaMTX config (paths added at runtime)
│   ├── cameras.yaml               # persisted camera registry (desired state)
│   └── cloudflared/               # tunnel config (gitignored secrets)
├── src/rtsp_cam_server/
│   ├── __init__.py
│   ├── main.py                    # FastAPI app factory, startup reconcile
│   ├── config.py                  # settings (pydantic-settings, env-driven)
│   ├── auth.py                    # HTTP Basic Auth dependency
│   ├── models.py                  # Camera schema (type=usb|rtsp|virtual)
│   ├── store.py                   # cameras.yaml load/save (persistence)
│   ├── mediamtx_client.py         # wrapper over MediaMTX control API (:9997)
│   ├── codecs.py                  # platform/codec profiles → ffmpeg args
│   ├── cameras.py                 # register/start/stop/reconcile logic
│   ├── api.py                     # REST routes (/api/cameras, /urls, /health)
│   └── web/
│       ├── templates/index.html   # camera list + WebRTC players
│       └── static/                # JS (WHEP player), CSS
├── scripts/
│   ├── virtual_clock.sh           # ffmpeg drawtext → RTSP publish (default)
│   ├── virtual_clock_v4l2.sh      # ffmpeg → /dev/videoN via v4l2loopback
│   ├── load_v4l2loopback.sh       # host helper to insmod the module
│   └── list_devices.sh            # enumerate /dev/video* + capabilities
├── examples/
│   ├── client_opencv.py           # connect to RTSP, read frames, demo loop
│   └── client_ai_inference.py     # OpenCV read → placeholder inference hook
└── docs/
    ├── Project Context.md
    ├── implementation-plan.md     # this file
    ├── getting-started.md         # install + run (local & docker)
    ├── deployment-arm.md          # Jetson / Raspberry Pi notes (hw codecs)
    ├── api.md                     # REST API reference
    └── public-exposure.md         # Cloudflare Tunnel setup
```

## 5. Component designs

### 5.1 FastAPI control plane (`src/rtsp_cam_server/`)
- **`config.py`** — `pydantic-settings`; reads `.env`: ports, `BASIC_AUTH_USER/PASS`,
  `MEDIAMTX_API_URL`, `CODEC_PROFILE` (`software` | `jetson` | `rpi`), `PUBLIC_HOST`.
- **`auth.py`** — `HTTPBasic` dependency applied to UI + API routers.
- **`models.py`** — `Camera{ id, name, type, source, enabled, codec_overrides }`.
- **`store.py`** — atomic read/write of `config/cameras.yaml` (desired state).
- **`mediamtx_client.py`** — `add_path/remove_path/list_paths` via MediaMTX
  `v3` control API; builds the path config (source or runOnDemand command).
- **`codecs.py`** — maps `CODEC_PROFILE` to ffmpeg input/encode args
  (`libx264` software; `nvv4l2*`/`nvenc` Jetson; `h264_v4l2m2m` Pi). Single place
  to keep the app codec-agnostic across architectures.
- **`cameras.py`** — orchestration: on register, persist + push path to MediaMTX;
  on startup, **reconcile** `cameras.yaml` → MediaMTX paths.
- **`api.py`** — routes below.

### 5.2 REST API
| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/health` | liveness + MediaMTX reachability |
| GET | `/api/cameras` | list registered cameras + status |
| POST | `/api/cameras` | register (usb/rtsp/virtual) |
| DELETE | `/api/cameras/{id}` | unregister + remove MediaMTX path |
| POST | `/api/cameras/{id}/enable` `/disable` | toggle |
| GET | `/api/cameras/{id}/urls` | RTSP / WebRTC / HLS URLs |
| GET | `/` | web UI (Basic Auth) |

### 5.3 Web UI
- Server-rendered `index.html` lists cameras; each card embeds the MediaMTX
  **WHEP** WebRTC player (vanilla JS, no heavy framework) + copy-able RTSP URL.

### 5.4 Python client examples (`examples/`)
- **`client_opencv.py`** — `cv2.VideoCapture(rtsp_url)` loop, FPS print, optional
  window/imwrite; CLI args for URL + Basic Auth creds.
- **`client_ai_inference.py`** — same capture loop with a clearly marked
  `run_inference(frame)` stub showing where an AI/ML model plugs in.

### 5.5 Streaming engine config (`config/mediamtx.yml`)
- Enable RTSP/WebRTC/HLS; expose control API on `:9997`; auth aligned with app;
  base file has no hard-coded paths (added at runtime by FastAPI).

### 5.6 Containerization & multi-arch
- **`.devcontainer/Dockerfile`** — `python:3.12-slim` (multi-arch) + `ffmpeg`,
  `v4l-utils`; installs app. Built for `linux/amd64,linux/arm64` via buildx.
- **`docker-compose.yml`** services:
  - `mediamtx` — `bluenviron/mediamtx:latest-ffmpeg` (multi-arch, ffmpeg bundled);
    `devices: /dev/video*`; mounts `config/mediamtx.yml`.
  - `app` — the FastAPI image; `MEDIAMTX_API_URL=http://mediamtx:9997`; port 8000.
  - `cloudflared` — `cloudflare/cloudflared`; tunnel token via env.
- ARM hardware codecs (Jetson L4T `nvenc`, Pi `h264_v4l2m2m`) selected purely via
  `CODEC_PROFILE` — no code changes; documented in `docs/deployment-arm.md`.

## 6. Build order (each step leaves a runnable state)
1. **Skeleton + MediaMTX** — compose with `mediamtx` only; verify a native RTSP
   source plays via RTSP/WebRTC/HLS.
2. **FastAPI control plane** — register/list cameras, Basic Auth, MediaMTX API
   wiring, `cameras.yaml` persistence + startup reconcile.
3. **USB ingest** — runOnDemand ffmpeg path; `list_devices.sh`.
4. **Web UI** — camera list + WHEP players.
5. **Virtual clock** — RTSP-published clock script (+ optional v4l2loopback).
6. **Python clients** — OpenCV consumer + inference stub.
7. **Cloudflare Tunnel** — compose service + docs.
8. **Multi-arch packaging** — buildx images, ARM codec profiles, ARM docs.
9. **README + docs** — keep root README high-level, details in `docs/`.

## 7. Confirmed decisions
- **MediaMTX integration:** runtime **control API** (`:9997`) — add/remove paths
  live, no restarts.
- **Persistence:** **`config/cameras.yaml`** (human-editable, fits tens of cameras).
- **Dependency tool:** **`pyproject.toml` managed with `uv`** (lockfile committed).
- **ARM targets:** design and document for **both NVIDIA Jetson and Raspberry Pi**
  equally from the start (codec profiles `jetson` and `rpi`).
```
