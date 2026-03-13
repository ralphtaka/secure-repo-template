#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/init-project.sh --stack <node|python|java> [--docker <on|off>]

Examples:
  ./scripts/init-project.sh --stack node --docker off
  ./scripts/init-project.sh --stack python --docker on
EOF
}

STACK=""
DOCKER="off"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)
      STACK="${2:-}"
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

if [[ -z "$STACK" ]]; then
  echo "--stack is required." >&2
  usage
  exit 1
fi

if [[ "$STACK" != "node" && "$STACK" != "python" && "$STACK" != "java" ]]; then
  echo "Invalid --stack value: $STACK" >&2
  exit 1
fi

if [[ "$DOCKER" != "on" && "$DOCKER" != "off" ]]; then
  echo "Invalid --docker value: $DOCKER (expected on|off)" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="$ROOT_DIR/profiles/$STACK"
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
CODEQL_SOURCE="$PROFILE_DIR/codeql.yml"
CI_SOURCE="$PROFILE_DIR/ci.yml"

if [[ "$DOCKER" == "on" ]]; then
  DEPENDABOT_SOURCE="$PROFILE_DIR/dependabot-docker.yml"
else
  DEPENDABOT_SOURCE="$PROFILE_DIR/dependabot.yml"
fi

if [[ ! -f "$DEPENDABOT_SOURCE" ]]; then
  echo "Missing profile file: $DEPENDABOT_SOURCE" >&2
  exit 1
fi

if [[ ! -f "$PROFILE_DIR/gitignore.snippet" ]]; then
  echo "Missing profile file: $PROFILE_DIR/gitignore.snippet" >&2
  exit 1
fi

if [[ ! -f "$CODEQL_SOURCE" ]]; then
  echo "Missing profile file: $CODEQL_SOURCE" >&2
  exit 1
fi

if [[ ! -f "$CI_SOURCE" ]]; then
  echo "Missing profile file: $CI_SOURCE" >&2
  exit 1
fi

cp "$DEPENDABOT_SOURCE" "$DEPENDABOT_TARGET"
cp "$CODEQL_SOURCE" "$CODEQL_TARGET"
cp "$CI_SOURCE" "$CI_TARGET"

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
  echo "# stack=$STACK"
  cat "$PROFILE_DIR/gitignore.snippet"
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
stack=$STACK
docker=$DOCKER
generated_by=scripts/init-project.sh
generated_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "Profile applied:"
echo "- stack: $STACK"
echo "- docker: $DOCKER"
echo
echo "Updated files:"
echo "- .github/dependabot.yml"
echo "- .github/workflows/codeql.yml"
echo "- .github/workflows/ci.yml"
echo "- .gitignore"
echo "- .stack-profile"
if [[ "$DOCKER" == "on" ]]; then
  echo "- .github/workflows/container-scan.yml (enabled)"
  echo "- .github/workflows/dockerfile-lint.yml (enabled)"
else
  echo "- .github/workflows/container-scan.yml.disabled (kept disabled)"
  echo "- .github/workflows/dockerfile-lint.yml.disabled (kept disabled)"
fi
