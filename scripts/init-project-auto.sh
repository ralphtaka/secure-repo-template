#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/init-project-auto.sh [--docker <on|off>] [--dry-run] [--config <path>] [--no-config]
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

split_csv() {
  local csv="${1:-}"
  local -n output_ref=$2
  output_ref=()
  if [[ -z "$csv" ]]; then
    return 0
  fi
  IFS=',' read -r -a output_ref <<< "$csv"
}

normalize_lang_name() {
  local lang="$1"
  echo "$lang" | tr '[:upper:]' '[:lower:]'
}

profile_language_to_codeql() {
  local lang="$1"
  case "$lang" in
    node) echo "javascript-typescript" ;;
    python) echo "python" ;;
    java) echo "java-kotlin" ;;
    go) echo "go" ;;
    rust) echo "rust" ;;
  esac
}

dependabot_ecosystem_for_lang() {
  local lang="$1"
  case "$lang" in
    node) echo "npm" ;;
    python) echo "pip" ;;
    java) echo "maven" ;;
    go) echo "gomod" ;;
    rust) echo "cargo" ;;
  esac
}

dependabot_group_block_for_lang() {
  local lang="$1"
  case "$lang" in
    node)
      cat <<'EOF'
    groups:
      npm-nonmajor:
        update-types:
          - "minor"
          - "patch"
EOF
      ;;
    go)
      cat <<'EOF'
    groups:
      gomod-nonmajor:
        update-types:
          - "minor"
          - "patch"
EOF
      ;;
    rust)
      cat <<'EOF'
    groups:
      cargo-nonmajor:
        update-types:
          - "minor"
          - "patch"
EOF
      ;;
  esac
}

dependabot_directory() {
  local dir="$1"
  if [[ "$dir" == "." ]]; then
    echo "/"
  else
    echo "/$dir"
  fi
}

DOCKER="off"
DRY_RUN="false"
declare -a CONFIG_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker)
      DOCKER="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift 1
      ;;
    --config)
      CONFIG_ARGS+=(--config "${2:-}")
      shift 2
      ;;
    --no-config)
      CONFIG_ARGS+=(--no-config)
      shift 1
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

if [[ "$DOCKER" != "on" && "$DOCKER" != "off" ]]; then
  echo "Invalid --docker value: $DOCKER (expected on|off)" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPENDABOT_TARGET="$ROOT_DIR/.github/dependabot.yml"
GITIGNORE_TARGET="$ROOT_DIR/.gitignore"
CODEQL_TARGET="$ROOT_DIR/.github/workflows/codeql.yml"
CI_TARGET="$ROOT_DIR/.github/workflows/ci.yml"
DOCKER_SCAN_ENABLED="$ROOT_DIR/.github/workflows/container-scan.yml"
DOCKER_SCAN_DISABLED="$ROOT_DIR/.github/workflows/container-scan.yml.disabled"
DOCKER_LINT_ENABLED="$ROOT_DIR/.github/workflows/dockerfile-lint.yml"
DOCKER_LINT_DISABLED="$ROOT_DIR/.github/workflows/dockerfile-lint.yml.disabled"
PROFILE_MARKER_START="# >>> stack-profile:start >>>"
PROFILE_MARKER_END="# <<< stack-profile:end <<<"

detect_cmd=("$ROOT_DIR/scripts/detect-manifests.sh" --root "$ROOT_DIR" --format kv)
if [[ "${CONFIG_ARGS+set}" == "set" && ${#CONFIG_ARGS[@]} -gt 0 ]]; then
  detect_cmd+=("${CONFIG_ARGS[@]}")
fi
DETECT_KV="$("${detect_cmd[@]}")"

NODE="false"
PYTHON="false"
JAVA="false"
GO="false"
RUST="false"
LANGUAGES_CSV=""
NODE_DIRS_CSV=""
PYTHON_DIRS_CSV=""
JAVA_DIRS_CSV=""
GO_DIRS_CSV=""
RUST_DIRS_CSV=""

while IFS='=' read -r key value; do
  case "$key" in
    node) NODE="$value" ;;
    python) PYTHON="$value" ;;
    java) JAVA="$value" ;;
    go) GO="$value" ;;
    rust) RUST="$value" ;;
    languages) LANGUAGES_CSV="$value" ;;
    node_dirs) NODE_DIRS_CSV="$value" ;;
    python_dirs) PYTHON_DIRS_CSV="$value" ;;
    java_dirs) JAVA_DIRS_CSV="$value" ;;
    go_dirs) GO_DIRS_CSV="$value" ;;
    rust_dirs) RUST_DIRS_CSV="$value" ;;
  esac
done <<< "$DETECT_KV"

LANGUAGES=()
NODE_DIRS=()
PYTHON_DIRS=()
JAVA_DIRS=()
GO_DIRS=()
RUST_DIRS=()
split_csv "$LANGUAGES_CSV" LANGUAGES
split_csv "$NODE_DIRS_CSV" NODE_DIRS
split_csv "$PYTHON_DIRS_CSV" PYTHON_DIRS
split_csv "$JAVA_DIRS_CSV" JAVA_DIRS
split_csv "$GO_DIRS_CSV" GO_DIRS
split_csv "$RUST_DIRS_CSV" RUST_DIRS

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Auto detection dry-run:"
  echo "- docker: $DOCKER"
  echo "- languages: ${LANGUAGES_CSV:-none}"
  echo "- node_dirs: ${NODE_DIRS_CSV:-none}"
  echo "- python_dirs: ${PYTHON_DIRS_CSV:-none}"
  echo "- java_dirs: ${JAVA_DIRS_CSV:-none}"
  echo "- go_dirs: ${GO_DIRS_CSV:-none}"
  echo "- rust_dirs: ${RUST_DIRS_CSV:-none}"
  echo
  echo "Planned updates:"
  echo "- .github/dependabot.yml (auto-generated)"
  echo "- .github/workflows/ci.yml (auto-generated)"
  echo "- .github/workflows/codeql.yml (auto-generated)"
  echo "- .gitignore (auto profile markers)"
  echo "- .stack-profile (auto detection metadata)"
  if [[ "$DOCKER" == "on" ]]; then
    echo "- .github/workflows/container-scan.yml (enabled if present)"
    echo "- .github/workflows/dockerfile-lint.yml (enabled if present)"
  else
    echo "- .github/workflows/container-scan.yml.disabled (kept disabled if present)"
    echo "- .github/workflows/dockerfile-lint.yml.disabled (kept disabled if present)"
  fi
  exit 0
fi

{
  cat <<'EOF'
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
EOF

  append_dependabot_updates() {
    local lang="$1"
    shift
    local -a dirs=("$@")
    local ecosystem
    ecosystem="$(dependabot_ecosystem_for_lang "$lang")"
    local dir
    for dir in "${dirs[@]}"; do
      [[ -z "$dir" ]] && continue
      cat <<EOF

  - package-ecosystem: "$ecosystem"
    directory: "$(dependabot_directory "$dir")"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
      - "security"
EOF
      group_block="$(dependabot_group_block_for_lang "$lang" || true)"
      if [[ -n "$group_block" ]]; then
        printf '%s\n' "$group_block"
      fi
    done
  }

  if [[ "${NODE_DIRS+set}" == "set" && ${#NODE_DIRS[@]} -gt 0 ]]; then
    append_dependabot_updates "node" "${NODE_DIRS[@]}"
  fi
  if [[ "${PYTHON_DIRS+set}" == "set" && ${#PYTHON_DIRS[@]} -gt 0 ]]; then
    append_dependabot_updates "python" "${PYTHON_DIRS[@]}"
  fi
  if [[ "${JAVA_DIRS+set}" == "set" && ${#JAVA_DIRS[@]} -gt 0 ]]; then
    append_dependabot_updates "java" "${JAVA_DIRS[@]}"
  fi
  if [[ "${GO_DIRS+set}" == "set" && ${#GO_DIRS[@]} -gt 0 ]]; then
    append_dependabot_updates "go" "${GO_DIRS[@]}"
  fi
  if [[ "${RUST_DIRS+set}" == "set" && ${#RUST_DIRS[@]} -gt 0 ]]; then
    append_dependabot_updates "rust" "${RUST_DIRS[@]}"
  fi
} > "$DEPENDABOT_TARGET"

codeql_languages=()
if [[ "${LANGUAGES+set}" == "set" && ${#LANGUAGES[@]} -gt 0 ]]; then
  for lang in "${LANGUAGES[@]}"; do
    [[ -z "$lang" ]] && continue
    mapped="$(profile_language_to_codeql "$(normalize_lang_name "$lang")" || true)"
    [[ -z "$mapped" ]] && continue
    codeql_languages+=("$mapped")
  done
fi

codeql_lang_csv=""
if [[ ${#codeql_languages[@]} -gt 0 ]]; then
  codeql_lang_csv="$(IFS=,; echo "${codeql_languages[*]}")"
fi

requires_autobuild="false"
if [[ "$JAVA" == "true" || "$GO" == "true" ]]; then
  requires_autobuild="true"
fi

if [[ -z "$codeql_lang_csv" ]]; then
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
      - name: No supported languages detected
        run: echo "No supported languages detected for CodeQL. Set force_languages in .stack-detect.yml if needed."
EOF
else
  cat > "$CODEQL_TARGET" <<EOF
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

      - name: Resolve CodeQL mode
        id: mode
        run: |
          mode="\${{ vars.CODEQL_MODE }}"
          if [ -z "\$mode" ]; then
            mode="auto"
          fi

          ./scripts/resolve-security-feature-mode.sh \
            --feature codeql \
            --mode "\$mode" \
            --repo "\${{ github.repository }}" \
            --private-repo "\${{ github.event.repository.private }}" \
            --owner-type "\${{ github.event.repository.owner.type }}" \
            --token "\${{ secrets.GITHUB_TOKEN }}" >> "\$GITHUB_OUTPUT"

      - name: Init CodeQL
        if: steps.mode.outputs.run_feature == 'true'
        uses: github/codeql-action/init@0d579ffd059c29b07949a3cce3983f0780820c98
        with:
          languages: $codeql_lang_csv
EOF
  if [[ "$requires_autobuild" != "true" ]]; then
    cat >> "$CODEQL_TARGET" <<'EOF'
          build-mode: none
EOF
  fi

  if [[ "$requires_autobuild" == "true" ]]; then
    cat >> "$CODEQL_TARGET" <<'EOF'

      - name: Autobuild
        if: steps.mode.outputs.run_feature == 'true'
        uses: github/codeql-action/autobuild@0d579ffd059c29b07949a3cce3983f0780820c98
EOF
  fi

  cat >> "$CODEQL_TARGET" <<'EOF'

      - name: Analyze
        if: steps.mode.outputs.run_feature == 'true'
        uses: github/codeql-action/analyze@0d579ffd059c29b07949a3cce3983f0780820c98

      - name: CodeQL skipped
        if: steps.mode.outputs.run_feature != 'true'
        run: |
          echo "CodeQL scan skipped."
          echo "mode=${{ steps.mode.outputs.mode }}"
          echo "reason=${{ steps.mode.outputs.reason }}"
          echo "capability_status=${{ steps.mode.outputs.capability_status }}"
          echo "capability_detail=${{ steps.mode.outputs.capability_detail }}"
EOF
fi

job_names=()
{
  cat <<'EOF'
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
EOF

  append_ci_job_header() {
    local job_id="$1"
    local display_name="$2"
    printf '  %s:\n' "$job_id"
    printf '    name: %s\n' "$display_name"
    printf '    runs-on: ubuntu-latest\n'
    printf '    strategy:\n'
    printf '      fail-fast: false\n'
    printf '      matrix:\n'
    printf '        path:\n'
  }

  append_ci_matrix_paths() {
    local dir
    for dir in "$@"; do
      [[ -z "$dir" ]] && continue
      printf '          - %s\n' "$dir"
    done
  }

  if [[ ${#NODE_DIRS[@]} -gt 0 ]]; then
    append_ci_job_header "node-ci" "node-ci"
    append_ci_matrix_paths "${NODE_DIRS[@]}"
    cat <<'EOF'
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd

      - name: Setup Node.js
        uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: ${{ matrix.path }}/package-lock.json

      - name: Install dependencies
        working-directory: ${{ matrix.path }}
        run: |
          if [ ! -f package.json ]; then
            echo "package.json not found in ${{ matrix.path }}"
            exit 1
          fi
          if [ -f package-lock.json ]; then
            npm ci
          else
            npm install
          fi

      - name: Run tests
        working-directory: ${{ matrix.path }}
        run: npm test --if-present
EOF
    job_names+=("node-ci")
  fi

  if [[ ${#PYTHON_DIRS[@]} -gt 0 ]]; then
    append_ci_job_header "python-ci" "python-ci"
    append_ci_matrix_paths "${PYTHON_DIRS[@]}"
    cat <<'EOF'
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd

      - name: Setup Python
        uses: actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065
        with:
          python-version: "3.12"

      - name: Install dependencies
        working-directory: ${{ matrix.path }}
        run: |
          python -m pip install --upgrade pip
          if [ -f requirements.txt ]; then
            python -m pip install -r requirements.txt
          elif [ -f pyproject.toml ]; then
            python -m pip install .
          else
            echo "requirements.txt or pyproject.toml not found in ${{ matrix.path }}"
            exit 1
          fi
          python -m pip install pytest

      - name: Run tests
        working-directory: ${{ matrix.path }}
        run: pytest -q
EOF
    job_names+=("python-ci")
  fi

  if [[ ${#JAVA_DIRS[@]} -gt 0 ]]; then
    append_ci_job_header "java-ci" "java-ci"
    append_ci_matrix_paths "${JAVA_DIRS[@]}"
    cat <<'EOF'
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd

      - name: Setup Java
        uses: actions/setup-java@c1e323688fd81a25caa38c78aa6df2d33d3e20d9
        with:
          distribution: temurin
          java-version: "17"
          cache: maven

      - name: Run tests
        working-directory: ${{ matrix.path }}
        run: |
          if [ ! -f pom.xml ]; then
            echo "pom.xml not found in ${{ matrix.path }}"
            exit 1
          fi
          if [ -x ./mvnw ]; then
            ./mvnw -B test
          else
            mvn -B test
          fi
EOF
    job_names+=("java-ci")
  fi

  if [[ ${#GO_DIRS[@]} -gt 0 ]]; then
    append_ci_job_header "go-ci" "go-ci"
    append_ci_matrix_paths "${GO_DIRS[@]}"
    cat <<'EOF'
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd

      - name: Setup Go
        uses: actions/setup-go@4b73464bb391d4059bd26b0524d20df3927bd417
        with:
          go-version: "1.23.x"
          cache: true

      - name: Run tests
        working-directory: ${{ matrix.path }}
        run: |
          if [ ! -f go.mod ]; then
            echo "go.mod not found in ${{ matrix.path }}"
            exit 1
          fi
          go test ./...
EOF
    job_names+=("go-ci")
  fi

  if [[ ${#RUST_DIRS[@]} -gt 0 ]]; then
    append_ci_job_header "rust-ci" "rust-ci"
    append_ci_matrix_paths "${RUST_DIRS[@]}"
    cat <<'EOF'
    steps:
      - name: Checkout
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd

      - name: Run tests
        working-directory: ${{ matrix.path }}
        run: |
          if [ ! -f Cargo.toml ]; then
            echo "Cargo.toml not found in ${{ matrix.path }}"
            exit 1
          fi
          if [ -f Cargo.lock ]; then
            cargo test --locked
          else
            cargo test
          fi
EOF
    job_names+=("rust-ci")
  fi

  if [[ ${#job_names[@]} -eq 0 ]]; then
    cat <<'EOF'
  ci:
    name: ci
    runs-on: ubuntu-latest
    steps:
      - name: No supported manifests detected
        run: echo "No supported language manifests detected for CI."
EOF
  else
    needs_csv="$(IFS=,; echo "${job_names[*]}")"
    cat <<EOF
  ci:
    name: ci
    runs-on: ubuntu-latest
    needs: [${needs_csv}]
    steps:
      - name: Aggregate status
        run: echo "All language CI jobs passed"
EOF
  fi
} > "$CI_TARGET"

if [[ ! -f "$GITIGNORE_TARGET" ]]; then
  touch "$GITIGNORE_TARGET"
fi

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
  echo "# stack=auto"
  echo "# languages=${LANGUAGES_CSV:-none}"
  if [[ "${LANGUAGES+set}" == "set" && ${#LANGUAGES[@]} -gt 0 ]]; then
    for lang in "${LANGUAGES[@]}"; do
      [[ -z "$lang" ]] && continue
      snippet_path="$ROOT_DIR/profiles/$lang/gitignore.snippet"
      if [[ -f "$snippet_path" ]]; then
        cat "$snippet_path"
      fi
    done
  fi
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
stack=auto
languages=${LANGUAGES_CSV}
node_dirs=${NODE_DIRS_CSV}
python_dirs=${PYTHON_DIRS_CSV}
java_dirs=${JAVA_DIRS_CSV}
go_dirs=${GO_DIRS_CSV}
rust_dirs=${RUST_DIRS_CSV}
docker=$DOCKER
generated_by=scripts/init-project-auto.sh
generated_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "Auto profile applied:"
echo "- stack: auto"
echo "- languages: ${LANGUAGES_CSV:-none}"
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
