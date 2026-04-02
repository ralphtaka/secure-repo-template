# Branch Ruleset Template

Use this as a default `main` ruleset for client delivery repositories.

## Suggested rules
- Require pull request before merge
- Require at least 1 approval (team repos)
- For solo repos, set required approvals to `0` (`--solo on`)
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
- `template-smoke`

If Docker is enabled, also require:
- `container-scan`
- `dockerfile-lint`

For direct-to-main repositories:
- `config-sync` is a push-to-main maintenance workflow, not a PR required check.
- Monitor `config-sync` run status on `main` pushes to confirm auto-regeneration succeeded.

## Where to configure
`Settings -> Rules -> New ruleset -> Branch ruleset`

Target:
- Branch name pattern: `main`

## Apply via script (recommended)

```bash
./scripts/apply-ruleset.sh --repo <owner/repo> --docker <on|off>
```

With CodeQL high severity gate:

```bash
./scripts/apply-ruleset.sh --repo <owner/repo> --docker <on|off> --require-code-scanning-high on
```

For solo mode (required approvals = 0):

```bash
./scripts/apply-ruleset.sh --repo <owner/repo> --docker <on|off> --solo on
```

Script behavior:
- Auto-detects enabled workflows and only includes matching check contexts
- Prevents accidental lockout when `ci.yml` or `codeql.yml` has not been generated yet
- Use `--strict-required` if you want missing expected checks to fail immediately
- Use `--require-code-scanning-high on` to add a ruleset gate that blocks PRs with CodeQL security alerts `high_or_higher`
- Code scanning gate requires GitHub code scanning to be enabled in repository security settings

Use `--dry-run` first to review payload:

```bash
./scripts/apply-ruleset.sh --repo <owner/repo> --docker off --dry-run
```

## Day 1 sanity check
After enabling ruleset:
1. Open a test PR to `main`.
2. Confirm all required checks appear in the PR checks panel.
3. Confirm merge is blocked when any required check fails.
