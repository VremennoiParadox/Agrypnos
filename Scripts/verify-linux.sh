#!/usr/bin/env bash
# Linux-side verification: Core tests + the 600-line cap.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v swift >/dev/null 2>&1; then
  echo "swift not on PATH" >&2
  exit 1
fi

swift test
bash "$ROOT/Scripts/check-file-sizes.sh"
echo "Linux verification passed."
