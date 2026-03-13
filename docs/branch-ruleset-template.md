# Branch Ruleset Template

Use this as a default `main` ruleset for client delivery repositories.

## Suggested rules
- Require pull request before merge
- Require at least 1 approval
- Dismiss stale approvals when new commits are pushed
- Block force pushes
- Block branch deletion
- Require status checks to pass

## Required status checks
Always require:
- `dependency-review`
- `trivy-pr`
- `gitleaks`
- `codeql`
- `ci`

If Docker is enabled, also require:
- `container-scan`
- `dockerfile-lint`

## Where to configure
`Settings -> Rules -> New ruleset -> Branch ruleset`

Target:
- Branch name pattern: `main`

## Apply via script (recommended)

```bash
./scripts/apply-ruleset.sh --repo <owner/repo> --docker <on|off>
```

Use `--dry-run` first to review payload:

```bash
./scripts/apply-ruleset.sh --repo <owner/repo> --docker off --dry-run
```

## Day 1 sanity check
After enabling ruleset:
1. Open a test PR to `main`.
2. Confirm all required checks appear in the PR checks panel.
3. Confirm merge is blocked when any required check fails.
