# RTSP Camera Server

A camera **aggregation hub** for the edge. It ingests local **USB webcams** and
**native RTSP cameras** and re-publishes them over **RTSP, WebRTC, and HLS** so
they can be consumed by browsers *and* by downstream applications such as
**AI/ML visual-reasoning / inspection pipelines**.

Designed to be easy to host on a server or on **ARM edge devices** (NVIDIA
Jetson, Raspberry Pi) installed in places with multiple cameras.

## Architecture (at a glance)

- **MediaMTX** — the streaming engine (ingest + multi-protocol serving).
- **FastAPI** — the control plane: register cameras, manage streams, web UI,
  Basic Auth. *(Frame data never flows through Python.)*
- **cloudflared** — optional public exposure with no port forwarding.

```
USB / RTSP cameras ─▶ MediaMTX ─▶ RTSP (OpenCV/AI) · WebRTC (browser) · HLS
                         ▲
                      FastAPI (control plane + UI)
```

## Quick start

```bash
cp .env.example .env        # adjust ports / credentials
docker compose up -d        # starts MediaMTX
```

Then verify the synthetic demo stream:

- RTSP:  `rtsp://localhost:8554/demo`
- WebRTC: http://localhost:8889/demo
- HLS:   http://localhost:8888/demo/index.m3u8

## Documentation

All setup and usage instructions live in [`docs/`](docs/):

- [Getting started](docs/getting-started.md)
- [Project context](docs/Project%20Context.md)
- [Implementation plan](docs/implementation-plan.md)
- [GitHub repository configuration](docs/github/github-branch-protection.md)
- [GitHub Actions](docs/github/Github_Actions.md)

## Contributing

Use the same GitHub flow copied from the Rdog repository:

1. Create short-lived feature branches from the protected base branch.
2. Use commit messages like `[SUBSYSTEM] action: description`.
3. Open a PR with the provided template and apply `type_*`, `sys_*`, and
   `PRIORITY_*` labels.
4. Request review and resolve all conversations before merge.
5. Use squash or rebase merge only; merge commits stay disabled.

> Status: **Step 1 of the build plan** — MediaMTX streaming engine running with a
> verifiable demo source. Control plane, cameras, clients, tunnel, and multi-arch
> packaging follow in subsequent steps.
