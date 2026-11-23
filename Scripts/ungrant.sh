#!/usr/bin/env bash
# Remove the Agrypnos sudoers grant.
set -euo pipefail
DST="/etc/sudoers.d/agrypnos-disablesleep"
SUDO="sudo"
[ "$(id -u)" -eq 0 ] && SUDO=""
# Clear the wake hold first, while the grant still allows it. Without the grant, a hold left on
# by a running watch would stay until reboot and the Mac would not sleep with the lid closed.
$SUDO /usr/bin/pmset -a disablesleep 0
echo "Lid-close sleep is back on (disablesleep 0)."
if [ -f "$DST" ]; then
  $SUDO rm -f "$DST"
  echo "Removed $DST"
else
  echo "No grant at $DST"
fi
$SUDO visudo -c >/dev/null
echo "sudoers still parses."
