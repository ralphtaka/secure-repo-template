# Docker Security Add-on

This repository ships Docker scanning as an optional module.

## Why optional
- Not every client project builds Docker images.
- Keeping it disabled by default avoids noisy failures in non-Docker repos.

## How to enable
1. Rename `.github/workflows/container-scan.yml.disabled` to `.github/workflows/container-scan.yml`.
2. Commit and push.
3. Trigger the workflow once with `workflow_dispatch` and confirm it passes.
4. Rename `.github/workflows/dockerfile-lint.yml.disabled` to `.github/workflows/dockerfile-lint.yml`.
5. Add `container-scan` and `dockerfile-lint` to required checks on `main` if Docker is part of release.

## Expected prerequisites
- A valid `Dockerfile` at repo root.
- Runner can build image without private base image auth issues.
- GitHub code scanning is enabled if you want SARIF alerts in Security tab.

## Operational guidance
- Keep `.trivyignore` small and documented.
- Prefer fixing HIGH/CRITICAL findings over suppressing.
- Re-run scans after base image updates.
