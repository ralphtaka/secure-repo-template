# Local Guardrails

Use these local safeguards to catch issues before CI.

## Install Git hooks

```bash
./scripts/install-hooks.sh
```

This enables `.githooks/pre-commit`, which:
- blocks commits that include likely secret files (`.env`, key material, tfstate)
- runs `gitleaks` staged scan when available

## Recommended local tooling
- Install `gitleaks` and keep it updated.
- Run your stack test command before opening PR.

## Disable hooks temporarily (not recommended)

```bash
git config --unset core.hooksPath
```
