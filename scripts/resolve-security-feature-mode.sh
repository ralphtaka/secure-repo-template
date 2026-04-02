#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/resolve-security-feature-mode.sh \
    --feature <codeql|dependency-review|sarif-upload> \
    --mode <auto|off|enforce> \
    --repo <owner/name> \
    [--private-repo <true|false>] \
    [--owner-type <User|Organization>] \
    [--token <github-token>]
EOF
}

FEATURE=""
MODE=""
REPO=""
PRIVATE_REPO=""
OWNER_TYPE=""
TOKEN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature)
      FEATURE="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --private-repo)
      PRIVATE_REPO="${2:-}"
      shift 2
      ;;
    --owner-type)
      OWNER_TYPE="${2:-}"
      shift 2
      ;;
    --token)
      TOKEN="${2:-}"
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

if [[ "$FEATURE" != "codeql" && "$FEATURE" != "dependency-review" && "$FEATURE" != "sarif-upload" ]]; then
  echo "Invalid --feature value: $FEATURE (expected codeql|dependency-review|sarif-upload)" >&2
  exit 1
fi

if [[ "$MODE" != "auto" && "$MODE" != "off" && "$MODE" != "enforce" ]]; then
  echo "Invalid --mode value: $MODE (expected auto|off|enforce)" >&2
  exit 1
fi

if [[ -z "$REPO" ]]; then
  echo "--repo is required." >&2
  exit 1
fi

probe_status="skipped"
capability_status="unknown"
capability_detail="not_probed"

if [[ -n "$TOKEN" && "$MODE" == "auto" ]]; then
  api_response="$(curl -sS -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$REPO" 2>/dev/null || true)"
  if [[ -n "$api_response" ]]; then
    capability_probe="$(
      FEATURE_INPUT="$FEATURE" API_RESPONSE_INPUT="$api_response" python3 - <<'PY'
import json
import os

feature = os.environ.get("FEATURE_INPUT", "")
try:
    payload = json.loads(os.environ.get("API_RESPONSE_INPUT", ""))
except Exception:
    print("unknown")
    print("invalid_json")
    sys.exit(0)

security_and_analysis = payload.get("security_and_analysis") or {}

def status_of(name):
    value = security_and_analysis.get(name)
    if isinstance(value, dict):
        return (value.get("status") or "").strip()
    return ""

advanced = status_of("advanced_security")
dependency_graph = status_of("dependency_graph")
code_scanning = status_of("code_scanning")

if feature in ("codeql", "sarif-upload"):
    candidate = advanced or code_scanning
else:
    candidate = dependency_graph

candidate = candidate.lower()
if candidate in {"enabled"}:
    print("enabled")
elif candidate in {"disabled", "not_enabled"}:
    print("disabled")
else:
    print("unknown")
print(candidate if candidate else "missing")
PY
    )"
    capability_status="$(echo "$capability_probe" | sed -n '1p')"
    capability_detail="$(echo "$capability_probe" | sed -n '2p')"
    probe_status="ok"
  else
    probe_status="failed"
    capability_detail="empty_response"
  fi
fi

run_feature="true"
reason="enabled"

case "$MODE" in
  off)
    run_feature="false"
    reason="disabled by mode=off"
    ;;
  enforce)
    run_feature="true"
    reason="enabled by mode=enforce"
    ;;
  auto)
    case "$capability_status" in
      enabled)
        run_feature="true"
        reason="enabled by capability probe"
        ;;
      disabled)
        run_feature="false"
        reason="auto-skip: capability disabled"
        ;;
      *)
        if [[ "$PRIVATE_REPO" == "true" && "$OWNER_TYPE" == "User" ]]; then
          run_feature="false"
          reason="auto-skip fallback for private personal repository (capability unknown)"
        fi
        ;;
    esac
    ;;
esac

echo "mode=$MODE"
echo "run_feature=$run_feature"
echo "reason=$reason"
echo "capability_status=$capability_status"
echo "capability_detail=$capability_detail"
echo "probe_status=$probe_status"
