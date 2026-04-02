# Profile Init Guide

Use profiles to apply language-specific defaults on top of the shared security baseline.

## When to run
Run once right after creating a new repository from this template.
Before running profile init, template default Dependabot only updates GitHub Actions.

## Command

```bash
./scripts/init-project.sh --stack auto --docker <on|off>
```

Or run everything in one step:

```bash
./scripts/bootstrap-project.sh --stack <auto|node|python|java|go|rust> --docker <on|off> --repo <owner/repo> --require-code-scanning-high on
```

Examples:

```bash
./scripts/init-project.sh --stack auto --docker off --dry-run
./scripts/init-project.sh --stack auto --docker on
./scripts/init-project.sh --stack node --docker off
```

## What the script changes
- `.github/dependabot.yml`: auto-generated from detected language directories
- `.github/workflows/codeql.yml`: auto-generated from detected languages
- `.github/workflows/ci.yml`: auto-generated multi-language CI matrix
- `.gitignore`: appends or replaces a managed profile block
- `.stack-profile`: records detected languages/directories and docker mode
- Docker scan workflow is toggled by mode:
- `--docker on` enables `.github/workflows/container-scan.yml`
- `--docker off` keeps `.github/workflows/container-scan.yml.disabled`
- Dockerfile lint workflow is toggled by mode:
- `--docker on` enables `.github/workflows/dockerfile-lint.yml`
- `--docker off` keeps `.github/workflows/dockerfile-lint.yml.disabled`
- CodeQL and dependency-review behavior can be tuned by repository variables:
- `CODEQL_MODE`: `auto | off | enforce`
- `DEPENDENCY_REVIEW_MODE`: `auto | off | enforce`
- SARIF upload behavior can be tuned by repository variable:
- `SARIF_UPLOAD_MODE`: `auto | off | enforce`

Optional detection overrides (`.stack-detect.yml`):

```yaml
include_paths:
  - apps
  - services
exclude_paths:
  - apps/legacy
force_languages:
  - node
```

Manual single-stack compatibility mode remains available:

```bash
./scripts/init-project.sh --stack <node|python|java|go|rust> --docker <on|off>
```

## Expected next steps
1. Review the generated diff.
2. Commit and push.
3. Open a smoke PR and verify required checks.
4. Complete GitHub settings from `security_docs/client-project-kickoff-checklist.md`.

## Direct-to-main repositories
If your team pushes directly to `main`, config sync still works:

1. `config-sync` workflow detects manifest changes on `push main`.
2. It re-runs auto init and validates generated files.
3. If generated files drift, it creates a follow-up `[config-sync]` commit automatically.
