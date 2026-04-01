# Monorepo Example: Node + Python

This template currently applies one stack at a time.
For a Node + Python monorepo, use the dedicated initializer script below (recommended), or use manual assembly fallback.

## Why this needs a dedicated flow

- `scripts/init-project.sh` accepts only one `--stack` and overwrites:
- `.github/dependabot.yml`
- `.github/workflows/ci.yml`
- `.github/workflows/codeql.yml`
- `.gitignore` stack block

## Recommended: dedicated initializer script

Use:

```bash
./scripts/init-monorepo-node-python.sh --node-dir apps/web --python-dir services/api --docker off
```

Default values:

- `--node-dir apps/web`
- `--python-dir services/api`
- `--docker off`

What it generates:

- `.github/dependabot.yml` with `github-actions` + `npm` + `pip`
- `.github/workflows/ci.yml` with `node-ci`, `python-ci`, and final `ci` aggregate job
- `.github/workflows/codeql.yml` with `languages: javascript-typescript, python`
- `.gitignore` managed stack block merged from `profiles/node/gitignore.snippet` + `profiles/python/gitignore.snippet`
- `.stack-profile` metadata for this monorepo mode
- Docker workflow toggle same as `init-project.sh` (`--docker on|off`)

## Reusable materials in this repo

- Node profile inputs:
- `profiles/node/dependabot.yml`
- `profiles/node/ci.yml`
- `profiles/node/codeql.yml`
- `profiles/node/gitignore.snippet`
- Python profile inputs:
- `profiles/python/dependabot.yml`
- `profiles/python/ci.yml`
- `profiles/python/codeql.yml`
- `profiles/python/gitignore.snippet`
- Still reusable scripts:
- `./scripts/install-hooks.sh`
- `./scripts/apply-ruleset.sh`

## Example directory layout

This example assumes:

- Node app: `apps/web`
- Python app: `services/api`

Adjust paths to match your monorepo.

## Manual fallback: compose from existing materials

Use this only if you need custom behavior not covered by the script.

## 1. Build a combined Dependabot config

Create a single `.github/dependabot.yml` with both ecosystems:

```bash
cat > .github/dependabot.yml <<'YAML'
version: 2

updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    labels: ["dependencies", "security"]

  - package-ecosystem: "npm"
    directory: "/apps/web"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    labels: ["dependencies", "security"]
    groups:
      npm-nonmajor:
        update-types: ["minor", "patch"]

  - package-ecosystem: "pip"
    directory: "/services/api"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    labels: ["dependencies", "security"]
YAML
```

## 2. Build a combined CI workflow

Keep a final job named `ci` so ruleset check context stays stable.

```bash
cat > .github/workflows/ci.yml <<'YAML'
name: ci

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  node-ci:
    name: node-ci
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/web
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - name: Setup Node.js
        uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: apps/web/package-lock.json
      - name: Install dependencies
        run: |
          if [ -f package-lock.json ]; then
            npm ci
          else
            npm install
          fi
      - name: Run tests
        run: npm test --if-present

  python-ci:
    name: python-ci
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: services/api
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - name: Setup Python
        uses: actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065
        with:
          python-version: "3.12"
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          if [ -f requirements.txt ]; then
            python -m pip install -r requirements.txt
          elif [ -f pyproject.toml ]; then
            python -m pip install .
          else
            echo "requirements.txt or pyproject.toml not found"
            exit 1
          fi
          python -m pip install pytest
      - name: Run tests
        run: pytest -q

  ci:
    name: ci
    runs-on: ubuntu-latest
    needs: [node-ci, python-ci]
    steps:
      - name: Aggregate status
        run: echo "node-ci and python-ci passed"
YAML
```

## 3. Build a combined CodeQL workflow

Keep job name as `codeql` for ruleset compatibility.

```bash
cat > .github/workflows/codeql.yml <<'YAML'
name: codeql

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: "21 2 * * 1"
  workflow_dispatch:

permissions:
  actions: read
  contents: read
  security-events: write

jobs:
  analyze:
    name: codeql
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd
      - name: Init CodeQL
        uses: github/codeql-action/init@0d579ffd059c29b07949a3cce3983f0780820c98
        with:
          languages: javascript-typescript, python
          build-mode: none
      - name: Analyze
        uses: github/codeql-action/analyze@0d579ffd059c29b07949a3cce3983f0780820c98
YAML
```

## 4. Merge Node/Python ignore patterns

Append one managed block in `.gitignore`:

```bash
cat >> .gitignore <<'EOF'

# >>> stack-profile:start >>>
# stack=monorepo-node-python
# Node profile
node_modules/
dist/
coverage/
npm-debug.log*
yarn-error.log*
pnpm-debug.log*
# Python profile
__pycache__/
.pytest_cache/
.venv/
venv/
*.pyc
*.pyo
.mypy_cache/
# <<< stack-profile:end <<<
EOF
```

## 5. Keep using baseline scripts

Install local hooks:

```bash
./scripts/install-hooks.sh
```

Apply ruleset (example):

```bash
./scripts/apply-ruleset.sh --repo <owner/repo> --docker off --solo on --require-code-scanning-high on
```

If Docker is part of the monorepo, enable Docker workflows first, then run ruleset with `--docker on`.

## 6. Verify before first PR

```bash
git status
rg -n "package-ecosystem|directory:" .github/dependabot.yml
rg -n "name: ci|name: codeql|languages:" .github/workflows/ci.yml .github/workflows/codeql.yml
```

Expected:

- Dependabot has both `npm` and `pip` entries with monorepo subdirectories.
- `.github/workflows/ci.yml` includes `node-ci`, `python-ci`, and final `ci`.
- `.github/workflows/codeql.yml` uses `languages: javascript-typescript, python`.

## Notes

- `dependency-audit-nightly.yml` now discovers manifests recursively and audits per subdirectory.
- Detection excludes template-internal paths like `profiles/` and `.claude/`.
- Keep dependency files in predictable app/service folders to avoid scanning temporary or sample projects.
