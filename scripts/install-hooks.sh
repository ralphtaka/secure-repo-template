#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ROOT_DIR/.githooks/pre-commit" ]]; then
  echo "Missing hook file: $ROOT_DIR/.githooks/pre-commit" >&2
  exit 1
fi

chmod +x "$ROOT_DIR/.githooks/pre-commit"
git -C "$ROOT_DIR" config core.hooksPath .githooks

echo "Installed local hooks."
echo "- core.hooksPath=.githooks"
echo "- active hook: .githooks/pre-commit"
