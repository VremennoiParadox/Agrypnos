# Agrypnos — agent bar

Agrypnos is a native Swift macOS **menu-bar extra**. It keeps a Mac awake with the lid closed while coding agents work, then lets the machine sleep when the watch ends. Personality: playful with the human, still professional. Greek *agrypnos* = sleepless. It is not a Sleepless clone and it is not a watt-marketing page.

This file is the project bar. Follow it. If a request fights this file, stop and say so.

## Model (non-negotiable)

For any coding, architecture, tests, or review on this repo, use **Grok 4.6 Extra High, non-fast**. Do not switch to a fast variant to save time. Do not silently downgrade.

## Session start

Before editing:

1. Read `superpowers:using-superpowers` and follow it.
2. Use **TDD** for testable logic (`superpowers:test-driven-development`).
3. Use **systematic debugging** when something is wrong (`superpowers:systematic-debugging`).
4. Use **verification-before-completion** before claiming done (`superpowers:verification-before-completion`).
5. Request review notes on non-trivial work (`superpowers:requesting-code-review`).

User instructions in this file beat skill ceremony when they conflict (example: the human is asleep and already shipped a spec — implement; do not block on a design interview).

## Taste: ponytail + Karpathy

- **Karpathy:** no slop. Small diffs. Boring Swift. Delete cleverness. Make it work, then make it obvious.
- **Ponytail:** Saturday-senior code. Short files, obvious names, no framework soup, comments only for *why*. If a junior can follow the state machine on one screen, you are done.

No giant god-objects. No “just one more helper” that becomes AppDelegate 2.

## Hard limits

- **No file over 600 lines.** Split *before* you hit the wall. Prefer ~250.
- **Menu-bar only.** No Dock-first UI, no settings window unless V2 asks. `LSUIElement`.
- **Open source** (MIT). No telemetry. No stealth network.
- **Do not claim watt numbers you did not measure.** Do not cite StillOn’s measured watts. Do not say we beat them.
- **Do not promise every agent provider.** V1 is Cursor, Claude Code, and Codex, local heuristics, correctness over coverage.
- **Do not kill Wi-Fi or Bluetooth.** Out of scope forever unless a later spec says otherwise.
- **Dim ≠ asleep.** Forcing brightness to 0 is not display sleep. V1 forces real display sleep and turns the keyboard backlight off.

## V1 scope

Ship these, and stop:

| Piece | Behavior |
|---|---|
| Menu-bar extra + popover | Cards, toggles, segmented duration, low-battery slider, launch-at-login, quit. Agrypnos copy + eye glyph (not a coffee cup). |
| Global hotkey | Activate/toggle the watch. Default `⌥⌘A`. Required V1. |
| Lid-closed keep-awake | `pmset disablesleep` (SleepDisabled). IOKit assertions do **not** survive lid close; use them only as extra idle prevention, never as the lid story. |
| Force display asleep | `pmset displaysleepnow` (and IOKit idle request as fallback). Not brightness 0. |
| Keyboard backlight | Off on engage. Restore on disengage when we can. |
| Brightness floor | On lid close / engage, clamp restored brightness to a floor so we never leave the panel at 0 as fake sleep. |
| Auto-off timer | Segmented: `∞` / `1h` / `3h` / `Agents`. |
| Auto-off low battery | Slider 5–50%, default 15%, on discharging battery. |
| Thermal auto-off | `ProcessInfo.thermalState` `.serious` or `.critical`. |
| Agent watch | Busy → stay awake. Settled idle after grace → allow sleep. Cursor + Claude Code + Codex first. Process list + session-file mtimes. |
| Safety | Reboot clears SleepDisabled. Launch-at-login never re-arms the watch. One-time scoped sudoers grant for *exactly* two `pmset disablesleep` commands. |

Out of V1: App Store sandbox, notarization pipeline, every provider, fake benchmarks, Wi-Fi/BT kill, Dock UI.

## Layout

```
Sources/AgrypnosCore/     Portable logic. Linux-testable. No AppKit.
Tests/AgrypnosCoreTests/  TDD for heuristics, timers, state machine.
Apps/Agrypnos/            macOS menu-bar app. AppKit + IOKit. Needs a Mac to run.
Scripts/                  verify-linux.sh, check-file-sizes.sh, Mac build.sh
prd/                      Product scope. Implement against it.
```

`AgrypnosCore` decides. Mac adapters execute (pmset, IOKit, NSStatusItem, Carbon hotkey).

## Tests and verification

- Pure logic gets tests first. Watch the test fail, then implement.
- On Linux: `swift test` and `Scripts/verify-linux.sh`. That is real evidence for Core.
- On a Mac: build the app, flip the watch, close the lid, confirm display sleep, keyboard dark, agent settle → sleep. Until that happens, say so. Do not claim Mac runtime you did not run.
- Before you call a PR done: line-count check, Core tests, and an honest “works vs needs a Mac” list.

## Git

Commit and push when the work is a coherent slice. Do not ask the user for permission to commit. Prefer small named commits over one dump. Open a PR on the normal cloud-agent path.

## Fleet roles

| Role | Owns | Does not own |
|---|---|---|
| **Rules** | `AGENTS.md`, this bar, scope fights | Feature code |
| **Swift core** | `AgrypnosCore`, heuristics, watch engine, safety | AppKit chrome |
| **UI** | Menu bar, popover, personality copy, glyph | Kernel sleep flag |
| **Review** | Gates. File size, TDD, no watt fiction, no god files | Shipping unreviewed slop |
| **Boss** | Sequence, merge order, “stop, this is V2” | Writing all the code |

Parallel foundations are forbidden. One track. If you find a second scaffold, delete yours or stop.

## Personality

Talk to the user like a night watch that likes them. Not a mascot. Not a clone of anyone’s coffee cup.

Good: “Lid can fall. I’ll keep the panel asleep and the machine awake.”
Bad: “World-class AI-powered sleep prevention maximizing battery.”

## OSS

MIT. No analytics. Privileged work is the sudoers grant — keep it two exact commands, `visudo -c` before install, document it in `SECURITY.md`.
