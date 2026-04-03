#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/detect-manifests.sh [--root <path>] [--format <github|kv|json>] [--config <path>] [--no-config]

Examples:
  ./scripts/detect-manifests.sh
  ./scripts/detect-manifests.sh --format json
  ./scripts/detect-manifests.sh --root /path/to/repo --format github
  ./scripts/detect-manifests.sh --config .stack-detect.yml
EOF
}

ROOT_DIR="$(pwd)"
FORMAT="github"
CONFIG_PATH=""
USE_CONFIG="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT_DIR="${2:-}"
      shift 2
      ;;
    --format)
      FORMAT="${2:-}"
      shift 2
      ;;
    --config)
      CONFIG_PATH="${2:-}"
      shift 2
      ;;
    --no-config)
      USE_CONFIG="false"
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

if [[ "$FORMAT" != "github" && "$FORMAT" != "kv" && "$FORMAT" != "json" ]]; then
  echo "Invalid --format value: $FORMAT (expected github|kv|json)" >&2
  exit 1
fi

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "Root directory not found: $ROOT_DIR" >&2
  exit 1
fi

ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
if [[ -z "$CONFIG_PATH" ]]; then
  CONFIG_PATH="$ROOT_DIR/.stack-detect.yml"
fi

COMMON_EXCLUDES=(
  "*/.git/*"
  "*/profiles/*"
  "*/.claude/*"
)

NODE_EXCLUDES=(
  "*/node_modules/*"
)

PYTHON_EXCLUDES=(
  "*/.venv/*"
  "*/venv/*"
)

JAVA_EXCLUDES=(
  "*/target/*"
)

GO_EXCLUDES=(
  "*/vendor/*"
)

RUST_EXCLUDES=(
  "*/target/*"
)

INCLUDE_PATHS=()
CONFIG_EXCLUDES=()
FORCE_LANGUAGES=()
SCAN_ROOTS=(".")

normalize_rel_path() {
  local value="${1:-}"
  value="${value#./}"
  value="${value#/}"
  value="${value%/}"
  printf '%s' "$value"
}

strip_wrapping_quotes() {
  local value="${1:-}"
  local first_char="${value:0:1}"
  local last_char="${value: -1}"
  if [[ (${first_char}"$last_char" == "\"\"") || (${first_char}"$last_char" == "''") ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

read_yaml_list() {
  local key="$1"
  local file="$2"
  awk -v key="$key" '
    {
      line=$0
      sub(/[[:space:]]+#.*$/, "", line)
    }
    line ~ "^[[:space:]]*" key ":[[:space:]]*$" { in_list=1; next }
    in_list && line ~ /^[[:space:]]*-[[:space:]]*/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      print line
      next
    }
    in_list && line ~ /^[[:space:]]*$/ { next }
    in_list { in_list=0 }
  ' "$file"
}

if [[ "$USE_CONFIG" == "true" && -f "$CONFIG_PATH" ]]; then
  while IFS= read -r raw; do
    [[ -z "$raw" ]] && continue
    value="$(strip_wrapping_quotes "$raw")"
    value="$(normalize_rel_path "$value")"
    [[ -z "$value" ]] && continue
    INCLUDE_PATHS+=("$value")
  done < <(read_yaml_list "include_paths" "$CONFIG_PATH")

  while IFS= read -r raw; do
    [[ -z "$raw" ]] && continue
    value="$(strip_wrapping_quotes "$raw")"
    value="$(normalize_rel_path "$value")"
    [[ -z "$value" ]] && continue
    CONFIG_EXCLUDES+=("./$value")
    CONFIG_EXCLUDES+=("./$value/*")
  done < <(read_yaml_list "exclude_paths" "$CONFIG_PATH")

  while IFS= read -r raw; do
    [[ -z "$raw" ]] && continue
    value="$(strip_wrapping_quotes "$raw")"
    value="$(echo "$value" | tr '[:upper:]' '[:lower:]')"
    [[ -z "$value" ]] && continue
    FORCE_LANGUAGES+=("$value")
  done < <(read_yaml_list "force_languages" "$CONFIG_PATH")
fi

if [[ ${#INCLUDE_PATHS[@]} -gt 0 ]]; then
  SCAN_ROOTS=()
  for include_path in "${INCLUDE_PATHS[@]}"; do
    if [[ -e "$ROOT_DIR/$include_path" ]]; then
      SCAN_ROOTS+=("./$include_path")
    fi
  done
  if [[ ${#SCAN_ROOTS[@]} -eq 0 ]]; then
    SCAN_ROOTS=(".")
  fi
fi

find_files() {
  local name="$1"
  shift
  local -a excludes=("${COMMON_EXCLUDES[@]}")
  if [[ "${CONFIG_EXCLUDES+set}" == "set" && ${#CONFIG_EXCLUDES[@]} -gt 0 ]]; then
    excludes+=("${CONFIG_EXCLUDES[@]}")
  fi
  if [[ $# -gt 0 ]]; then
    excludes+=("$@")
  fi
  local -a cmd=(find "${SCAN_ROOTS[@]}" -type f -name "$name")
  local pattern
  for pattern in "${excludes[@]}"; do
    cmd+=(-not -path "$pattern")
  done
  cmd+=(-print)

  (
    cd "$ROOT_DIR"
    "${cmd[@]}"
  ) | sed 's#^\./##' | sort -u
}

dirs_from_files() {
  local file_list="${1:-}"
  if [[ -z "$file_list" ]]; then
    return 0
  fi
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    dirname "$file"
  done <<< "$file_list" | sort -u
}

merge_unique_lines() {
  local first="${1:-}"
  local second="${2:-}"
  {
    [[ -n "$first" ]] && printf '%s\n' "$first"
    [[ -n "$second" ]] && printf '%s\n' "$second"
    :
  } | sed '/^$/d' | sort -u
}

json_escape() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

json_array_from_lines() {
  local lines="${1:-}"
  local first="true"
  printf '['
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$first" == "false" ]]; then
      printf ','
    fi
    first="false"
    printf '"%s"' "$(json_escape "$line")"
  done <<< "$lines"
  printf ']'
}

emit_multiline_output() {
  local key="$1"
  local lines="${2:-}"
  printf '%s<<EOF\n' "$key"
  if [[ -n "$lines" ]]; then
    printf '%s\n' "$lines"
  fi
  printf 'EOF\n'
}

NODE_FILES="$(find_files "package.json" "${NODE_EXCLUDES[@]}")"
PYTHON_REQUIREMENTS_FILES="$(find_files "requirements*.txt" "${PYTHON_EXCLUDES[@]}")"
PYTHON_PYPROJECT_FILES="$(find_files "pyproject.toml" "${PYTHON_EXCLUDES[@]}")"
JAVA_FILES="$(find_files "pom.xml" "${JAVA_EXCLUDES[@]}")"
GO_FILES="$(find_files "go.mod" "${GO_EXCLUDES[@]}")"
RUST_FILES="$(find_files "Cargo.toml" "${RUST_EXCLUDES[@]}")"

NODE_DIRS="$(dirs_from_files "$NODE_FILES")"
PYTHON_PYPROJECT_DIRS="$(dirs_from_files "$PYTHON_PYPROJECT_FILES")"
PYTHON_DIRS="$(merge_unique_lines "$(dirs_from_files "$PYTHON_REQUIREMENTS_FILES")" "$PYTHON_PYPROJECT_DIRS")"
JAVA_DIRS="$(dirs_from_files "$JAVA_FILES")"
GO_DIRS="$(dirs_from_files "$GO_FILES")"
RUST_DIRS="$(dirs_from_files "$RUST_FILES")"

NODE=false
PYTHON=false
JAVA=false
GO=false
RUST=false

[[ -n "$NODE_DIRS" ]] && NODE=true
[[ -n "$PYTHON_DIRS" ]] && PYTHON=true
[[ -n "$JAVA_DIRS" ]] && JAVA=true
[[ -n "$GO_DIRS" ]] && GO=true
[[ -n "$RUST_DIRS" ]] && RUST=true

if [[ "${FORCE_LANGUAGES+set}" == "set" && ${#FORCE_LANGUAGES[@]} -gt 0 ]]; then
  for forced_lang in "${FORCE_LANGUAGES[@]}"; do
    case "$forced_lang" in
      node) NODE=true ;;
      python) PYTHON=true ;;
      java) JAVA=true ;;
      go) GO=true ;;
      rust) RUST=true ;;
    esac
  done
fi

LANGUAGES=""
[[ "$NODE" == "true" ]] && LANGUAGES="$(merge_unique_lines "$LANGUAGES" "node")"
[[ "$PYTHON" == "true" ]] && LANGUAGES="$(merge_unique_lines "$LANGUAGES" "python")"
[[ "$JAVA" == "true" ]] && LANGUAGES="$(merge_unique_lines "$LANGUAGES" "java")"
[[ "$GO" == "true" ]] && LANGUAGES="$(merge_unique_lines "$LANGUAGES" "go")"
[[ "$RUST" == "true" ]] && LANGUAGES="$(merge_unique_lines "$LANGUAGES" "rust")"

case "$FORMAT" in
  github)
    printf 'node=%s\n' "$NODE"
    printf 'python=%s\n' "$PYTHON"
    printf 'java=%s\n' "$JAVA"
    printf 'go=%s\n' "$GO"
    printf 'rust=%s\n' "$RUST"
    emit_multiline_output "languages" "$LANGUAGES"
    emit_multiline_output "node_dirs" "$NODE_DIRS"
    emit_multiline_output "python_requirements_files" "$PYTHON_REQUIREMENTS_FILES"
    emit_multiline_output "python_pyproject_dirs" "$PYTHON_PYPROJECT_DIRS"
    emit_multiline_output "python_dirs" "$PYTHON_DIRS"
    emit_multiline_output "java_dirs" "$JAVA_DIRS"
    emit_multiline_output "go_dirs" "$GO_DIRS"
    emit_multiline_output "rust_dirs" "$RUST_DIRS"
    ;;
  kv)
    printf 'node=%s\n' "$NODE"
    printf 'python=%s\n' "$PYTHON"
    printf 'java=%s\n' "$JAVA"
    printf 'go=%s\n' "$GO"
    printf 'rust=%s\n' "$RUST"
    printf 'languages=%s\n' "$(echo "$LANGUAGES" | paste -sd ',' -)"
    printf 'node_dirs=%s\n' "$(echo "$NODE_DIRS" | paste -sd ',' -)"
    printf 'python_requirements_files=%s\n' "$(echo "$PYTHON_REQUIREMENTS_FILES" | paste -sd ',' -)"
    printf 'python_pyproject_dirs=%s\n' "$(echo "$PYTHON_PYPROJECT_DIRS" | paste -sd ',' -)"
    printf 'python_dirs=%s\n' "$(echo "$PYTHON_DIRS" | paste -sd ',' -)"
    printf 'java_dirs=%s\n' "$(echo "$JAVA_DIRS" | paste -sd ',' -)"
    printf 'go_dirs=%s\n' "$(echo "$GO_DIRS" | paste -sd ',' -)"
    printf 'rust_dirs=%s\n' "$(echo "$RUST_DIRS" | paste -sd ',' -)"
    ;;
  json)
    printf '{\n'
    printf '  "node": %s,\n' "$NODE"
    printf '  "python": %s,\n' "$PYTHON"
    printf '  "java": %s,\n' "$JAVA"
    printf '  "go": %s,\n' "$GO"
    printf '  "rust": %s,\n' "$RUST"
    printf '  "languages": %s,\n' "$(json_array_from_lines "$LANGUAGES")"
    printf '  "node_dirs": %s,\n' "$(json_array_from_lines "$NODE_DIRS")"
    printf '  "python_requirements_files": %s,\n' "$(json_array_from_lines "$PYTHON_REQUIREMENTS_FILES")"
    printf '  "python_pyproject_dirs": %s,\n' "$(json_array_from_lines "$PYTHON_PYPROJECT_DIRS")"
    printf '  "python_dirs": %s,\n' "$(json_array_from_lines "$PYTHON_DIRS")"
    printf '  "java_dirs": %s,\n' "$(json_array_from_lines "$JAVA_DIRS")"
    printf '  "go_dirs": %s,\n' "$(json_array_from_lines "$GO_DIRS")"
    printf '  "rust_dirs": %s\n' "$(json_array_from_lines "$RUST_DIRS")"
    printf '}\n'
    ;;
esac
