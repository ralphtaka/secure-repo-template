#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/has-manifest-changes.sh --base <sha> --head <sha>
EOF
}

BASE_SHA=""
HEAD_SHA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      BASE_SHA="${2:-}"
      shift 2
      ;;
    --head)
      HEAD_SHA="${2:-}"
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

if [[ -z "$BASE_SHA" || -z "$HEAD_SHA" ]]; then
  echo "--base and --head are required." >&2
  exit 1
fi

if [[ "$BASE_SHA" == "0000000000000000000000000000000000000000" ]]; then
  BASE_SHA="$(git rev-list --max-parents=0 "$HEAD_SHA" | tail -n1)"
fi

changed_files="$(git diff --name-only "$BASE_SHA" "$HEAD_SHA" || true)"

if [[ -z "$changed_files" ]]; then
  echo "has_changes=false"
  echo "matched_files="
  exit 0
fi

matched_files="$(
  echo "$changed_files" | rg -N \
    -e '(^|/)package\.json$' \
    -e '(^|/)requirements[^/]*\.txt$' \
    -e '(^|/)pyproject\.toml$' \
    -e '(^|/)pom\.xml$' \
    -e '(^|/)go\.mod$' \
    -e '(^|/)Cargo\.toml$' \
    -e '^\.stack-detect\.yml$' \
    || true
)"

if [[ -n "$matched_files" ]]; then
  echo "has_changes=true"
  echo "matched_files<<EOF"
  printf '%s\n' "$matched_files"
  echo "EOF"
else
  echo "has_changes=false"
  echo "matched_files="
fi
