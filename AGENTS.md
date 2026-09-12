# Agrypnos — agent bar

Agrypnos is a native Swift macOS **menu-bar extra**. It keeps a Mac awake with the lid closed while coding agents work, then lets the machine sleep when the watch ends. Personality: warm and direct — playful tone is fine, mysterious capability copy is not. Greek *agrypnos* = sleepless. It is not a Sleepless clone and it is not a watt-marketing page.

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
- **Do not claim watt numbers you did not measure.** Do not cite other products’ watt studies or invent comparisons. Agrypnos stands alone — do not name competitors in product docs or commits.
- **Do not promise every agent provider.** V1 is Cursor, Claude Code, and Codex, local heuristics, correctness over coverage.
- **Do not kill Wi-Fi or Bluetooth.** Out of scope forever unless a later spec says otherwise.
- **Armed ≠ black screen.** Toggling Keep the watch must **not** call `displaysleepnow`, blank the panel, or kill the keyboard backlight while the lid is open. Do not claim “we force display asleep” or “dim ≠ asleep / real display sleep” for this path — V1 honesty is **brightness floor + keyboard off on lid close**.

## V1 scope

Ship these, and stop:

| Piece | Behavior |
|---|---|
| Menu-bar extra + popover | Cards, toggles, duration (presets + custom minutes), remappable hotkey, low-battery slider (5–100%), brightness floor %, Agents settle grace, lid-open ramp 1/2/3s, launch-at-login, quit. Agrypnos glyph (eye, not a coffee cup). **Plain captions only** — every control says what it does (armed / waiting for lid close → brightness floor + keyboard backlight off). No poetry. **No separate settings window** — controls stay in the popover. |
| Global hotkey | Activate/toggle the watch. Default `⌥⌘A`. **Remappable** in the popover (conflict-safe). Required V1. Surface bind failure honestly when the chord cannot register. |
| Keep the watch (armed) | ON = **armed** while the lid is open. Machine may already be held awake (`pmset disablesleep` / SleepDisabled) as needed for the watch, but **no** display blank, **no** `displaysleepnow`, **no** keyboard backlight off on toggle. |
| Lid-closed keep-awake | With the watch armed, lid close keeps the Mac awake via `pmset disablesleep` (SleepDisabled). IOKit assertions do **not** survive lid close; use them only as extra idle prevention, never as the lid story. |
| Lid-close hygiene | On lid **close** (not on toggle): set brightness to the **user floor %** (default **15%**, range 5–40; never 0%) and turn **keyboard backlight off**. Do **not** use `displaysleepnow` for this path. |
| Lid-open restore | If the lid opens again while the watch is still armed (timer/agents not finished): gradual brightness ramp (**1 / 2 / 3 s**, default **2s**) + keyboard backlight on. |
| Hold until end | Stay armed until the selected timer ends or Agents mode settles idle (then allow sleep). |
| Auto-off timer | Segmented presets `∞` / `1h` / `3h` / `Agents`, plus **custom minutes** (e.g. 33) the user can set. |
| Auto-off low battery | Slider **5–100%**, default 15%, on discharging battery. |
| Thermal auto-off | `ProcessInfo.thermalState` `.serious` or `.critical`. |
| Low Power Mode | Auto-off when LPM is on and discharging **unless** the user deliberately armed this session (forced watch). **Copy honesty:** do not show “ended / standing down” copy while the Mac is still held awake by that forced watch. |
| Agent watch | Busy → stay awake. Settled idle after **user settle grace** → allow sleep. Cursor + Claude Code + Codex first. Process list + session-file mtimes. |
| Safety | Reboot clears SleepDisabled. Launch-at-login never re-arms the watch. One-time scoped sudoers grant for *exactly* two `pmset disablesleep` commands. |

### V1 settings (popover only)

**Landed** (keep working; README should name them):

- Remappable global hotkey (default still `⌥⌘A`)
- Custom duration in minutes (beyond fixed presets)
- Low-battery auto-off threshold **5–100%** (default 15%)
- Brightness floor **%** (Core math + persist; default **15%**; range 5–40; never 0%; lid-close uses this floor)
- Agents settle grace (Core math + persist; 15s–15m, default 90s)
- Lid-open ramp duration **1 / 2 / 3 s** (Core math + persist; default **2s**)

**Popover chrome next** (still popover only — no settings window):

- Controls for floor %, settle grace, and ramp (Core already reads prefs)

Still **locked** until Boss unlocks after Mac prove:

- Status-item remaining time
- Per-tool Agents include list

Out of V1: App Store sandbox, notarization pipeline, every provider, fake benchmarks, Wi-Fi/BT kill, Dock UI, separate settings window, `displaysleepnow` on engage, claiming display sleep when we only floored brightness.

## Layout

```
Sources/AgrypnosCore/     Portable logic. Linux-testable. No AppKit.
Tests/AgrypnosCoreTests/  TDD for heuristics, timers, state machine.
Apps/Agrypnos/            macOS menu-bar app. AppKit + IOKit. Needs a Mac to run.
Scripts/                  verify-linux.sh, check-file-sizes.sh, Mac build.sh
prd/                      Product scope. Implement against it.
```

`AgrypnosCore` decides. Mac adapters execute (pmset, IOKit, NSStatusItem, Carbon hotkey, lid events).

## Tests and verification

- Pure logic gets tests first. Watch the test fail, then implement.
- On Linux: `swift test` and `Scripts/verify-linux.sh`. That is real evidence for Core.
- On a Mac: build the app, arm Keep the watch with the lid **open** (screen stays usable), close the lid (brightness floor + keyboard dark), reopen mid-watch (ramp length from prefs + keyboard on), then confirm timer/Agents end allows sleep. Until that happens, say so. Do not claim Mac runtime you did not run.
- Before you call a PR done: line-count check, Core tests, and an honest “works vs needs a Mac” list.

## Git

Commit and push when the work is a coherent slice. Do not ask the user for permission to commit. Prefer small named commits over one dump. Open a PR on the normal cloud-agent path.

**Commit messages (hard):** product-only. Describe the Agrypnos change. Do **not** mention overnight runs, session framing, breakfast, agent drama, or other meta. Do **not** name competing products. Agrypnos is its own project.

## Fleet roles

| Role | Owns | Does not own |
|---|---|---|
| **Rules** | `AGENTS.md`, this bar, scope fights | Feature code |
| **Swift core** | `AgrypnosCore`, heuristics, watch engine, lid/hygiene, safety | AppKit chrome |
| **UI** | Menu bar, popover, personality copy, glyph | Kernel sleep flag |
| **Review** | Gates. File size, TDD, no watt fiction, no god files, no false display-sleep claims, plain popover copy, no false ended-copy under LPM forced-watch | Shipping unreviewed slop |
| **Boss** | Sequence, merge order, “stop, this is V2” | Writing all the code |

Parallel foundations are forbidden. One track. If you find a second scaffold, delete yours or stop.

## Personality / popover copy

Warm and direct. Not a mascot. Not a coffee-cup clone. Light personality in **tone** is fine; capability captions must be **plain**.

**Hard:** every popover caption says what the control does. Ban mysterious metaphors for real behavior — no “kill the keys,” “floor the panel,” “sleeps with you,” or vague “when they settle” as the only explanation. (Internal/product terms like *settle grace* in this file are fine; user-facing strings must spell out idle → allow sleep.)

Good: “Armed. Waiting for lid close — then brightness floor + keyboard backlight off. Auto-off at 15% battery.”
Good: “Stays awake while agents are busy. Allows sleep after they go idle.”
Good: “Keeps the Mac awake with the lid closed.”
Bad: “Sleeps with you when the lid closes.” / “I’ll floor the panel and kill the keys.” / “When they settle, sleep may return.”
Bad: “World-class AI-powered sleep prevention maximizing battery.” / “We force the display asleep on toggle.”
Bad: ended/standing-down copy while Low Power Mode forced-watch is still holding the Mac awake.

## OSS

MIT. No analytics. Privileged work is the sudoers grant — keep it two exact commands, `visudo -c` before install, document it in `SECURITY.md`.
