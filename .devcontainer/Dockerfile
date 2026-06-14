# Development environment for the RTSP Camera Server control plane.
#
# Multi-arch: python:3.12-slim has amd64 + arm64 variants, so this image also
# builds for NVIDIA Jetson / Raspberry Pi targets.
#
# This is the DEV image (interactive coding, tests, running the FastAPI app).
# The runtime streaming engine (MediaMTX) is a separate service in
# docker-compose.yml.
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    PATH="/opt/venv/bin:/root/.local/bin:$PATH"

# System deps:
#  - ffmpeg, v4l-utils : capture USB cameras, generate the virtual clock source
#  - git, curl, ca-certificates : tooling / uv install
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        v4l-utils \
        git \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast Python package manager).
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

WORKDIR /workspace

# Pre-install THIRD-PARTY dependencies for layer caching (copy only the
# manifest). We deliberately do NOT build/install the project itself here:
# --no-install-project skips it, since the package source is bind-mounted at
# runtime and editable-installed by postCreateCommand. The OpenCV client extra
# is included for the example clients.
COPY pyproject.toml ./
RUN uv sync --no-install-project --extra client

# Source is bind-mounted by devcontainer.json at runtime; this COPY is a
# fallback so the image is usable standalone too.
COPY . .

EXPOSE 8000
CMD ["bash"]
