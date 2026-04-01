#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/init-monorepo-node-python.sh [--node-dir <path>] [--python-dir <path>] [--docker <on|off>]

Examples:
  ./scripts/init-monorepo-node-python.sh
  ./scripts/init-monorepo-node-python.sh --node-dir apps/web --python-dir services/api --docker off
  ./scripts/init-monorepo-node-python.sh --node-dir frontend --python-dir backend --docker on
EOF
}

print_gitleaks_hint() {
  if command -v gitleaks >/dev/null 2>&1; then
    return 0
  fi

  echo
  echo "Prerequisite reminder: gitleaks is not installed."
  echo "Local pre-commit hook requires gitleaks and will block commits until installed."

  os_name="$(uname -s || true)"
  case "$os_name" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        echo "Install command (macOS): brew install gitleaks"
      else
        echo "Install command (macOS): install Homebrew first, then run: brew install gitleaks"
      fi
      ;;
    Linux)
      echo "Install guide (Linux): https://github.com/gitleaks/gitleaks#installing"
      ;;
    *)
      echo "Install guide: https://github.com/gitleaks/gitleaks#installing"
      ;;
  esac
}

normalize_rel_dir() {
  local input="${1:-}"
  input="${input#/}"
  input="${input%/}"
  echo "$input"
}

NODE_DIR="apps/web"
PYTHON_DIR="services/api"
DOCKER="off"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --node-dir)
      NODE_DIR="${2:-}"
      shift 2
      ;;
    --python-dir)
      PYTHON_DIR="${2:-}"
      shift 2
      ;;
    --docker)
      DOCKER="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

NODE_DIR="$(normalize_rel_dir "$NODE_DIR")"
PYTHON_DIR="$(normalize_rel_dir "$PYTHON_DIR")"

if [[ -z "$NODE_DIR" || -z "$PYTHON_DIR" ]]; then
  echo "--node-dir and --python-dir must not be empty." >&2
  exit 1
fi

if [[ "$DOCKER" != "on" && "$DOCKER" != "off" ]]; then
  echo "Invalid --docker value: $DOCKER (expected on|off)" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -d "$ROOT_DIR/$NODE_DIR" ]]; then
  echo "Node directory not found: $NODE_DIR" >&2
  exit 1
fi

if [[ ! -d "$ROOT_DIR/$PYTHON_DIR" ]]; then
  echo "Python directory not found: $PYTHON_DIR" >&2
  exit 1
fi

DEPENDABOT_TARGET="$ROOT_DIR/.github/dependabot.yml"
CI_TARGET="$ROOT_DIR/.github/workflows/ci.yml"
CODEQL_TARGET="$ROOT_DIR/.github/workflows/codeql.yml"
GITIGNORE_TARGET="$ROOT_DIR/.gitignore"
NODE_GITIGNORE_SNIPPET="$ROOT_DIR/profiles/node/gitignore.snippet"
PYTHON_GITIGNORE_SNIPPET="$ROOT_DIR/profiles/python/gitignore.snippet"
DOCKER_SCAN_ENABLED="$ROOT_DIR/.github/workflows/container-scan.yml"
DOCKER_SCAN_DISABLED="$ROOT_DIR/.github/workflows/container-scan.yml.disabled"
DOCKER_LINT_ENABLED="$ROOT_DIR/.github/workflows/dockerfile-lint.yml"
DOCKER_LINT_DISABLED="$ROOT_DIR/.github/workflows/dockerfile-lint.yml.disabled"

if [[ ! -f "$NODE_GITIGNORE_SNIPPET" ]]; then
  echo "Missing profile file: $NODE_GITIGNORE_SNIPPET" >&2
  exit 1
fi

if [[ ! -f "$PYTHON_GITIGNORE_SNIPPET" ]]; then
  echo "Missing profile file: $PYTHON_GITIGNORE_SNIPPET" >&2
  exit 1
fi

node_dependabot_dir="/$NODE_DIR"
python_dependabot_dir="/$PYTHON_DIR"

cat > "$DEPENDABOT_TARGET" <<EOF
version: 2

updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
      - "security"

  - package-ecosystem: "npm"
    directory: "$node_dependabot_dir"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
      - "security"
    groups:
      npm-nonmajor:
        update-types:
          - "minor"
          - "patch"

  - package-ecosystem: "pip"
    directory: "$python_dependabot_dir"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
      - "security"
EOF

cat > "$CI_TARGET" <<EOF
name: ci

on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read

jobs:
  node-ci:
    name: node-ci
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: $NODE_DIR
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd

      - name: Setup Node.js
        uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: $NODE_DIR/package-lock.json

      - name: Install dependencies
        run: |
          if [ ! -f package.json ]; then
            echo "package.json not found in $NODE_DIR"
            exit 1
          fi
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
        working-directory: $PYTHON_DIR
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
            echo "requirements.txt or pyproject.toml not found in $PYTHON_DIR"
            exit 1
          fi
          python -m pip install pytest

      - name: Run tests
        run: pytest -q

  ci:
    name: ci
    runs-on: ubuntu-latest
    needs:
      - node-ci
      - python-ci
    steps:
      - name: Aggregate status
        run: echo "node-ci and python-ci passed"
EOF

cat > "$CODEQL_TARGET" <<'EOF'
name: codeql

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
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
EOF

PROFILE_MARKER_START="# >>> stack-profile:start >>>"
PROFILE_MARKER_END="# <<< stack-profile:end <<<"
TMP_FILE="$(mktemp)"
awk -v start="$PROFILE_MARKER_START" -v end="$PROFILE_MARKER_END" '
  $0 == start { skip = 1; next }
  $0 == end   { skip = 0; next }
  skip != 1   { print }
' "$GITIGNORE_TARGET" > "$TMP_FILE"

{
  cat "$TMP_FILE"
  echo
  echo "$PROFILE_MARKER_START"
  echo "# stack=monorepo-node-python"
  echo "# node_dir=$NODE_DIR"
  echo "# python_dir=$PYTHON_DIR"
  cat "$NODE_GITIGNORE_SNIPPET"
  cat "$PYTHON_GITIGNORE_SNIPPET"
  echo "$PROFILE_MARKER_END"
} > "$GITIGNORE_TARGET"
rm -f "$TMP_FILE"

if [[ "$DOCKER" == "on" ]]; then
  if [[ -f "$DOCKER_SCAN_DISABLED" ]]; then
    mv "$DOCKER_SCAN_DISABLED" "$DOCKER_SCAN_ENABLED"
  fi
  if [[ -f "$DOCKER_LINT_DISABLED" ]]; then
    mv "$DOCKER_LINT_DISABLED" "$DOCKER_LINT_ENABLED"
  fi
else
  if [[ -f "$DOCKER_SCAN_ENABLED" ]]; then
    mv "$DOCKER_SCAN_ENABLED" "$DOCKER_SCAN_DISABLED"
  fi
  if [[ -f "$DOCKER_LINT_ENABLED" ]]; then
    mv "$DOCKER_LINT_ENABLED" "$DOCKER_LINT_DISABLED"
  fi
fi

cat > "$ROOT_DIR/.stack-profile" <<EOF
stack=monorepo-node-python
node_dir=$NODE_DIR
python_dir=$PYTHON_DIR
docker=$DOCKER
generated_by=scripts/init-monorepo-node-python.sh
generated_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "Monorepo profile applied:"
echo "- stack: monorepo-node-python"
echo "- node_dir: $NODE_DIR"
echo "- python_dir: $PYTHON_DIR"
echo "- docker: $DOCKER"
echo
echo "Updated files:"
echo "- .github/dependabot.yml"
echo "- .github/workflows/ci.yml"
echo "- .github/workflows/codeql.yml"
echo "- .gitignore"
echo "- .stack-profile"
if [[ "$DOCKER" == "on" ]]; then
  echo "- .github/workflows/container-scan.yml (enabled)"
  echo "- .github/workflows/dockerfile-lint.yml (enabled)"
else
  echo "- .github/workflows/container-scan.yml.disabled (kept disabled)"
  echo "- .github/workflows/dockerfile-lint.yml.disabled (kept disabled)"
fi

print_gitleaks_hint
