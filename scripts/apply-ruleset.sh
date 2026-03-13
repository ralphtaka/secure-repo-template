#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/apply-ruleset.sh [--repo owner/name] [--docker on|off] [--solo on|off] [--enforcement active|evaluate|disabled] [--name ruleset-name] [--require-code-scanning-high on|off] [--strict-required] [--dry-run]

Examples:
  ./scripts/apply-ruleset.sh --repo owner/project --docker off
  ./scripts/apply-ruleset.sh --repo owner/project --docker on --require-code-scanning-high on
  ./scripts/apply-ruleset.sh --repo owner/project --solo on
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO=""
DOCKER="off"
SOLO="off"
ENFORCEMENT="active"
RULESET_NAME="main-security-baseline"
DRY_RUN="false"
STRICT_REQUIRED="false"
REQUIRE_CODE_SCANNING_HIGH="off"

checks=()
skipped_checks=()

add_check_if_workflow_exists() {
  local context="$1"
  local workflow_file="$2"
  local workflow_path="$ROOT_DIR/.github/workflows/$workflow_file"

  if [[ -f "$workflow_path" ]]; then
    checks+=("$context")
  else
    skipped_checks+=("$context (missing .github/workflows/$workflow_file)")
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --docker)
      DOCKER="${2:-}"
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
    --name)
      RULESET_NAME="${2:-}"
      shift 2
      ;;
    --require-code-scanning-high)
      REQUIRE_CODE_SCANNING_HIGH="${2:-}"
      shift 2
      ;;
    --strict-required)
      STRICT_REQUIRED="true"
      shift 1
      ;;
    --dry-run)
      DRY_RUN="true"
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

if [[ "$SOLO" != "on" && "$SOLO" != "off" ]]; then
  echo "Invalid --solo value: $SOLO (expected on|off)" >&2
  exit 1
fi

if [[ "$ENFORCEMENT" != "active" && "$ENFORCEMENT" != "evaluate" && "$ENFORCEMENT" != "disabled" ]]; then
  echo "Invalid --enforcement value: $ENFORCEMENT (expected active|evaluate|disabled)" >&2
  exit 1
fi

if [[ "$REQUIRE_CODE_SCANNING_HIGH" != "on" && "$REQUIRE_CODE_SCANNING_HIGH" != "off" ]]; then
  echo "Invalid --require-code-scanning-high value: $REQUIRE_CODE_SCANNING_HIGH (expected on|off)" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required. Install GitHub CLI first." >&2
  exit 1
fi

if [[ -z "$REPO" ]]; then
  remote_url="$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ "$remote_url" =~ ^git@github.com:([^/]+)/([^/.]+)(\.git)?$ ]]; then
    REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  elif [[ "$remote_url" =~ ^https://github.com/([^/]+)/([^/.]+)(\.git)?$ ]]; then
    REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  fi
fi

if [[ -z "$REPO" ]]; then
  echo "Unable to infer --repo from git remote. Provide --repo owner/name." >&2
  exit 1
fi

add_check_if_workflow_exists "dependency-review" "security-pr.yml"
add_check_if_workflow_exists "trivy-pr" "security-pr.yml"
add_check_if_workflow_exists "gitleaks" "secret-scan.yml"
add_check_if_workflow_exists "codeql" "codeql.yml"
add_check_if_workflow_exists "ci" "ci.yml"

if [[ "$DOCKER" == "on" ]]; then
  add_check_if_workflow_exists "container-scan" "container-scan.yml"
  add_check_if_workflow_exists "dockerfile-lint" "dockerfile-lint.yml"
fi

if [[ "$STRICT_REQUIRED" == "true" && ${#skipped_checks[@]} -gt 0 ]]; then
  echo "Strict mode failed: required checks were skipped." >&2
  for item in "${skipped_checks[@]}"; do
    echo "- $item" >&2
  done
  exit 1
fi

if [[ ${#checks[@]} -eq 0 ]]; then
  echo "No status checks detected from enabled workflows. Ruleset was not applied." >&2
  exit 1
fi

required_approving_review_count=1
if [[ "$SOLO" == "on" ]]; then
  required_approving_review_count=0
fi

code_scanning_rule=""
if [[ "$REQUIRE_CODE_SCANNING_HIGH" == "on" ]]; then
  code_scanning_rule='
    ,
    {
      "type": "code_scanning",
      "parameters": {
        "code_scanning_tools": [
          {
            "tool": "CodeQL",
            "alerts_threshold": "none",
            "security_alerts_threshold": "high_or_higher"
          }
        ]
      }
    }'
fi

required_checks_json="["
for check in "${checks[@]}"; do
  required_checks_json+="{\"context\":\"$check\"},"
done
required_checks_json="${required_checks_json%,}]"

payload_file="$(mktemp)"
cleanup() {
  rm -f "$payload_file"
}
trap cleanup EXIT

cat > "$payload_file" <<EOF
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "$ENFORCEMENT",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "bypass_actors": [],
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_approving_review_count": $required_approving_review_count,
        "required_review_thread_resolution": true
      }
    },
    { "type": "non_fast_forward" },
    { "type": "deletion" },
    {
      "type": "required_status_checks",
      "parameters": {
        "required_status_checks": $required_checks_json,
        "strict_required_status_checks_policy": true
      }
    }$code_scanning_rule
  ]
}
EOF

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Repo: $REPO"
  echo "Docker checks enabled: $DOCKER"
  echo "Solo mode: $SOLO"
  echo "Ruleset name: $RULESET_NAME"
  echo "Strict required mode: $STRICT_REQUIRED"
  echo "Code scanning high gate: $REQUIRE_CODE_SCANNING_HIGH"
  echo "Selected required checks:"
  for check in "${checks[@]}"; do
    echo "- $check"
  done
  if [[ ${#skipped_checks[@]} -gt 0 ]]; then
    echo "Skipped checks:"
    for item in "${skipped_checks[@]}"; do
      echo "- $item"
    done
  fi
  cat "$payload_file"
  exit 0
fi

existing_id="$(
  gh api "repos/$REPO/rulesets" \
    --jq ".[] | select(.target == \"branch\" and .name == \"$RULESET_NAME\") | .id" \
    | head -n1
)"

if [[ -n "$existing_id" ]]; then
  gh api --method PUT "repos/$REPO/rulesets/$existing_id" --input "$payload_file" >/dev/null
  echo "Updated ruleset '$RULESET_NAME' (id: $existing_id) on $REPO"
else
  gh api --method POST "repos/$REPO/rulesets" --input "$payload_file" >/dev/null
  echo "Created ruleset '$RULESET_NAME' on $REPO"
fi

echo "Required checks:"
for check in "${checks[@]}"; do
  echo "- $check"
done
echo "Code scanning high gate: $REQUIRE_CODE_SCANNING_HIGH"
echo "Solo mode: $SOLO (required approvals: $required_approving_review_count)"

if [[ ${#skipped_checks[@]} -gt 0 ]]; then
  echo "Skipped checks:"
  for item in "${skipped_checks[@]}"; do
    echo "- $item"
  done
fi
