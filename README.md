# Freelancer DevSecOps Template - Practical Baseline

A practical GitHub security baseline for freelancers and solo developers.

## Included

### Baseline controls (enabled by default)
- Dependabot: automatic dependency update PRs
- Dependency Review: blocks PRs that introduce vulnerable runtime dependencies
- Trivy PR scan: scans vulnerabilities and misconfigurations
- Gitleaks: secret scanning on pull requests and pushes to `main`
- Nightly Trivy SARIF upload: post-merge continuous scanning in GitHub code scanning
- SBOM generation: software bill of materials after pushes to `main`
- SECURITY.md: vulnerability disclosure policy
- GitHub Actions pinning: workflows use commit SHA references

### Optional Docker module (disabled by default)
- Container image scan workflow is included as `.github/workflows/container-scan.yml.disabled`
- Enable it only for repositories that build and ship Docker images

## Required GitHub settings

### Security features
Enable:
- Dependency graph
- Dependabot alerts
- Dependabot security updates
- Secret scanning (if available on your plan)
- Code scanning (if available on your plan, required for SARIF upload visibility)

### Branch protection for `main`
Require these status checks:
- dependency-review
- trivy-pr
- gitleaks

Recommended:
- Require pull request before merge
- Block force pushes and branch deletion

## Enable Docker scan when needed
1. Rename `.github/workflows/container-scan.yml.disabled` to `.github/workflows/container-scan.yml`.
2. Verify your `Dockerfile` builds successfully in CI (`docker build .`).
3. If Docker is mandatory in the project, add `container-scan` to required status checks on `main`.
4. If needed, track accepted risks in `.trivyignore` with ticket/justification.

## Project kickoff checklist
- Use [`docs/client-project-kickoff-checklist.md`](docs/client-project-kickoff-checklist.md) for client repo setup, GitHub security toggles, and Day 1 verification commands.

## Files included

- README.md
- SECURITY.md
- .gitignore
- .trivyignore
- .gitleaks.toml
- docs/security-baseline.md
- docs/docker-security-addon.md
- docs/client-project-kickoff-checklist.md
- .github/dependabot.yml
- .github/dependency-review-config.yml
- .github/workflows/security-pr.yml
- .github/workflows/secret-scan.yml
- .github/workflows/security-nightly.yml
- .github/workflows/sbom.yml
- .github/workflows/container-scan.yml.disabled
