# Agrypnos V1 scope

Status: foundation track. Implement this, not a second personality.

## User / business goal

A human closes a MacBook lid overnight while Cursor / Claude Code / Codex work. The machine must stay up. The display must actually sleep. The keyboard must go dark. Keep the watch stays on until the user turns it off. Safety auto-offs exist so the notebook is not cooked or drained.

## Personality

Playful with the user, professional in the mechanism. Greek *agrypnos* = sleepless. Eye / night-watch, not a coffee cup. Not a Sleepless clone.

## Acceptance (map to tests where noted)

1. Menu-bar extra only (`LSUIElement`). Popover with cards: master toggle, segmented duration (`∞` / `1h` / `3h` / `Agents`), low-battery slider, launch-at-login, quit. Agrypnos copy.
2. Global hotkey toggles the watch. Default Option-Command-A.
3. Engaged watch sets `pmset -a disablesleep 1` and reads `SleepDisabled` back. Disengage sets `0`.
4. Engage requests real display sleep, keyboard backlight off, brightness floor. Lid-close while engaged re-applies those, not brightness 0 as the sleep method.
5. Auto-off: battery floor while discharging, thermal serious/critical, leftover Low Power Mode on battery (hard battery floor always wins). Timer and Agents idle do not auto-off.
6. Agents mode: busy holds awake; after busy, idle for grace may POST (Notif). Does not disarm. Cursor + Claude Code + Codex only. Process + session mtime. (Core tests.)
7. Launch at login never re-arms SleepDisabled.
8. No watt claims in UI or README. No Wi-Fi/BT kill. No file over 600 lines.

## Edge / error

- Missing sudoers grant: one native auth prompt, then retry. Never spin a password TTY in a GUI.
- `SleepDisabled` readback disagrees with intent: UI follows the kernel, not hope.
- Agent paths missing: treat as not busy.
- Reboot: watch is off.

## Out of scope

Every provider, App Store sandbox, measured watt marketing, remote access, Dock UI.
