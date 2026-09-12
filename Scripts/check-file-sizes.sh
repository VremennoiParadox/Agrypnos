#!/usr/bin/env bash
# Fail if any tracked source/doc file exceeds 600 lines.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
limit=600
fail=0
while IFS= read -r file; do
  case "$file" in
    .build/*|.git/*|*.xcodeproj/*|*.png) continue ;;
  esac
  lines=$(wc -l < "$file")
  if [ "$lines" -gt "$limit" ]; then
    echo "TOO LONG ($lines): $file"
    fail=1
  fi
done < <(git ls-files; git ls-files --others --exclude-standard)
if [ "$fail" -ne 0 ]; then
  echo "Files exceed ${limit} lines." >&2
  exit 1
fi
echo "All tracked files are ≤ ${limit} lines (except ignored binaries/xcodeproj)."
