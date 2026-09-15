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
- **Menu-bar only.** No Dock-first UI. **No separate settings window** (no traffic-lights titled prefs). V1 sections stay in the popover. When V2 **Notif** ships, it stays in the popover too — **do not** add a Notif segment in V1. `LSUIElement`.
- **Open source** (MIT). No telemetry. No stealth network.
- **Do not claim watt numbers you did not measure.** Do not cite other products’ watt studies or invent comparisons. Agrypnos stands alone — do not name competitors in product docs or commits.
- **Do not promise every agent provider.** V1 is Cursor, Claude Code, and Codex, local heuristics, correctness over coverage.
- **Do not kill Wi-Fi or Bluetooth.** Out of scope forever unless a later spec says otherwise.
- **Armed ≠ black screen.** Toggling Keep the watch must **not** call `displaysleepnow`, blank the panel, or kill the keyboard backlight while the lid is open. Do not claim “we force display asleep”, “screen off”, or “dim ≠ asleep / real display sleep” for the toggle — V1 lid-close honesty is **brightness floor + keyboard off**.

## V1 scope

Ship these, and stop:

| Piece | Behavior |
|---|---|
| Menu-bar extra + popover | Cards, toggles, duration (presets + custom minutes), remappable hotkey, low-battery slider (5–100%), brightness floor %, idle wait, brightness return 1/2/3s, thermal auto-off (Power toggle, default ON), launch-at-login, quit. Agrypnos glyph (eye, not a coffee cup). **Plain captions only** — every control says what it does (armed / waiting for lid close → brightness floor + keyboard backlight off). No poetry. **No separate settings window** — controls stay in the popover behind the V1 section switcher (**Watch** · **Power** · **Agents** · **General**). |
| Global hotkey | Activate/toggle the watch. Default `⌥⌘A`. **Remappable** in the popover (conflict-safe). Required V1. Surface bind failure honestly when the chord cannot register. |
| Keep the watch (armed) | ON = **armed** while the lid is open. Machine may already be held awake (`pmset disablesleep` / SleepDisabled) as needed for the watch, but **no** display blank, **no** `displaysleepnow`, **no** keyboard backlight off on toggle. |
| Lid-closed keep-awake | With the watch armed, lid close keeps the Mac awake via `pmset disablesleep` (SleepDisabled). IOKit assertions do **not** survive lid close; use them only as extra idle prevention, never as the lid story. |
| Lid-close hygiene | On lid **close** (not on toggle): set brightness to the **user floor %** (default **15%**, range 1–40; never 0%) and turn **keyboard backlight off**. Brightness write only — not display sleep, not “screen off”. Do **not** use `displaysleepnow` for this path. |
| Lid-open restore | If the lid opens again while the watch is still armed (timer/agents not finished): gradual brightness ramp (**1 / 2 / 3 s**, default **2s**) + keyboard backlight on. |
| Hold until end | Stay armed until the selected timer ends or Agents mode waits the settle buffer after local busy signals stop (then allow sleep). |
| Auto-off timer | Segmented presets `∞` / `1h` / `3h` / `Agents`, plus **custom minutes** (e.g. 33) the user can set. |
| Auto-off low battery | Slider **5–100%**, default 15%, on discharging battery. |
| Thermal auto-off | Power toggle, **default ON**. ON (unchanged): while armed, auto-off on `ProcessInfo.thermalState` `.serious` or `.critical`. OFF: skip that thermal path (battery / timer / Agents / LPM unchanged). Toggle only — not °C, not SMC sensors. |
| Low Power Mode | Auto-off when LPM is on and discharging **unless** the user deliberately armed this session (forced watch). **Copy honesty:** do not show “ended / standing down” copy while the Mac is still held awake by that forced watch. |
| Agent watch | Busy → stay awake. After **local busy signals** stop, wait **user settle grace** (`agentSettleGrace`: **2m–15m**, default **2m** / 120s; prefs below 2m clamp up) then allow sleep. Cursor + Claude Code + Codex first. Process + session/transcript mtimes; Claude/Codex may also use CPU. Not think-detection. |
| Safety | Reboot clears SleepDisabled. Launch-at-login never re-arms the watch. One-time scoped sudoers grant for *exactly* two `pmset disablesleep` commands. |

### V1 popover sections (landed)

Section switcher is **landed**: **Watch** · **Power** · **Agents** · **General**. Default open **Watch**. Still **no** settings window.

- Top of the popover: slim section switcher. Prefer native segmented control / quiet text. Toolbar *position* like macOS prefs is fine; **do not** copy icon+blue-tile prefs chrome.
- Card map:
  - **Watch:** Keep the watch (arm) + duration presets/custom + arming caption
  - **Power:** brightness floor % + keyboard backlight off, battery auto-off, brightness return ramp, thermal auto-off toggle (default ON; unlocked)
  - **Agents:** idle wait after local busy signals stop (per-tool include still locked until Mac prove)
  - **General:** remappable hotkey, launch at login, quit
- No **Licence** tab. No **About** as a toolbar tab. No **Notif** segment in V1.
- Goal: shorter height per section; reduce long scroll when possible.
- Plain captions only (personality rules below).

### V1 settings (popover only)

**Landed** (popover only — no settings window; README should name them):

- Remappable global hotkey (default still `⌥⌘A`)
- Custom duration in minutes (beyond fixed presets)
- Low-battery auto-off threshold **5–100%** (default 15%)
- Brightness floor **%** — Core + popover control; default **15%**; range 1–40; never 0%; lid-close uses this floor (brightness write only — not display sleep, not “screen off”)
- Idle wait after local busy signals stop (`agentSettleGrace`) — Core + popover control; **2 minutes – 15 minutes**; default **2 minutes** (120s). Never advertise 15s or 30s as the min. Existing prefs below 2m clamp up to 2m. Then allow sleep in Agents mode.
  - **What:** settle buffer after **local busy signals** stop (process + session/transcript mtimes; Claude/Codex may also use CPU).
  - **Why:** a quiet gap mid-run (tool pause, think with no file write) can look “done” and the Mac may sleep too soon. The buffer keeps Agents mode from sleeping between those gaps.
  - **Not:** not a stuck-agent detector; not mind-reading; we do **not** know “still thinking” or “agent finished the job.” Ban copy that claims that.
  - Title may stay short (e.g. “Wait after agents go idle” or “Idle wait”). Help carries the detail, in this spirit: “How long to wait after local busy signals stop, before allowing sleep. Agents mode needs this buffer so a quiet gap mid-run (no file write / low CPU) doesn’t look finished and sleep the Mac. Not still thinking — we only see local process and session activity.”
- Brightness return when the lid opens — Core + popover control; **1 / 2 / 3 s**, default **2s**

**Unlocked (Core + Agrypnos UI):** thermal auto-off — Power toggle, **default ON**. ON: while armed, `.serious` / `.critical` ends the watch. OFF: skip that path in Core (battery / timer / Agents / LPM unchanged). Stays in Power with floor / battery / ramp. No settings window. Plain caption only (thermal pressure turns the watch off). Ban °C, “safe temp”, health-gauge, warranty claims. Duration / arming copy must not say thermal still applies when the toggle is off.

Still **locked** until Boss unlocks after Mac prove:

- Status-item remaining time
- Per-tool Agents include list

**Gated:** donate — no donate control until there is a live URL.

### V2 park (do not implement)

**Notif** section/tab for opt-in Discord webhook / user Telegram bot (token + chat id). One-shot POST on agents idle-while-armed (after the idle wait). Default off. Secrets in Keychain. No shared Agrypnos bot. No companion app. No stealth network / telemetry.

Plain copy: POST to *your* webhook. Not “we notify your phone”. Not “agent stopped” — only idle after wait.

Two-way remote commands and rich status (task text / finish ETA) stay idea-only. Do not invent them as V2 scope beyond one-way outbound notify.

### Out of V1

App Store sandbox, notarization pipeline, every provider, fake benchmarks, Wi-Fi/BT kill, Dock UI, separate settings window, **Licence** tab, **About** as a toolbar tab, **Notif**, donate without a live URL, `displaysleepnow` on engage, claiming display sleep or “screen off” when we only floored brightness, think-detection / “still thinking” claims, opt-in panel sleep (parked / idea-only — do not unlock).

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
| **UI** | Menu bar, popover (section switcher + cards), personality copy, glyph | Kernel sleep flag |
| **Review** | Gates. File size, TDD, no watt fiction, no god files, no false display-sleep claims, plain popover copy, no false ended-copy under LPM forced-watch, no settings window, no Licence/About tabs, Notif is V2, donate gated on live URL | Shipping unreviewed slop |
| **Boss** | Sequence, merge order, “stop, this is V2” | Writing all the code |

Parallel foundations are forbidden. One track. If you find a second scaffold, delete yours or stop.

## Personality / popover copy

Warm and direct. Not a mascot. Not a coffee-cup clone. Light personality in **tone** is fine; capability captions must be **plain**.

**Hard:** every popover caption says what the control does. Ban mysterious metaphors for real behavior — no “kill the keys,” “floor the panel,” “sleeps with you,” or vague “when they settle” / “go quiet” as the only explanation. (Internal/product terms like *settle grace* in this file are fine; idle-wait **title** may stay short; **help** must say local busy signals → settle buffer → allow sleep. Ban “still thinking” / “agent finished.”)

Good: “Armed. Waiting for lid close — then brightness floor + keyboard backlight off. Auto-off at 15% battery.”
Good: “Stays awake while agents are busy. Allows sleep after they go idle.” (short Agents-mode caption is fine; idle-wait **help** must carry the buffer.)
Good: “How long to wait after local busy signals stop, before allowing sleep. Agents mode needs this buffer so a quiet gap mid-run (no file write / low CPU) doesn’t look finished and sleep the Mac. Not still thinking — we only see local process and session activity.”
Good: “Keeps the Mac awake with the lid closed.”
Good: “Thermal pressure turns the watch off.”
Bad: “Sleeps with you when the lid closes.” / “I’ll floor the panel and kill the keys.” / “When they settle, sleep may return.”
Bad: “after the agent finishes thinking” / “we know it’s still thinking” / “when the job is done.”
Bad: °C, “safe temp”, health-gauge, or warranty claims for thermal auto-off.
Bad: “World-class AI-powered sleep prevention maximizing battery.” / “We force the display asleep on toggle.” / “Lid close turns the screen off.”
Bad: ended/standing-down copy while Low Power Mode forced-watch is still holding the Mac awake.
Bad: “We notify your phone.” / “Agent stopped.” (Notif is V2; event is idle after wait; POST to *your* webhook.)

## OSS

MIT. No analytics. Privileged work is the sudoers grant — keep it two exact commands, `visudo -c` before install, document it in `SECURITY.md`.
