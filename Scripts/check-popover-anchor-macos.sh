#!/usr/bin/env bash
set -euo pipefail
CHECK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$CHECK_ROOT"
CHECK_DIR="$(mktemp -d)"
trap 'rm -rf "$CHECK_DIR"' EXIT
sources=()
while IFS= read -r -d '' source; do
  sources+=("$source")
done < <(find Sources/AgrypnosCore Apps/Agrypnos/Sources -name '*.swift' \
  ! -name AppMain.swift ! -name AppDelegate.swift -print0)
swiftc -parse-as-library "${sources[@]}" Scripts/check-popover-anchor-macos.swift -o "$CHECK_DIR/anchor-check"
"$CHECK_DIR/anchor-check"
