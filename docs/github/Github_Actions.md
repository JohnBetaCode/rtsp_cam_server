# GitHub Actions

GitHub Actions automate repository checks, deployments, and integrations. Each
workflow is defined in `.github/workflows/*.yml` or `.github/workflows/*.yaml`.

## Current Workflows

This repository does not currently define GitHub Actions workflows.

## Recommended First Workflows

When the implementation grows beyond the current MediaMTX demo setup, add these
checks before requiring status checks in branch protection:

1. **Docker Compose validation**
   - Run `docker compose config`.
   - Verify the demo MediaMTX service definition is valid.

2. **Code quality checks**
   - Run formatter and lint checks if/when application code is added.

3. **Configuration and docs checks**
   - Validate YAML files.
   - Check Markdown formatting and links.

## Required Secrets

No GitHub Actions secrets are required yet.

When hosted deployment is added, store runtime values as GitHub Actions secrets
instead of committing them. Likely future examples:

- Deployment host credentials
- Registry credentials

## Local Debugging

You can debug GitHub Actions locally with `act` once workflows exist:

```bash
act --env LC_ALL=C.UTF-8 LANG=C.UTF-8 -j <workflow_name>
```

If the workflow needs secrets, pass them with `--secret`.
