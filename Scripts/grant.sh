#!/usr/bin/env bash
# Install a scoped sudoers grant: exactly two pmset disablesleep commands.
set -euo pipefail

DST="/etc/sudoers.d/agrypnos-disablesleep"
USER_NAME="${AGRYPNOS_USER:-${SUDO_USER:-$(id -un)}}"

if [ -z "$USER_NAME" ] || [ "$USER_NAME" = "root" ]; then
  USER_NAME="$(stat -f%Su /dev/console 2>/dev/null || true)"
fi
if [ -z "$USER_NAME" ] || [ "$USER_NAME" = "root" ]; then
  echo "error: could not resolve a non-root user for the grant." >&2
  exit 1
fi

SUDO="sudo"
[ "$(id -u)" -eq 0 ] && SUDO=""

GRANT="$USER_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"

echo "Agrypnos will install this passwordless grant at $DST (root:wheel, 0440):"
echo ""
echo "    $GRANT"
echo ""
echo "It permits ONLY turning lid-close sleep on (1) or off (0)."
if [ "${1:-}" != "--yes" ] && [ "${1:-}" != "-y" ]; then
  read -r -p "Continue? [y/N] " reply
  case "$reply" in [yY]*) ;; *) echo "Aborted."; exit 1 ;; esac
fi

TMP="$(mktemp)"
printf '%s\n' "$GRANT" > "$TMP"
if ! $SUDO visudo -cf "$TMP" >/dev/null; then
  echo "error: generated sudoers failed validation; not installing." >&2
  rm -f "$TMP"
  exit 1
fi
$SUDO install -m 0440 -o root -g wheel "$TMP" "$DST"
rm -f "$TMP"
$SUDO visudo -c >/dev/null
echo "Grant installed ($DST). Reboot still clears SleepDisabled."
