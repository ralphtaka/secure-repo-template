#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/apply-ruleset.sh [--repo owner/name] [--docker on|off] [--enforcement active|evaluate|disabled] [--name ruleset-name] [--dry-run]

Examples:
  ./scripts/apply-ruleset.sh --repo owner/project --docker off
  ./scripts/apply-ruleset.sh --docker on
EOF
}

REPO=""
DOCKER="off"
ENFORCEMENT="active"
RULESET_NAME="main-security-baseline"
DRY_RUN="false"

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
    --enforcement)
      ENFORCEMENT="${2:-}"
      shift 2
      ;;
    --name)
      RULESET_NAME="${2:-}"
      shift 2
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

if [[ "$ENFORCEMENT" != "active" && "$ENFORCEMENT" != "evaluate" && "$ENFORCEMENT" != "disabled" ]]; then
  echo "Invalid --enforcement value: $ENFORCEMENT (expected active|evaluate|disabled)" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required. Install GitHub CLI first." >&2
  exit 1
fi

if [[ -z "$REPO" ]]; then
  remote_url="$(git remote get-url origin 2>/dev/null || true)"
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

checks=("dependency-review" "trivy-pr" "gitleaks" "codeql" "ci")
if [[ "$DOCKER" == "on" ]]; then
  checks+=("container-scan" "dockerfile-lint")
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
        "required_approving_review_count": 1,
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
    }
  ]
}
EOF

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Repo: $REPO"
  echo "Docker checks enabled: $DOCKER"
  echo "Ruleset name: $RULESET_NAME"
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
