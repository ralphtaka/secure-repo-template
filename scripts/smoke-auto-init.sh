#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/smoke-auto-init.sh
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

copy_repo() {
  local target="$1"
  mkdir -p "$target"
  (
    cd "$ROOT_DIR"
    tar --exclude=.git -cf - .
  ) | (
    cd "$target"
    tar -xf -
  )
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  if ! rg -q "$pattern" "$file"; then
    echo "Smoke assertion failed: pattern '$pattern' not found in $file" >&2
    exit 1
  fi
}

run_case() {
  local case_name="$1"
  local repo_path="$TEMP_ROOT/$case_name"
  copy_repo "$repo_path"

  mkdir -p "$repo_path/apps/web" "$repo_path/services/api" "$repo_path/services/go-api"
  cat > "$repo_path/apps/web/package.json" <<'EOF'
{
  "name": "web",
  "version": "1.0.0",
  "scripts": {
    "test": "echo ok"
  }
}
EOF
  cat > "$repo_path/services/api/requirements.txt" <<'EOF'
requests==2.32.3
EOF
  cat > "$repo_path/services/go-api/go.mod" <<'EOF'
module example.com/go-api

go 1.23
EOF
  cat > "$repo_path/.stack-detect.yml" <<'EOF'
include_paths:
  - apps
  - services
exclude_paths:
  - services/legacy
EOF

  (
    cd "$repo_path"
    ./scripts/init-project.sh --stack auto --docker off
    ./scripts/validate-generated-configs.sh --root .
  )

  assert_file_contains "$repo_path/.github/dependabot.yml" 'package-ecosystem: "npm"'
  assert_file_contains "$repo_path/.github/dependabot.yml" 'directory: "/apps/web"'
  assert_file_contains "$repo_path/.github/dependabot.yml" 'package-ecosystem: "pip"'
  assert_file_contains "$repo_path/.github/dependabot.yml" 'directory: "/services/api"'
  assert_file_contains "$repo_path/.github/dependabot.yml" 'package-ecosystem: "gomod"'
  assert_file_contains "$repo_path/.github/dependabot.yml" 'directory: "/services/go-api"'
  assert_file_contains "$repo_path/.github/workflows/codeql.yml" "languages: go,javascript-typescript,python"
  assert_file_contains "$repo_path/.github/workflows/codeql.yml" "name: Autobuild"
  assert_file_contains "$repo_path/.github/workflows/ci.yml" "node-ci"
  assert_file_contains "$repo_path/.github/workflows/ci.yml" "python-ci"
  assert_file_contains "$repo_path/.github/workflows/ci.yml" "go-ci"
  assert_file_contains "$repo_path/.stack-profile" "stack=auto"
}

run_case "case-mixed-monorepo"

echo "Smoke test passed: auto init and generated configs are valid."
