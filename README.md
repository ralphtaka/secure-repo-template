# Freelancer DevSecOps Template - Practical Baseline

A practical GitHub security baseline for freelancers and solo developers.

## Included

### Baseline controls (enabled by default)
- Dependabot: automatic dependency update PRs
- Dependency Review: blocks PRs that introduce vulnerable runtime dependencies
- Trivy PR scan: scans vulnerabilities and misconfigurations
- Gitleaks: secret scanning on pull requests and pushes to `main`
- Nightly Trivy SARIF upload: post-merge continuous scanning in GitHub code scanning
- Nightly dependency audit: stack-aware dependency vulnerability checks for Node/Python/Java
- SBOM generation: software bill of materials after pushes to `main`
- CodeQL: language SAST workflow is applied by profile init
- CI tests: language-specific test workflow is applied by profile init
- Dependabot auto-merge: patch-level GitHub Actions updates can auto-merge after checks pass
- SECURITY.md: vulnerability disclosure policy
- GitHub Actions pinning: workflows use commit SHA references

### Optional Docker module (disabled by default)
- Container image scan workflow is included as `.github/workflows/container-scan.yml.disabled`
- Dockerfile lint workflow is included as `.github/workflows/dockerfile-lint.yml.disabled`
- Enable it only for repositories that build and ship Docker images

## Language profile init
Apply one stack profile per new client repo:

```bash
./scripts/init-project.sh --stack <node|python|java> --docker <on|off>
```

This command selects language-specific Dependabot config, applies a managed `.gitignore` profile block, and toggles Docker scanning mode.
It also copies a minimal smoke scaffold for the selected stack when target files do not already exist.
Template default `.github/dependabot.yml` only tracks GitHub Actions to avoid noise before profile init.
See [`docs/profile-init-guide.md`](docs/profile-init-guide.md) for details.

## One-command bootstrap (recommended)

```bash
./scripts/bootstrap-project.sh --stack <node|python|java> --docker <on|off> --repo <owner/repo>
```

This runs profile init, installs local hooks, and applies the main ruleset in one step.

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
- codeql
- ci

Recommended:
- Require pull request before merge
- Block force pushes and branch deletion

## Enable Docker scan when needed
1. Run `./scripts/init-project.sh --stack <node|python|java> --docker on` (or rename `.github/workflows/container-scan.yml.disabled` manually).
2. Verify your `Dockerfile` builds successfully in CI (`docker build .`).
3. If Docker is mandatory in the project, add `container-scan` and `dockerfile-lint` to required status checks on `main`.
4. If needed, track accepted risks in `.trivyignore` with ticket/justification.

## Project kickoff checklist
- Use [`docs/client-project-kickoff-checklist.md`](docs/client-project-kickoff-checklist.md) for client repo setup, GitHub security toggles, and Day 1 verification commands.
- Ruleset baseline is documented in [`docs/branch-ruleset-template.md`](docs/branch-ruleset-template.md).

## Local guardrails
- Install local hooks: `./scripts/install-hooks.sh`
- Apply ruleset by CLI: `./scripts/apply-ruleset.sh --repo <owner/repo> --docker <on|off>` (`--strict-required` optional)
- Vulnerability SLA baseline: [`docs/vulnerability-sla.md`](docs/vulnerability-sla.md)

## Files included

- README.md
- SECURITY.md
- .gitignore
- .trivyignore
- .gitleaks.toml
- docs/security-baseline.md
- docs/docker-security-addon.md
- docs/client-project-kickoff-checklist.md
- docs/profile-init-guide.md
- docs/branch-ruleset-template.md
- docs/local-guardrails.md
- docs/vulnerability-sla.md
- .github/dependabot.yml
- .github/dependency-review-config.yml
- .github/workflows/dependabot-automerge.yml
- .github/workflows/security-pr.yml
- .github/workflows/secret-scan.yml
- .github/workflows/security-nightly.yml
- .github/workflows/dependency-audit-nightly.yml
- .github/workflows/sbom.yml
- .github/workflows/container-scan.yml.disabled
- .github/workflows/dockerfile-lint.yml.disabled
- .githooks/pre-commit
- profiles/README.md
- profiles/node/dependabot.yml
- profiles/node/dependabot-docker.yml
- profiles/node/codeql.yml
- profiles/node/ci.yml
- profiles/node/smoke/package.json
- profiles/node/smoke/test/smoke.test.js
- profiles/node/gitignore.snippet
- profiles/python/dependabot.yml
- profiles/python/dependabot-docker.yml
- profiles/python/codeql.yml
- profiles/python/ci.yml
- profiles/python/smoke/requirements.txt
- profiles/python/smoke/tests/test_smoke.py
- profiles/python/gitignore.snippet
- profiles/java/dependabot.yml
- profiles/java/dependabot-docker.yml
- profiles/java/codeql.yml
- profiles/java/ci.yml
- profiles/java/smoke/pom.xml
- profiles/java/smoke/src/test/java/com/example/SmokeTest.java
- profiles/java/gitignore.snippet
- scripts/init-project.sh
- scripts/bootstrap-project.sh
- scripts/install-hooks.sh
- scripts/apply-ruleset.sh
