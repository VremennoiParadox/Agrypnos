# Agrypnos

**Lid down. Display actually asleep. Agents still working.**

Agrypnos is a native Swift menu-bar extra for Mac. It keeps the machine awake with the lid closed while your coding agents run, forces the **display** into real sleep (dim is not sleep), turns the **keyboard backlight** off, and — when you ask it to watch agents — lets the Mac sleep after Cursor, Claude Code, or Codex settle.

The name is Greek: *agrypnos*, sleepless. The tone is a night watch that likes you, not a caffeine joke and not a watt brochure.

> We don’t claim StillOn’s measured watts until we run the same protocol on this Mac. Agrypnos wins on **what the hardware is doing** (display sleep + keyboard dark + brightness floor), not on a number we did not measure.

## The wedge (measurable, no lab coat required)

| You can check | What Agrypnos does | What “dim the screen” apps often do |
|---|---|---|
| Display | `pmset displaysleepnow` — panel power-off | Brightness 0, panel still on |
| Keyboard | Backlight set to off on engage | Left glowing under a closed lid |
| Brightness floor | Clamp restore brightness so 0% is never the sleep trick | Leave the panel at 0 and call it done |
| Lid closed | Kernel `SleepDisabled` via `pmset disablesleep` | `caffeinate` / IOKit idle assertions, which **do not** survive lid close |
| Agents | Busy stays awake; settled idle allows sleep | Always-on until you remember to toggle |
| You | Menu bar + `⌥⌘A` | Dig through a window |

StillOn already markets agent-finish sleep. Agrypnos treats that as table stakes for the *sleep trigger*: when the watched agents go quiet for a grace period, we drop the watch. The product difference is power hygiene — real display sleep and a dark keyboard — plus a lid-closed keep-awake that actually survives shutting the notebook.

## Install / build

Needs a Mac, Apple Silicon or Intel, **macOS 14+**. Xcode 15+ or Command Line Tools.

```sh
git clone https://github.com/VremennoiParadox/Agrypnos.git
cd Agrypnos
./Scripts/build-macos.sh
open dist/Agrypnos.app
```

Or open `Apps/Agrypnos/Agrypnos.xcodeproj` in Xcode and Run. The app is a menu-bar extra (`LSUIElement`): no Dock icon.

**One-time privilege.** Lid-close sleep is a kernel flag. A GUI app cannot flip it without a password unless you grant *exactly two commands*:

```
pmset -a disablesleep 1
pmset -a disablesleep 0
```

Flip the watch once; Agrypnos will offer a native macOS auth sheet that installs a scoped `/etc/sudoers.d` drop-in (see [SECURITY.md](SECURITY.md)). Reboot always clears `SleepDisabled`. Launch-at-login never re-arms the watch.

From Terminal, equivalent grant:

```sh
./Scripts/grant.sh
```

## Using it

1. Click the **eye** in the menu bar (or press **⌥⌘A**).
2. Flip **Keep the watch**.
3. Pick how long: **∞**, **1h**, **3h**, or **Agents**.
4. Close the lid. The Mac should stay up; the display should be asleep; the keys should be dark.
5. Walk away.

**Agents** mode: Agrypnos polls local processes and session files for Cursor, Claude Code, and Codex. If they look busy, the watch holds. After they look idle for a grace period, Agrypnos *allows sleep* (drops `SleepDisabled`). It does not try to be every provider on earth.

Safety nets, always:

- Auto-off at your battery floor (default 15%, slider 5–50%) while discharging
- Auto-off on serious/critical thermal pressure
- Auto-off when Low Power Mode is on and you are on battery (a deliberate flip this session still honors the hard battery floor)

## What “busy” means (honest heuristics)

Correctness over coverage. V1 only:

| Agent | Process names (examples) | Session files (mtime) |
|---|---|---|
| Cursor | `Cursor`, not GPU helper CPU alone | `~/.cursor/projects/*/agent-transcripts/`, `~/.cursor/chats/` |
| Claude Code | `claude` | `~/.claude/projects/**/*.jsonl` (`CLAUDE_CONFIG_DIR` honored) |
| Codex | `codex` | `~/.codex/sessions/**/rollout-*.jsonl` (`CODEX_HOME` honored) |

Busy = process is running **and** (recent session write **or**, for Claude/Codex, meaningful CPU). Cursor open with a stale chat is *not* busy. Stale files with no process are *not* busy. Paths are vendor-undocumented except Claude’s; they can move. We will break loudly in tests when we change the matcher, not by silently adding twelve other tools.

## Repo layout

```
Sources/AgrypnosCore/     State machine, heuristics, timers — tested on Linux
Tests/AgrypnosCoreTests/
Apps/Agrypnos/            Menu bar, IOKit, pmset, hotkey — needs macOS
prd/v1-scope.md           Product scope this code is built against
AGENTS.md                 Bar for coding agents
```

Linux contributors (and overnight agents): `./Scripts/verify-linux.sh` runs `swift test` and the 600-line file cap. That does **not** prove lid-close or display sleep.

## What is verified vs what needs a Mac

| | Linux `swift test` | Needs a Mac |
|---|---|---|
| Agent busy/settle rules | Yes | — |
| Timer / battery / thermal state machine | Yes | — |
| Copy, hotkey chord encoding | Yes | — |
| Menu-bar popover | — | Render + click |
| `SleepDisabled` lid-close | — | Close the lid |
| Display sleep vs dim | — | `pmset -g assertions` / eyeball the panel |
| Keyboard backlight | — | Eyeball the keys |
| Brightness floor | — | Open lid, check brightness |
| `⌥⌘A` | — | Press it |
| Launch at login | — | Log out/in |

## Not this project

- Killing Wi-Fi or Bluetooth
- Claiming StillOn’s measured watts, or any watt figure we did not measure on this Mac
- Every agent vendor
- A Dock app, a dashboard, or a remote-control product
- Files over 600 lines

MIT. No telemetry.
