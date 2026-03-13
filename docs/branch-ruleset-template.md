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

If Docker is enabled, also require:
- `container-scan`

## Where to configure
`Settings -> Rules -> New ruleset -> Branch ruleset`

Target:
- Branch name pattern: `main`

## Day 1 sanity check
After enabling ruleset:
1. Open a test PR to `main`.
2. Confirm all required checks appear in the PR checks panel.
3. Confirm merge is blocked when any required check fails.
