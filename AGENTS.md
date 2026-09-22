# Agrypnos — agent bar

Agrypnos is a native Swift macOS **menu-bar extra**. It keeps a Mac awake with the lid closed while coding agents work, then lets the machine sleep when you turn the watch off, when Agents stay idle through the wait, or on safety auto-off. Personality: warm and direct — playful tone is fine, mysterious capability copy is not. Greek *agrypnos* = sleepless. It is not a Sleepless clone and it is not a watt-marketing page.

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
- **Menu-bar only.** No Dock-first UI. **No separate settings window** (no traffic-lights titled prefs). Sections stay in the popover. Switcher is **Watch · Power · Agents · Notif · General** — Notif is the landed V2 slice in that order. Still no Licence/About tabs. `LSUIElement`.
- **Open source** (MIT). No telemetry. No stealth network.
- **Do not claim watt numbers you did not measure.** Do not cite other products’ watt studies or invent comparisons. Agrypnos stands alone — do not name competitors in product docs or commits.
- **Do not promise every agent provider.** V1 is Cursor, Claude Code, Codex, and OpenCode. Local heuristics only. Correctness over coverage. Still not every provider. Still not think-detection.
- **Do not kill Wi-Fi or Bluetooth.** Out of scope forever unless a later spec says otherwise.
- **Armed ≠ black screen.** Toggling Keep the watch must **not** call `displaysleepnow`, blank the panel, or kill the keyboard backlight while the lid is open. Do not claim “we force display asleep”, “screen off”, or “dim ≠ asleep / real display sleep” for the toggle — V1 lid-close honesty is **brightness floor + keyboard off**.

## V1 scope

Ship these, and stop:

| Piece | Behavior |
|---|---|
| Menu-bar extra + popover | Cards, toggles, duration (presets + custom minutes), remappable hotkey, low-battery slider (5–100%), brightness floor %, idle wait, brightness return 1/2/3s, thermal auto-off (Power toggle, default ON), launch-at-login, quit. Agrypnos glyph (eye, not a coffee cup). **Plain captions only** — every control says what it does (armed / waiting for lid close → brightness floor + keyboard backlight off). No poetry. **No separate settings window** — V1 controls stay in the popover. **Notif** is landed V2 in the same switcher (see Popover sections), not a V1 add-on. |
| Global hotkey | Activate/toggle the watch. Default `⌥⌘A`. **Remappable** in the popover (conflict-safe). Required V1. Surface bind failure honestly when the chord cannot register. |
| Keep the watch (armed) | ON = **armed** while the lid is open. Machine may already be held awake (`pmset disablesleep` / SleepDisabled) as needed for the watch, but **no** display blank, **no** `displaysleepnow`, **no** keyboard backlight off on toggle. |
| Lid-closed keep-awake | With the watch armed, lid close keeps the Mac awake via `pmset disablesleep` (SleepDisabled). IOKit assertions do **not** survive lid close; use them only as extra idle prevention, never as the lid story. |
| Lid-close hygiene | On lid **close** (not on toggle): set brightness to the **user floor %** (default **15%**, range 1–40; never 0%) and turn **keyboard backlight off**. Brightness write only — not display sleep, not “screen off”. Do **not** use `displaysleepnow` for this path. |
| Lid-open restore | If the lid opens again while the watch is still armed: gradual brightness ramp (**1 / 2 / 3 s**, default **2s**) + keyboard backlight on. Keep the watch and How long stay as the user set them. |
| Hold until user off | Stay armed until the user turns Keep the watch off, except duration **Agents**: after local busy this arm then idle through the wait, turn Keep the watch off. Timer must not flip How long. Agents idle must not flip How long (it stays **Agents**). Battery / thermal / leftover LPM still apply. |
| Auto-off timer | Segmented presets `∞` / `1h` / `3h` / `Agents`, plus **custom minutes** (e.g. 33) the user can set. Remembered only — they do not auto-off. |
| Auto-off low battery | Slider **5–100%**, default 15%, on discharging battery. |
| Thermal auto-off | Power toggle, **default ON**. ON (unchanged): while armed, auto-off on `ProcessInfo.thermalState` `.serious` or `.critical`. OFF: skip that thermal path (battery / leftover LPM unchanged). Toggle only — not °C, not SMC sensors. |
| Low Power Mode | Auto-off when LPM is on and discharging **unless** the user deliberately armed this session (forced watch). **Copy honesty:** do not show “ended / standing down” copy while the Mac is still held awake by that forced watch. |
| Agent watch | Busy → stay awake. After **local busy signals** stop, wait **user settle grace** (`agentSettleGrace`: **2m–15m**, default **2m** / 120s; prefs below 2m clamp up) then idle-after-wait POST if Notif is on **and** `disengage(.agentsSettled)` so Keep the watch turns off. Never-busy this arm: no POST, no disarm. How long stays **Agents**. Providers: Cursor, Claude Code, Codex, and OpenCode. Local heuristics only. Busy signals only from the user’s multi-select (require ≥1 selected; default all four ON). Process + session/transcript mtimes, including nested `/subagents/*.jsonl` within `sessionFreshness` (45s) only when that parent tool is selected (Cursor path); Claude/Codex may also use CPU. OpenCode: local process + session files (prove on Mac). Not think-detection. Not every provider. |
| Safety | Reboot clears SleepDisabled. Launch-at-login never re-arms the watch. One-time scoped sudoers grant for *exactly* two `pmset disablesleep` commands. |

### Popover sections (landed)

Switcher is **landed**: **Watch** · **Power** · **Agents** · **Notif** · **General**. Default open **Watch**. Still **no** settings window. Notif is the landed V2 slice in that order — not “next allowed,” not a V1 add-on.

- Top of the popover: slim section switcher. Prefer native segmented control / quiet text. Toolbar *position* like macOS prefs is fine; **do not** copy icon+blue-tile prefs chrome.
- Card map:
  - **Watch:** Keep the watch (arm) + duration presets/custom + arming caption + last-end honesty (caption-only last watch end from real `DisengageReason`)
  - **Power:** brightness floor % + keyboard backlight off, battery auto-off, brightness return ramp, thermal auto-off toggle (default ON; unlocked)
  - **Agents:** idle wait after local busy signals stop + per-tool include (multi-select; implement next)
  - **Notif:** opt-in idle-after-wait POST (default OFF); Discord URL; Telegram token + chat id; dotted fields + reveal; clear secrets
  - **General:** remappable hotkey, launch at login, quit
- No **Licence** tab. No **About** as a toolbar tab. Do not drop **Notif** from the switcher. Do not add Licence/About.
- Goal: shorter height per section; reduce long scroll when possible.
- Plain captions only (personality rules below).

### Menu-bar status item (landed)

While Keep the watch is on: **Armed.** for ∞ / 1h / 3h / custom minutes, **Agents.** when How long is Agents. Off is the glyph only. Non-countdown. Do not invent remaining-time digits unless Core has a real end clock that will turn the watch off. Agents idle-after-wait is not that clock. Ban “1h left” / ticking remaining when How long does not auto-off.

### Settings (popover only)

**Landed** (popover only — no settings window; README should name them):

- Remappable global hotkey (default still `⌥⌘A`)
- Custom duration in minutes (beyond fixed presets)
- Low-battery auto-off threshold **5–100%** (default 15%)
- Brightness floor **%** — Core + popover control; default **15%**; range 1–40; never 0%; lid-close uses this floor (brightness write only — not display sleep, not “screen off”)
- Idle wait after local busy signals stop (`agentSettleGrace`) — Core + popover control; **2 minutes – 15 minutes**; default **2 minutes** (120s). Never advertise 15s or 30s as the min. Existing prefs below 2m clamp up to 2m. Gates the idle-after-wait POST **and** turning Keep the watch off in Agents mode.
  - **What:** settle buffer after **local busy signals** from selected tools stop (process + session/transcript mtimes, including nested `/subagents/*.jsonl` within 45s when that parent tool is selected; Claude/Codex may also use CPU; OpenCode: local process + session files, prove on Mac).
  - **Why:** a quiet gap mid-run (tool pause, think with no file write) can look “done” and fire Notif / turn the watch off too soon. The buffer keeps that from happening between those gaps.
  - **Not:** not a stuck-agent detector; not mind-reading; we do **not** know “still thinking” or “agent finished the job.” Ban copy that claims that.
  - Title may stay short (e.g. “Wait after agents go idle” or “Idle wait”). Help carries the detail, in this spirit: “How long to wait after local busy signals stop, before the idle-after-wait POST. Then Keep the watch turns off. Buffer so a quiet gap mid-run (no file write / low CPU) doesn’t look finished. Not still thinking — we only see local process and session activity.”
- Brightness return when the lid opens — Core + popover control; **1 / 2 / 3 s**, default **2s**
- Last-end honesty — Watch caption-only card. Last watch end from a real `DisengageReason` (time + reason). No history log, no invented reasons.
- **Notif** — V2 slice, popover-only, **landed**. Do not grow it.
  - **One-way outbound only.** One-shot POST when Agents mode is armed, local busy signals were **seen this arm**, then stayed quiet through the idle wait (`agentSettleGrace`). Event is **idle after wait**, not “agent stopped / job done / still thinking.” Never-busy this arm is not that event — do not POST. That same settle also turns Keep the watch off. Do not POST for timer, battery, thermal, LPM, or manual off. Outbound body uses the same idle-after-wait honesty (ban “agent stopped” / “job finished” there too).
  - **Default OFF.** One opt-in. Discord fires only if a webhook URL is set; Telegram fires only if token **and** chat id are set. Empty fields: no POST, no shared bot.
  - **Channels:** (1) Discord **incoming webhook URL** the user creates in their own server; (2) Telegram **user’s own bot** — token + chat id from BotFather / `getUpdates`. **No shared Agrypnos bot. No companion app. No telemetry / stealth network.**
  - **Secrets** (webhook URL / bot token / chat id) live in Application Support (`notif-secrets.json`, mode 0600). **Not Keychain** — unsigned builds prompt for the login password, which looks like Agrypnos wants the Mac password. Never plaintext prefs, logs, or README examples with real secrets. Popover fields are dotted; an eye button reveals the value.
  - **UI:** **Notif** after Agents: **Watch · Power · Agents · Notif · General**. Default still **Watch**. Controls: opt-in (default OFF); Discord URL field; Telegram token + chat id fields; reveal buttons on those fields; clear/remove that deletes the saved file. Still **no** separate settings window. Still no Licence/About tabs.
  - **Plain copy:** “POST to *your* webhook” / “message *your* Telegram bot”. Ban “we notify your phone”, “agent stopped”, “job finished”.
  - **Honesty:** the user owns the webhook/bot. Agrypnos only POSTs when Notif is enabled and the matching secrets are set.
  - **Docs:** `SECURITY.md` allows opt-in POST to the user’s webhook/bot; still no telemetry / stealth network. Do not write “no network calls” as an absolute.
  - **Self-serve docs (required):**
    - README: step-by-step Discord (Server Settings → Integrations → Webhooks → New Webhook → copy URL) and Telegram (BotFather `/newbot` → token; message the bot; get chat id via `getUpdates` or a clear equivalent). What to paste where in Agrypnos. How to test (arm Agents, produce a local busy signal, wait idle, expect one POST, then Keep the watch off). How to turn off / clear secrets.
    - In-app Notif help must point at the same steps (short in the popover; full detail in README, linked or paraphrased).
  - **Out of this slice (idea-only):** two-way remote (arm/disarm/status via bot) and rich status (task text / ETA). Not Notification Center as the V2 path. Do not invent them.

**Unlocked (Core + Agrypnos UI):** thermal auto-off — Power toggle, **default ON**. ON: while armed, `.serious` / `.critical` ends the watch. OFF: skip that path in Core (battery / leftover LPM unchanged). Stays in Power with floor / battery / ramp. No settings window. Plain caption only (thermal pressure turns the watch off). Ban °C, “safe temp”, health-gauge, warranty claims. Duration / arming copy must not say thermal still applies when the toggle is off.

**Gated:** donate — no donate control until there is a live URL.

### Unlocked (implement next)

**Per-tool Agents include** — Core + Agrypnos UI. Boss unlocked. Multi-select. Implement this. Do not grow it. Do not treat it as parked. No separate “track all” toggle. Status item stays landed (do not reopen it here).

- Popover **Agents**: multi-select checkboxes or toggles for **Cursor · Claude Code · Codex · OpenCode**. The user picks any subset at once. Selecting every listed tool is how all of them count as busy.
- **Default:** all four ON. Existing installs keep Cursor, Claude Code, and Codex ON, and OpenCode defaults ON — same result as a new install: all current providers on.
- **Empty selection:** forbidden. Require **≥1** selected. Clamp back to the previous selection (or reject the change) so the saved set is never empty. Empty does not mean “watch no agents” and does not mean “watch everything.”
- Busy signals only from **selected** tools. Nested `/subagents/*.jsonl` counts only when the parent tool is selected (Cursor path).
- OpenCode: local process + session files (prove on Mac). Do not invent session paths in this bar. Cursor, Claude Code, and Codex stay local heuristics (process + session/transcript mtimes; Claude/Codex may also use CPU). Not think-detection. Still not every provider.
- Plain copy: “Which tools count as busy.” Ban “we track every AI” and think-detection claims.

### V2 park (do not implement)

Two-way remote commands and rich status (task text / finish ETA) stay idea-only.

Opt-in panel sleep stays parked / idea-only — do not unlock.

### Out of V1

App Store sandbox, notarization pipeline, providers beyond Cursor, Claude Code, Codex, and OpenCode, fake benchmarks, Wi-Fi/BT kill, Dock UI, separate settings window, **Licence** tab, **About** as a toolbar tab, donate without a live URL, `displaysleepnow` on engage, claiming display sleep or “screen off” when we only floored brightness, think-detection / “still thinking” claims, opt-in panel sleep (parked / idea-only — do not unlock), two-way remote, rich status, a shared Agrypnos bot, Notification Center as the Notif path.

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
- On a Mac: build the app, arm Keep the watch with the lid **open** (screen stays usable), close the lid (brightness floor + keyboard dark), reopen mid-watch (ramp length from prefs + keyboard on), then confirm Agents idle-after-wait turns Keep the watch off (How long stays Agents) and safety auto-off allows sleep. Timed How long presets do not auto-off. Until that happens, say so. Do not claim Mac runtime you did not run.
- Before you call a PR done: line-count check, Core tests, and an honest “works vs needs a Mac” list.

## Git

Commit and push when the work is a coherent slice. Do not ask the user for permission to commit. Prefer small named commits over one dump. Open a PR on the normal cloud-agent path.

**Commit messages (hard):** product-only. Describe the Agrypnos change. Do **not** mention overnight runs, session framing, breakfast, agent drama, or other meta. Do **not** name competing products. Agrypnos is its own project.

**Release tags:** When a new version ships, create an annotated git tag matching `MARKETING_VERSION` / `CFBundleShortVersionString`: `git tag -a vX.Y.Z -m "…"`. Push it with the release: `git push origin vX.Y.Z`. Tag messages follow the same product-only rules as commits. Do not tag unreleased work.

## Fleet roles

| Role | Owns | Does not own |
|---|---|---|
| **Rules** | `AGENTS.md`, this bar, scope fights | Feature code |
| **Swift core** | `AgrypnosCore`, heuristics, watch engine, lid/hygiene, safety | AppKit chrome |
| **UI** | Menu bar, popover (section switcher + cards), personality copy, glyph | Kernel sleep flag |
| **Review** | Gates. File size, TDD, no watt fiction, no god files, no false display-sleep claims, plain popover copy, no false ended-copy under LPM forced-watch, no settings window, no Licence/About tabs, Notif is landed V2 (popover switcher **Watch · Power · Agents · Notif · General**, one-way idle-after-wait, Application Support secrets `0600` + dotted/reveal, self-serve Discord/Telegram, no shared bot, no Keychain login prompt; two-way/rich status stay idea-only), status item is landed (**Armed.** / **Agents.** non-countdown; no fake timer), per-tool Agents include is unlocked implement next (multi-select Cursor · Claude Code · Codex · OpenCode; require ≥1; default all on; no separate track-all toggle; busy signals only from selected tools; OpenCode is local process + session files, prove on Mac), donate gated on live URL | Shipping unreviewed slop |
| **Boss** | Sequence, merge order, “stop” on parked V2 (two-way/rich status, panel-sleep) | Writing all the code |

Parallel foundations are forbidden. One track. If you find a second scaffold, delete yours or stop.

## Personality / popover copy

Warm and direct. Not a mascot. Not a coffee-cup clone. Light personality in **tone** is fine; capability captions must be **plain**.

**Hard:** every popover caption says what the control does. Ban mysterious metaphors for real behavior — no “kill the keys,” “floor the panel,” “sleeps with you,” or vague “when they settle” / “go quiet” as the only explanation. (Internal/product terms like *settle grace* in this file are fine; idle-wait **title** may stay short; **help** must say local busy signals → settle buffer → idle-after-wait POST and Keep the watch off. Ban “still thinking” / “agent finished.”)

Good: “Armed. Waiting for lid close — then brightness floor + keyboard backlight off. Auto-off at 15% battery.”
Good: “Stays on until you turn it off (battery / thermal still apply).”
Good: “Watch turns off after local busy signals stay idle through the wait (battery / thermal still apply).”
Good: “How long to wait after local busy signals stop, before the idle-after-wait POST. Then Keep the watch turns off. Buffer so a quiet gap mid-run (no file write / low CPU) doesn’t look finished. Not still thinking — we only see local process and session activity.”
Good: “Keeps the Mac awake with the lid closed.”
Good: “Thermal pressure turns the watch off.”
Good: “POST to *your* webhook when Agents stay idle after the wait.”
Good: “Message *your* Telegram bot. Agrypnos does not run a shared bot.”
Good: “Armed.” / “Agents.” (status item — landed, not a countdown)
Good: “Which tools count as busy.”
Bad: “Sleeps with you when the lid closes.” / “I’ll floor the panel and kill the keys.” / “When they settle, sleep may return.”
Bad: “We track every AI.”
Bad: “1h 12m remaining” on the status item when How long is remembered-only and will not auto-off.
Bad: “after the agent finishes thinking” / “we know it’s still thinking” / “when the job is done.”
Bad: °C, “safe temp”, health-gauge, or warranty claims for thermal auto-off.
Bad: “World-class AI-powered sleep prevention maximizing battery.” / “We force the display asleep on toggle.” / “Lid close turns the screen off.”
Bad: ended/standing-down copy while Low Power Mode forced-watch is still holding the Mac awake.
Bad: “We notify your phone.” / “Agent stopped.” / “Job finished.” (Notif event is idle after wait; POST to *your* webhook / message *your* Telegram bot.)

## OSS

MIT. No analytics. Privileged work is the sudoers grant — keep it two exact commands, `visudo -c` before install, document it in `SECURITY.md`.
