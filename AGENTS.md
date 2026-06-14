# AGENTS.md

This file provides repository guidance for AI coding agents working in this
project.

## Project Overview

RTSP Camera Server is an edge camera aggregation hub. It ingests local USB
webcams and native RTSP cameras, then republishes streams over RTSP, WebRTC, and
HLS for browsers and downstream AI/ML inspection pipelines.

The current stack uses:

- MediaMTX for streaming protocols and stream lifecycle.
- FastAPI for the future control plane and web UI.
- Docker Compose for local service orchestration.
- Optional cloudflared exposure for public access without port forwarding.

## Common Commands

```bash
# Start the current MediaMTX demo service
docker compose up -d

# Stop the service
docker compose down

# Validate Docker Compose configuration
docker compose config

# Copy local environment defaults
cp .env.example .env

# Configure GitHub repository settings with gh after authenticating
bash scripts/configure_github_repo.sh
```

## Git And GitHub Rules

- Protect the default branch. Do feature work on short-lived branches and open a
  PR back to the protected base branch.
- Current default branch: `main`. If `develop` and `staging` branches are added
  later, follow the Rdog flow: branch from `develop`, integrate through
  `staging`, and keep `main` production-ready.
- Commit style: `[SUBSYSTEM] action: description`.
- Good examples:
  - `[DOCS] update GitHub setup guide`
  - `[STREAMING] fix MediaMTX demo path`
  - `[CONFIG] add cloudflared defaults`
  - `[API] add camera registration endpoint`
- Before committing, review `git status` and `git diff`, check for secrets, and
  run the relevant validation command for the touched area.
- Use PR labels from the `type_*`, `sys_*`, and `PRIORITY_*` groups.
- Request review before merge and resolve all review conversations.
- Merge strategy: squash or rebase only. Merge commits should stay disabled.
- Delete feature branches after merge.
- Never force-push protected branches or delete protected branches.

## GitHub CLI

GitHub CLI (`gh`) is expected to be available locally. If remote repository
configuration fails, run:

```bash
gh auth login -h github.com
gh auth status
```

Then apply the repo configuration:

```bash
bash scripts/configure_github_repo.sh
```

## Labels

Use these label groups for issues and pull requests:

- Type: `type_bug`, `type_feature`, `type_enhancement`, `type_hotfix`,
  `type_release`, `type_chore`, `type_docs`
- Priority: `PRIORITY_LOW`, `PRIORITY_MEDIUM`, `PRIORITY_HIGH`,
  `PRIORITY_SATANIC`
- System: `sys_streaming`, `sys_api`, `sys_config`, `sys_docs`, `sys_cicd`,
  `sys_other`
- State: `state_in_progress`, `state_tech_check`, `state_qa_check`,
  `state_ready_to_test`, `state_testing`
- Automation: `automerge`, `automergesquash`, `auto_generated`, `hold_on`

## Documentation

Keep GitHub governance docs in `docs/github/`. Templates live in `.github/`.
GitHub automatically picks up issue and pull request templates once they are
merged to the default branch.
