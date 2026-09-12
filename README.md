# Agrypnos

**Lid down. Agents still working. Panel dark when it should be.**

Agrypnos is a native Swift menu-bar extra for Mac. Arm the watch, close the lid, and it keeps the machine awake while your coding agents run — brightness floored and keyboard backlight off under the lid, then back when you open mid-watch.

The name is Greek: *agrypnos*, sleepless. The tone is a night watch that likes you, not a caffeine joke and not a watt brochure.

> We do not publish watt numbers we have not measured on this Mac. Agrypnos wins on **what the hardware is doing** (brightness floor + keyboard dark under a closed lid, lid-closed keep-awake), not on a lab claim we did not run.

## The wedge (measurable, no lab coat required)

| You can check | What Agrypnos does |
|---|---|
| Keep the watch | **Armed** while the lid is open — screen stays usable; no blanking on toggle |
| Lid close | Brightness → floor (lowest) + keyboard backlight off |
| Lid open mid-watch | ~2s gradual brightness ramp + keyboard backlight on |
| Lid closed keep-awake | Kernel `SleepDisabled` via `pmset disablesleep` |
| Agents | Busy stays awake; settled idle allows sleep |
| You | Menu bar + remappable shortcut (default `⌥⌘A`) |

When watched agents go quiet for a grace period, Agrypnos drops the watch and allows sleep. The product difference is power hygiene under the lid — floored brightness and a dark keyboard — plus keep-awake that survives shutting the notebook.

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

1. Click the **eye** in the menu bar (or press the shortcut — default **⌥⌘A**).
2. Flip **Keep the watch** (arms the watch — screen stays usable).
3. Pick how long: **∞**, **1h**, **3h**, **Agents**, or type minutes (33 is a fine watch).
4. Click **Shortcut** and press a chord to remap the hotkey (default **⌥⌘A**). If that chord cannot register, Agrypnos says so and keeps the last live bind.
5. Close the lid when ready. Brightness floors; keyboard goes dark; the Mac stays up.
6. Open mid-watch if you need the panel — ~2s brightness ramp + keyboard back on.
7. Walk away until the timer or Agents settle ends the watch.

**Agents** mode: Agrypnos polls local processes and session files for Cursor, Claude Code, and Codex. If they look busy, the watch holds. After they look idle for a grace period, Agrypnos *allows sleep* (drops `SleepDisabled`). It does not try to be every provider on earth.

Safety nets, always:

- Auto-off at your battery floor (default 15%, slider 5–100%) while discharging
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

Linux contributors: `./Scripts/verify-linux.sh` runs `swift test` and the 600-line file cap. That does **not** prove lid-close or brightness/keyboard hygiene.

## What is verified vs what needs a Mac

| | Linux `swift test` | Needs a Mac |
|---|---|---|
| Agent busy/settle rules | Yes | — |
| Timer / battery / thermal state machine | Yes | — |
| Copy, hotkey chord encoding | Yes | — |
| Menu-bar popover | — | Render + click |
| Armed with lid open (no blank) | — | Flip Keep the watch |
| `SleepDisabled` lid-close | — | Close the lid |
| Brightness floor + keyboard off on lid close | — | Close the lid, eyeball |
| ~2s ramp + keyboard on lid open mid-watch | — | Open mid-watch |
| `⌥⌘A` | — | Press it |
| Launch at login | — | Log out/in |

## Not this project

- Killing Wi-Fi or Bluetooth
- Claiming watt figures we did not measure on this Mac
- Naming competing products in docs or commits
- Every agent vendor
- A Dock app, a dashboard, or a remote-control product
- Files over 600 lines
- Blanking the screen on toggle (`displaysleepnow` on engage)

MIT. No telemetry.
