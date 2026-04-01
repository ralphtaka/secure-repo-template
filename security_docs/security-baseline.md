# Security Baseline

## What this template keeps

### Baseline controls (enabled by default)
- Dependabot: opens update PRs for supported dependency ecosystems
- Dependency Review: blocks PRs that add vulnerable runtime dependencies when enabled/supported
- Dependency license policy: allowlist-based license compliance checks on PR dependency changes
- Trivy PR scan: fails on HIGH / CRITICAL vulnerabilities and misconfigurations
- Gitleaks: detects likely secrets in pull requests and pushes to `main`
- Nightly Trivy: continues scanning after merge and uploads SARIF to GitHub code scanning
- Nightly dependency audit: stack-aware package vulnerability checks for Node/Python/Java/Go/Rust
- SBOM: generates a software bill of materials for inventory and customer delivery
- CodeQL: language SAST workflow is applied by stack profile (auto-skip in private personal repos by default)
- CI tests: language-specific CI workflow is applied by stack profile
- SECURITY.md: tells others how to report vulnerabilities
- PR / Issue templates: standardize security-aware change and issue reporting
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
1. `./scripts/bootstrap-project.sh --stack <node|python|java|go|rust> --docker <on|off> --repo <owner/repo> --require-code-scanning-high on`
2. Open one smoke PR and confirm checks.
3. Review workflow map: `security_docs/security-workflow-overview.md`.

## License policy note
- Review `.github/dependency-review-config.yml` allowlist for each client contract.
- If a client needs stricter/legal-specific policy, adjust allowlist before project kickoff.
- In private personal repositories, `dependency-review` and `codeql` run in auto-skip mode by default.
- Use repository variables `DEPENDENCY_REVIEW_MODE` and `CODEQL_MODE` (`auto|off|enforce`) to override behavior.
