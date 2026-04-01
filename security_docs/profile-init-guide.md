# Profile Init Guide

Use profiles to apply language-specific defaults on top of the shared security baseline.

## When to run
Run once right after creating a new repository from this template.
Before running profile init, template default Dependabot only updates GitHub Actions.

## Command

```bash
./scripts/init-project.sh --stack <node|python|java|go|rust> --docker <on|off>
```

Or run everything in one step:

```bash
./scripts/bootstrap-project.sh --stack <node|python|java|go|rust> --docker <on|off> --repo <owner/repo> --require-code-scanning-high on
```

Examples:

```bash
./scripts/init-project.sh --stack node --docker off
./scripts/init-project.sh --stack go --docker on
```

## What the script changes
- `.github/dependabot.yml`: switched to the selected language profile
- `.github/workflows/codeql.yml`: writes language-specific CodeQL workflow
- `.github/workflows/ci.yml`: writes language-specific CI workflow
- Smoke scaffold: copies minimal runnable files only when target files do not already exist
- `.gitignore`: appends or replaces a managed profile block
- `.stack-profile`: records chosen stack and docker mode
- Docker scan workflow is toggled by mode:
- `--docker on` enables `.github/workflows/container-scan.yml`
- `--docker off` keeps `.github/workflows/container-scan.yml.disabled`
- Dockerfile lint workflow is toggled by mode:
- `--docker on` enables `.github/workflows/dockerfile-lint.yml`
- `--docker off` keeps `.github/workflows/dockerfile-lint.yml.disabled`

## Expected next steps
1. Review the generated diff.
2. Commit and push.
3. Open a smoke PR and verify required checks.
4. Complete GitHub settings from `security_docs/client-project-kickoff-checklist.md`.
