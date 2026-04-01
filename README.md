# Freelancer DevSecOps Template - Practical Baseline

A practical GitHub security baseline for freelancers and solo developers.

## TL;DR (Private Client Repo / Fastest Usable)
Use this path as default for solo freelance repos on GitHub Free private repositories.

1. Install local prerequisite:

```bash
brew install gitleaks
```

2. Bootstrap without ruleset lock first:

```bash
./scripts/bootstrap-project.sh --stack <node|python|java|go|rust> --docker <on|off> --repo <owner/repo> --solo on --require-code-scanning-high off --apply-ruleset off
```

3. Open one smoke PR (for example README change) and check which workflows are actually supported on your plan.
4. If `codeql` is unsupported in private repo, disable it before applying ruleset:

```bash
mv .github/workflows/codeql.yml .github/workflows/codeql.yml.disabled
git add .github/workflows/codeql.yml.disabled
git commit -m "chore: disable codeql for current plan"
git push
```

5. Apply ruleset only after smoke PR result is clear:

```bash
./scripts/apply-ruleset.sh --repo <owner/repo> --docker <on|off> --solo on --require-code-scanning-high off
```

## Included

### Baseline controls (enabled by default)
- Dependabot: automatic dependency update PRs
- Dependency Review: blocks PRs that introduce vulnerable runtime dependencies
- Dependency license policy: allowlist-based license compliance checks in dependency review
- Trivy PR scan: scans vulnerabilities and misconfigurations
- Gitleaks: secret scanning on pull requests and pushes to `main`
- Nightly Trivy SARIF upload: post-merge continuous scanning in GitHub code scanning
- Nightly dependency audit: stack-aware dependency vulnerability checks for Node/Python/Java/Go/Rust
- SBOM generation: software bill of materials after pushes to `main`
- CodeQL: language SAST workflow is applied by profile init
- CI tests: language-specific test workflow is applied by profile init
- Dependabot auto-merge: patch-level GitHub Actions updates can auto-merge after checks pass
- SECURITY.md: vulnerability disclosure policy
- PR / Issue templates: include security checklist and disclosure routing
- GitHub Actions pinning: workflows use commit SHA references

### Optional Docker module (disabled by default)
- Container image scan workflow is included as `.github/workflows/container-scan.yml.disabled`
- Dockerfile lint workflow is included as `.github/workflows/dockerfile-lint.yml.disabled`
- Enable it only for repositories that build and ship Docker images

## Language profile init
Apply one stack profile per new client repo:

```bash
./scripts/init-project.sh --stack <node|python|java|go|rust> --docker <on|off>
```

This command selects language-specific Dependabot config, applies a managed `.gitignore` profile block, and toggles Docker scanning mode.
It also copies a minimal smoke scaffold for the selected stack when target files do not already exist.
Template default `.github/dependabot.yml` only tracks GitHub Actions to avoid noise before profile init.
See [`security_docs/profile-init-guide.md`](security_docs/profile-init-guide.md) for details.

## One-command bootstrap (when Code Scanning is available)

```bash
./scripts/bootstrap-project.sh --stack <node|python|java|go|rust> --docker <on|off> --repo <owner/repo> --require-code-scanning-high on --solo on
```

This runs profile init, installs local hooks, and applies the main ruleset in one step.
Use `--solo on` for one-person repos to set required approvals to `0`.

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
- In ruleset, optionally enforce CodeQL security results `high_or_higher` by using:
- `./scripts/apply-ruleset.sh --repo <owner/repo> --docker <on|off> --require-code-scanning-high on --solo on`

## Enable Docker scan when needed
1. Run `./scripts/init-project.sh --stack <node|python|java|go|rust> --docker on` (or rename `.github/workflows/container-scan.yml.disabled` manually).
2. Verify your `Dockerfile` builds successfully in CI (`docker build .`).
3. If Docker is mandatory in the project, add `container-scan` and `dockerfile-lint` to required status checks on `main`.
4. If needed, track accepted risks in `.trivyignore` with ticket/justification.

## Project kickoff checklist
- Use [`security_docs/client-project-kickoff-checklist.md`](security_docs/client-project-kickoff-checklist.md) for client repo setup, GitHub security toggles, and Day 1 verification commands.
- Ruleset baseline is documented in [`security_docs/branch-ruleset-template.md`](security_docs/branch-ruleset-template.md).
- Workflow diagram is documented in [`security_docs/security-workflow-overview.md`](security_docs/security-workflow-overview.md).

## Local guardrails
- Install local hooks: `./scripts/install-hooks.sh`
- Apply ruleset by CLI: `./scripts/apply-ruleset.sh --repo <owner/repo> --docker <on|off> --require-code-scanning-high on` (`--strict-required` optional)
- Vulnerability SLA baseline: [`security_docs/vulnerability-sla.md`](security_docs/vulnerability-sla.md)

## Files included

- README.md
- SECURITY.md
- .gitignore
- .trivyignore
- .gitleaks.toml
- security_docs/security-baseline.md
- security_docs/docker-security-addon.md
- security_docs/client-project-kickoff-checklist.md
- security_docs/profile-init-guide.md
- security_docs/branch-ruleset-template.md
- security_docs/local-guardrails.md
- security_docs/security-workflow-overview.md
- security_docs/todo.md
- security_docs/vulnerability-sla.md
- .github/dependabot.yml
- .github/dependency-review-config.yml
- .github/PULL_REQUEST_TEMPLATE.md
- .github/ISSUE_TEMPLATE/config.yml
- .github/ISSUE_TEMPLATE/security-hardening.md
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
- profiles/go/dependabot.yml
- profiles/go/dependabot-docker.yml
- profiles/go/codeql.yml
- profiles/go/ci.yml
- profiles/go/smoke/go.mod
- profiles/go/smoke/main.go
- profiles/go/smoke/main_test.go
- profiles/go/gitignore.snippet
- profiles/rust/dependabot.yml
- profiles/rust/dependabot-docker.yml
- profiles/rust/codeql.yml
- profiles/rust/ci.yml
- profiles/rust/smoke/Cargo.toml
- profiles/rust/smoke/src/lib.rs
- profiles/rust/gitignore.snippet
- scripts/init-project.sh
- scripts/bootstrap-project.sh
- scripts/install-hooks.sh
- scripts/apply-ruleset.sh
