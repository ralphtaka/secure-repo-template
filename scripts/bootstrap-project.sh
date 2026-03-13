#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/bootstrap-project.sh --stack <node|python|java|go|rust> [--docker on|off] [--repo owner/name] [--solo on|off] [--enforcement active|evaluate|disabled] [--require-code-scanning-high on|off] [--apply-ruleset on|off] [--strict-required]

Examples:
  ./scripts/bootstrap-project.sh --stack node --docker off --repo owner/project
  ./scripts/bootstrap-project.sh --stack go --docker on --repo owner/project --require-code-scanning-high on
  ./scripts/bootstrap-project.sh --stack python --repo owner/project --solo on
EOF
}

STACK=""
DOCKER="off"
REPO=""
SOLO="off"
ENFORCEMENT="active"
APPLY_RULESET="on"
STRICT_REQUIRED="false"
REQUIRE_CODE_SCANNING_HIGH="off"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --solo)
      SOLO="${2:-}"
      shift 2
      ;;
    --enforcement)
      ENFORCEMENT="${2:-}"
      shift 2
      ;;
    --require-code-scanning-high)
      REQUIRE_CODE_SCANNING_HIGH="${2:-}"
      shift 2
      ;;
    --apply-ruleset)
      APPLY_RULESET="${2:-}"
      shift 2
      ;;
    --strict-required)
      STRICT_REQUIRED="true"
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

if [[ -z "$STACK" ]]; then
  echo "--stack is required." >&2
  usage
  exit 1
fi

if [[ "$DOCKER" != "on" && "$DOCKER" != "off" ]]; then
  echo "Invalid --docker value: $DOCKER (expected on|off)" >&2
  exit 1
fi

if [[ "$SOLO" != "on" && "$SOLO" != "off" ]]; then
  echo "Invalid --solo value: $SOLO (expected on|off)" >&2
  exit 1
fi

if [[ "$ENFORCEMENT" != "active" && "$ENFORCEMENT" != "evaluate" && "$ENFORCEMENT" != "disabled" ]]; then
  echo "Invalid --enforcement value: $ENFORCEMENT (expected active|evaluate|disabled)" >&2
  exit 1
fi

if [[ "$APPLY_RULESET" != "on" && "$APPLY_RULESET" != "off" ]]; then
  echo "Invalid --apply-ruleset value: $APPLY_RULESET (expected on|off)" >&2
  exit 1
fi

if [[ "$REQUIRE_CODE_SCANNING_HIGH" != "on" && "$REQUIRE_CODE_SCANNING_HIGH" != "off" ]]; then
  echo "Invalid --require-code-scanning-high value: $REQUIRE_CODE_SCANNING_HIGH (expected on|off)" >&2
  exit 1
fi

"$ROOT_DIR/scripts/init-project.sh" --stack "$STACK" --docker "$DOCKER"
"$ROOT_DIR/scripts/install-hooks.sh"

if [[ "$APPLY_RULESET" == "on" ]]; then
  cmd=("$ROOT_DIR/scripts/apply-ruleset.sh" --docker "$DOCKER" --solo "$SOLO" --enforcement "$ENFORCEMENT" --require-code-scanning-high "$REQUIRE_CODE_SCANNING_HIGH")
  if [[ -n "$REPO" ]]; then
    cmd+=(--repo "$REPO")
  fi
  if [[ "$STRICT_REQUIRED" == "true" ]]; then
    cmd+=(--strict-required)
  fi
  "${cmd[@]}"
else
  echo "Skipped ruleset apply (--apply-ruleset off)."
fi

echo "Bootstrap complete."
