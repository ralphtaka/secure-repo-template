# Security Baseline

## What this template keeps

### Baseline controls (enabled by default)
- Dependabot: opens update PRs for supported dependency ecosystems
- Dependency Review: blocks PRs that add vulnerable runtime dependencies
- Trivy PR scan: fails on HIGH / CRITICAL vulnerabilities and misconfigurations
- Gitleaks: detects likely secrets in pull requests and pushes to `main`
- Nightly Trivy: continues scanning after merge and uploads SARIF to GitHub code scanning
- Nightly dependency audit: stack-aware package vulnerability checks for Node/Python/Java
- SBOM: generates a software bill of materials for inventory and customer delivery
- CodeQL: language SAST workflow is applied by stack profile
- CI tests: language-specific CI workflow is applied by stack profile
- SECURITY.md: tells others how to report vulnerabilities
- GitHub Actions pinning: workflows use commit SHA instead of mutable tags
- Dependabot auto-merge policy: patch-level GitHub Actions updates can auto-merge after checks pass

### Docker control (optional)
- Container scan workflow is shipped as `.github/workflows/container-scan.yml.disabled`
- Rename it to `.github/workflows/container-scan.yml` only for Docker-based projects
- Dockerfile lint workflow is shipped as `.github/workflows/dockerfile-lint.yml.disabled`
- Enable branch protection checks `container-scan` and `dockerfile-lint` after turning Docker mode on

## Best fit
This package is best for:
- freelance client projects
- solo SaaS repos
- internal tools that ship with Docker

## Setup flow
1. `./scripts/bootstrap-project.sh --stack <node|python|java> --docker <on|off> --repo <owner/repo>`
2. Open one smoke PR and confirm checks.
