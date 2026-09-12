#!/usr/bin/env bash
# Remove the Agrypnos sudoers grant.
set -euo pipefail
DST="/etc/sudoers.d/agrypnos-disablesleep"
SUDO="sudo"
[ "$(id -u)" -eq 0 ] && SUDO=""
if [ -f "$DST" ]; then
  $SUDO rm -f "$DST"
  echo "Removed $DST"
else
  echo "No grant at $DST"
fi
$SUDO visudo -c >/dev/null
echo "sudoers still parses."
