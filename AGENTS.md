# Agrypnos: notes for contributors and coding agents

Agrypnos is a native Swift menu-bar app for macOS. It keeps a Mac awake with the lid closed while coding agents work. It lets the Mac sleep again when the user turns Keep awake off, a timer ends, the agents' activity has stopped for the user's idle wait, or a safety limit trips (low battery, heat, Low Power Mode).

If an `AGENTS.local.md` file sits next to this one, read it too. It holds the maintainer's fuller rules and wins where the two differ.

## Layout

```
Sources/AgrypnosCore/     Decisions: watch state machine, lid and safety rules, agent heuristics, all copy. No AppKit. Builds and tests on Linux.
Tests/AgrypnosCoreTests/  Core tests.
Tests/AgrypnosMacTests/   Tests for the Mac side.
Apps/Agrypnos/            The menu-bar app: AppKit, IOKit, pmset, hotkey, bots. Carries out what Core decides.
Scripts/                  Build, test, release, sudoers grant, Xcode project generator.
prd/                      Product scope.
```

## Build and test

```bash
swift test                              # all tests
./Scripts/verify-linux.sh               # Core tests + the 600-line cap
./Scripts/build-macos.sh                # dist/Agrypnos.app, ad-hoc signed
python3 Scripts/generate-xcodeproj.py   # after adding or removing app Swift files or resources
```

Write the test first for logic in Core. Lid, display, keyboard, sleep, and bot behavior also need a check on a real Mac. In the PR, say which parts you checked on a Mac and which only passed tests.

## Hard limits

- No file over 600 lines. Split before you get close; around 250 is a good size.
- Menu-bar only (`LSUIElement`). No Dock UI and no settings window. Settings live in the popover sections **Watch · Power · Agents · Notif · General**. The two guide windows (Bot setup, Question setup) hold instructions only.
- MIT. No telemetry or analytics. The only network traffic goes to the user's own Telegram or Discord bot, and only when they turn it on. No shared bot, no Discord webhook, no Interactions Endpoint URL, no listening port.
- The sudoers grant covers exactly `/usr/bin/pmset -a disablesleep 1` and `/usr/bin/pmset -a disablesleep 0`. Don't widen it.
- Supported agents: Cursor, Claude Code, Codex, OpenCode. Busy means local signals only: processes, session-file modification times, CPU. Agrypnos can't tell what an agent is doing, so the app and docs never claim it can.
- Question forwarding: OpenCode and Claude Code. Codex gets waiting alerts only. Cursor gets nothing. Forwarding only happens while Keep awake is on and never turns it on.
- Don't turn off Wi-Fi or Bluetooth.
- No power-saving or watt claims.

## Lid, display, and sleep

These rules keep Agrypnos from surprising someone at the keyboard.

- Turning Keep awake on never touches the display or the keyboard backlight.
- Lid-close effects need a confirmed close (stable readings), never a single raw `AppleClamshellState` change.
- On a confirmed close, **Dim panel** writes the brightness floor and **Sleep panel** runs `displaysleepnow`. Never both. Neither puts the Mac to sleep or turns Keep awake off.
- Restore only a brightness that was captured. No capture, no write.
- Turning Keep awake off (popover, hotkey, `/disarm`) runs `pmset sleepnow` only when the lid is confirmed closed. Lid open or unconfirmed: clear the hold, don't sleep.
- Bot commands that arrived while the Mac slept are never applied on wake. The bot replies "Missed while asleep." instead.

## Copy

Popover captions, bot replies, and the README say plainly what happens. Never write "still thinking", "agent finished", "job done", or "the Mac slept". No ETAs or task text in `/status`. No display-sleep claims for Dim panel. No metaphors standing in for behavior.

The README describes features only, with no testing status.

## Git

- Small commits that each do one thing. Messages describe the change to Agrypnos, not how the work was done.
- Don't name other apps in docs or commits.
- Release: bump the version in `Apps/Agrypnos/Resources/Info.plist` and `Scripts/generate-xcodeproj.py`, regenerate the project, and run `Scripts/release-dmg.sh`. Then tag `vX.Y.Z` (annotated) and attach `dist/Agrypnos.dmg` to the GitHub release.
