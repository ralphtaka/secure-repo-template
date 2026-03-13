# Local Guardrails

Use these local safeguards to catch issues before CI.

## One-command setup

```bash
./scripts/bootstrap-project.sh --stack <node|python|java|go|rust> --docker <on|off> --repo <owner/repo> --require-code-scanning-high on --solo on
```

If `gh` authentication is not ready yet, use `--apply-ruleset off` and apply ruleset later.

## Install Git hooks

```bash
./scripts/install-hooks.sh
```

This enables `.githooks/pre-commit`, which:
- blocks commits that include likely secret files (`.env`, key material, tfstate)
- runs `gitleaks` staged scan
- blocks commit if `gitleaks` is missing

## Recommended local tooling
- Install `gitleaks` and keep it updated (required by pre-commit).
- Run your stack test command before opening PR.

## Disable hooks temporarily (not recommended)

```bash
git config --unset core.hooksPath
```
