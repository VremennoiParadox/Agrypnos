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
- **Armed ≠ black screen.** Toggling Keep the watch must **not** call `displaysleepnow`, blank the panel, or kill the keyboard backlight while the lid is open. Do not claim “we force display asleep”, “screen off”, or “dim ≠ asleep / real display sleep” for the **toggle** or for **Power A**. Landed lid-close honesty for **Power A** (default) is **brightness floor + keyboard off**. **Power B** (unlocked) is real panel sleep on **confirmed** lid-close only — that claim is mode B only. Never invent display sleep while the lid is open.
- **Floor write gate.** Write the brightness floor **only** when Keep the watch is armed, lid-close is confirmed, **and Power A is selected**. Never write floor while the lid is open. Never write floor after the watch has disengaged (except restoring a **captured** pre-hygiene brightness). Never write floor under Power B. Universal — no M2-only branches.
- **Nil capture = skip.** On disengage / lid-open restore / any restore path: if captured display brightness is nil, **do not write** brightness (do not fall back to floor). Same honesty as keyboard: nil capture never becomes a guess write.
- **Lid confirm before hygiene.** Do not apply lid-close hygiene (Power A floor **or** Power B `displaysleepnow`) on a single raw `AppleClamshellState` edge. Require a **stable closed** signal (debounce / consecutive closed samples — Swift picks the smallest reliable approach; bar only requires stable confirm, not a named algorithm). Unconfirmed close must not apply floor or `displaysleepnow`. No M2-only branches.

## V1 scope

Ship these, and stop:

| Piece | Behavior |
|---|---|
| Menu-bar extra + popover | Cards, toggles, duration (presets + custom minutes), remappable hotkey, low-battery slider (5–100%), brightness floor %, idle wait, brightness return 1/2/3s, thermal auto-off (Power toggle, default ON), launch-at-login, quit. Agrypnos glyph (eye, not a coffee cup). **Plain captions only** — every control says what it does (armed / waiting for lid close → brightness floor + keyboard backlight off). No poetry. **No separate settings window** — V1 controls stay in the popover. **Notif** is landed V2 in the same switcher (see Popover sections), not a V1 add-on. |
| Global hotkey | Activate/toggle the watch. Default `⌥⌘A`. **Remappable** in the popover (conflict-safe). Required V1. Surface bind failure honestly when the chord cannot register. |
| Keep the watch (armed) | ON = **armed** while the lid is open. Machine may already be held awake (`pmset disablesleep` / SleepDisabled) as needed for the watch, but **no** display blank, **no** `displaysleepnow`, **no** keyboard backlight off on toggle. |
| Lid-closed keep-awake | With the watch armed, lid close keeps the Mac awake via `pmset disablesleep` (SleepDisabled). IOKit assertions do **not** survive lid close; use them only as extra idle prevention, never as the lid story. |
| Lid-close hygiene | On **confirmed** lid **close** (not on toggle, not a single raw `AppleClamshellState` edge): turn **keyboard backlight off**. **Power A (default, landed):** set brightness to the **user floor %** (default **15%**, range 1–40; never 0%). Brightness write only — not display sleep, not “screen off”, not `displaysleepnow`. Floor write only while armed + lid confirmed closed + Power A. **Power B (unlocked):** `displaysleepnow` (or equivalent — Core picks the smallest reliable path) instead of the floor. Mutually exclusive with A — never floor + `displaysleepnow` together. This **is** display sleep for B only. Unconfirmed close applies neither. Universal — no M2-only branches. |
| Lid-open restore | **Power A:** if the lid opens again while the watch is still armed: gradual brightness ramp (**1 / 2 / 3 s**, default **2s**) + keyboard backlight on — restore only a **captured** pre-hygiene brightness; if capture is nil, skip the brightness write (do not fall back to floor). **Power B:** hide ramp chrome (ramp only applies when restoring from the floor path); keyboard backlight on. Keep the watch and How long stay as the user set them. |
| Hold until user off | Stay armed until the user turns Keep the watch off, except duration **Agents**: after local busy this arm then idle through the wait, turn Keep the watch off. Timer must not flip How long. Agents idle must not flip How long (it stays **Agents**). Battery / thermal / leftover LPM still apply. |
| Auto-off timer | Segmented presets `∞` / `1h` / `3h` / `Agents`, plus **custom minutes** (e.g. 33) the user can set. Remembered only — they do not auto-off. |
| Auto-off low battery | Slider **5–100%**, default 15%, on discharging battery. |
| Thermal auto-off | Power toggle, **default ON**. ON (unchanged): while armed, auto-off on `ProcessInfo.thermalState` `.serious` or `.critical`. OFF: skip that thermal path (battery / leftover LPM unchanged). Toggle only — not °C, not SMC sensors. |
| Low Power Mode | Auto-off when LPM is on and discharging **unless** the user deliberately armed this session (forced watch). **Copy honesty:** do not show “ended / standing down” copy while the Mac is still held awake by that forced watch. |
| Agent watch | Busy → stay awake. After **local busy signals** stop, wait **user settle grace** (`agentSettleGrace`: **2m–15m**, default **2m** / 120s; prefs below 2m clamp up) then idle-after-wait POST if Notif is on **and** `disengage(.agentsSettled)` so Keep the watch turns off. Never-busy this arm: no POST, no disarm. How long stays **Agents**. Providers: Cursor, Claude Code, Codex, and OpenCode. Local heuristics only. Busy signals only from the user’s multi-select (require ≥1 selected; default all four ON). Process + session/transcript mtimes, including nested `/subagents/*.jsonl` within `sessionFreshness` (45s) only when that parent tool is selected (Cursor path); Claude/Codex may also use CPU. OpenCode: local process + session files (Mac-proven). Not think-detection. Not every provider. |
| Safety | Reboot clears SleepDisabled. Launch-at-login never re-arms the watch. One-time scoped sudoers grant for *exactly* two `pmset disablesleep` commands. |

### Popover sections (landed)

Switcher is **landed**: **Watch** · **Power** · **Agents** · **Notif** · **General**. Default open **Watch**. Still **no** settings window. Notif is the landed V2 slice in that order — not “next allowed,” not a V1 add-on.

- Top of the popover: slim section switcher. Prefer native segmented control / quiet text. Toolbar *position* like macOS prefs is fine; **do not** copy icon+blue-tile prefs chrome.
- Card map:
  - **Watch:** Keep the watch (arm) + duration presets/custom + arming caption + last-end honesty (caption-only last watch end from real `DisengageReason`)
  - **Power:** mutually exclusive panel mode A/B (unlocked; default A) + brightness floor % + keyboard backlight off, battery auto-off, brightness return ramp (visible in A; hide while B), thermal auto-off toggle (default ON; unlocked)
  - **Agents:** idle wait after local busy signals stop + per-tool include multi-select (landed, Mac-proven)
  - **Notif:** landed outbound POST (Discord URL + Telegram token + chat id; dotted + reveal; clear secrets); landed Telegram inbound on/off; landed slash `/arm` `/disarm` `/status` `/help`, wake-miss drain, lid-gated Telegram `/disarm` (Mac-proven); facts-richer `/status` dump + `/help` mirror (Mac-proven, reply copy)
  - **General:** remappable hotkey, launch at login, quit
- No **Licence** tab. No **About** as a toolbar tab. Do not drop **Notif** from the switcher. Do not add Licence/About.
- Goal: shorter height per section; reduce long scroll when possible.
- **Section-switch size:** When the section switcher changes, the popover **height must animate** between section sizes — system / macOS-standard motion (**0.25s ease-in-out**, what UI ships; matching Apple System Settings / menu extras). **No hard cut** / sudden resize. **Reduce Motion** skips the animation. Content may crossfade or swap with the height change; do not leave a blank gap or stretch-distort controls. Prefer native SwiftUI / AppKit layout animation over custom springs that fight the system. Still: native segmented / quiet text switcher; no icon+blue-tile prefs chrome; no settings window; sections stay in the popover.
  - **No cross-section paint:** During and after a section switch, only the **active** section’s cards/chrome may be visible. Outgoing section cards must not remain painted over (or under) the destination — no ghost Watch+Power overlap, no leftover toggles/sliders/labels from another section.
  - **Height hugs active section:** After the switch (and after the height animation settles), popover height must match the active section’s content — no huge empty bottom under short sections; no clipping mid-card while empty space sits below.
- **Honesty:** Mac optical on smooth section-switch **passed** (Watch ↔ Power ↔ Agents ↔ Notif ↔ General — no ghost paint, height hugging). Open-lid brightness and Agents picker / OpenCode process/session **passed** (user optical, 2026-09-24) — do not claim other providers or think-detection from this check.
- Plain captions only (personality rules below).

### Menu-bar status item (landed)

While Keep the watch is on: **Armed.** for ∞ / 1h / 3h / custom minutes, **Agents.** when How long is Agents. Off is the glyph only. Non-countdown. Do not invent remaining-time digits unless Core has a real end clock that will turn the watch off. Agents idle-after-wait is not that clock. Ban “1h left” / ticking remaining when How long does not auto-off.

### Settings (popover only)

**Landed** (popover only — no settings window; README should name them):

- Remappable global hotkey (default still `⌥⌘A`)
- Custom duration in minutes (beyond fixed presets)
- Low-battery auto-off threshold **5–100%** (default 15%)
- Brightness floor **%** — Core + popover control; default **15%**; range 1–40; never 0%; **Power A** confirmed lid-close uses this floor (brightness write only — not display sleep, not “screen off”). Write only when armed + lid confirmed closed + Power A. Never write floor under Power B. Nil capture never writes floor.
- Idle wait after local busy signals stop (`agentSettleGrace`) — Core + popover control; **2 minutes – 15 minutes**; default **2 minutes** (120s). Never advertise 15s or 30s as the min. Existing prefs below 2m clamp up to 2m. Gates the idle-after-wait POST **and** turning Keep the watch off in Agents mode.
  - **What:** settle buffer after **local busy signals** from selected tools stop (process + session/transcript mtimes, including nested `/subagents/*.jsonl` within 45s when that parent tool is selected; Claude/Codex may also use CPU; OpenCode: local process + session files, Mac-proven).
  - **Why:** a quiet gap mid-run (tool pause, think with no file write) can look “done” and fire Notif / turn the watch off too soon. The buffer keeps that from happening between those gaps.
  - **Not:** not a stuck-agent detector; not mind-reading; we do **not** know “still thinking” or “agent finished the job.” Ban copy that claims that.
  - Title may stay short (e.g. “Wait after agents go idle” or “Idle wait”). Help carries the detail, in this spirit: “How long to wait after local busy signals stop, before the idle-after-wait POST. Then Keep the watch turns off. Buffer so a quiet gap mid-run (no file write / low CPU) doesn’t look finished. Not still thinking — we only see local process and session activity.”
- Brightness return when the lid opens — Core + popover control; **1 / 2 / 3 s**, default **2s**. **Power A:** restore captured brightness only; nil capture skips the write (do not fall back to floor). **Power B:** hide this ramp control/chrome while B is selected (ramp only applies when restoring from the floor path).
- Last-end honesty — Watch caption-only card. Last watch end from a real `DisengageReason` (time + reason). No history log, no invented reasons.
- **Per-tool Agents include** — popover-only, **landed**. Do not grow it. No separate “track all” toggle.
  - Popover **Agents**: multi-select checkboxes or toggles for **Cursor · Claude Code · Codex · OpenCode**. The user picks any subset at once. Selecting every listed tool is how all of them count as busy.
  - **Default:** all four ON. Existing installs keep Cursor, Claude Code, and Codex ON, and OpenCode defaults ON — same result as a new install: all current providers on.
  - **Empty selection:** forbidden. Require **≥1** selected. Clamp back to the previous selection (or reject the change) so the saved set is never empty. Empty does not mean “watch no agents” and does not mean “watch everything.”
  - Busy signals only from **selected** tools. Nested `/subagents/*.jsonl` counts only when the parent tool is selected (Cursor path).
  - OpenCode: local process + session files (Mac-proven). Do not invent session paths in this bar. Cursor, Claude Code, and Codex stay local heuristics (process + session/transcript mtimes; Claude/Codex may also use CPU). Not think-detection. Still not every provider.
  - **Honesty:** Mac optical on the Agents picker and OpenCode process/session prove **passed** (user optical, 2026-09-24). Do not claim other providers or think-detection.
  - Plain copy: “Which tools count as busy.” Ban “we track every AI” and think-detection claims.
- **Notif** — V2 slice, popover-only. Outbound idle-after-wait POST is **landed**. Telegram inbound two-way is **landed** (Mac-proven). Telegram inbound polish is **landed** (Mac-proven): BotFather slash menu `/arm` `/disarm` `/status` `/help`, wake-miss drain, lid-gated Telegram `/disarm`. Facts-richer Telegram `/status` dump + `/help` mirror is **landed** (Mac-proven, user optical 2026-09-24): dump live WatchEngine state Agrypnos already knows. Live laptop battery on `/status` is **unlocked** (Core + UI after Review CLEAR + Boss merge of this bar) — extend that dump; reply copy only, not a Notif card. Do not grow past that. Enriched-status B (task text / finish ETA) is **scrapped** — will not implement; Review blocks any PR that adds it.
  - **One-way outbound (landed).** One-shot POST when Agents mode is armed, local busy signals were **seen this arm**, then stayed quiet through the idle wait (`agentSettleGrace`). Event is **idle after wait**, not “agent stopped / job done / still thinking.” Never-busy this arm is not that event — do not POST. That same settle also turns Keep the watch off. Do not POST for timer, battery, thermal, LPM, or manual off. Outbound body uses the same idle-after-wait honesty (ban “agent stopped” / “job finished” there too). Discord **incoming webhook URL** stays **outbound-only** — no Discord inbound in this slice.
  - **Default OFF.** One outbound opt-in. Discord fires only if a webhook URL is set; Telegram outbound fires only if token **and** chat id are set. Empty fields: no POST, no shared bot.
  - **Telegram inbound two-way (landed, Mac-proven).** User’s own bot — **same token** already required for Telegram outbound. Landed commands: **arm** / **disarm** / **status** → real WatchEngine arm/disarm/status (slash or bare). Accept commands only from the saved chat id. Empty token or chat id: no inbound. Default inbound **off** (separate from the outbound POST opt-in). Not a shared Agrypnos bot. Not Discord inbound (webhook stays outbound; Discord bot-token inbound stays idea-only / separate). Arm/disarm replies stay plain armed / disarmed facts. `/status` dumps live WatchEngine state (**reply copy** — not a new Notif popover control; Mac-proven). Ban “agent stopped / job finished / still thinking.” No fake remote-control panel. **Honesty:** Mac optical on Telegram inbound two-way **passed** (user optical, 2026-09-24). Facts-richer `/status` dump + `/help` mirror **passed** (user optical, 2026-09-24). Polish below is the same Mac-proven slice.
  - **Telegram inbound polish (landed, Mac-proven).** Same user’s own bot; no shared Agrypnos bot. Product command list is slash forms **`/arm`** **`/disarm`** **`/status`** plus **`/help`** (facts only) → real WatchEngine arm/disarm/status (`/help` is copy only). Register BotFather **`setMyCommands`** (or equivalent) so the bot menu matches those four. Advertise slash; existing bare-word parse may stay. Do not invent ETA in replies. `/help` keeps the asleep note and lid-gated `/disarm` honesty and says (short) that `/status` returns these watch facts. After live battery ships, `/help` also says (short) that `/status` includes live battery when known.
    - **Wake-miss drain.** No live “Mac asleep” reply while the Mac is sleeping — no relay. `/help` must say: if the bot isn’t replying, the Mac is likely asleep / Agrypnos isn’t polling. On wake: commands that arrived while asleep must be **drained without applying** (auto-apply on wake is a regression); reply facts-only **missed while asleep** (or equivalent plain wording). Ban copy that implies Agrypnos answered during sleep. Leftover drain is **only** setup / quit / inbound off (silent ack-without-apply) — not a poller start that is actually wake/resume. Wake/resume, including a poller restart after sleep, is wake-miss (drain without apply + missed-while-asleep). A still-seeded poll after sleep must not auto-apply.
    - **Lid-gated Telegram `/disarm` only.** If the Mac is awake and the **lid is open** (or lid-close is **not** confirmed): turn Keep the watch off / clear wake hold, **do not** send the Mac to sleep. If the Mac is awake and lid-close is **confirmed** (same stable closed signal as hygiene — not a single raw `AppleClamshellState` edge): turn Keep the watch off / clear wake hold **and** send the Mac to sleep (`pmset sleepnow` or equivalent — Core picks the smallest reliable path). Sleepnow even if Keep the watch was already off — still clear hold. Explain this in `/help`. Lid-open `/disarm` must never sleep the Mac. Unconfirmed close must not sleep. Do not ship “disarm always sleeps.” Popover and hotkey disarm stay as already specified — this sleep path is Telegram `/disarm` only.
  - **Telegram `/status` facts dump (landed, Mac-proven — user optical 2026-09-24).** Dump live WatchEngine state Agrypnos already knows. Facts only. Omit lines that don’t apply or aren’t known. Enriched-status B (task text / finish ETA) is **scrapped** — will not implement; Review blocks any PR that adds it. Ban invent ETA, “still thinking,” “job finished,” think-detection, and a countdown on remembered-only How long (`∞` / `1h` / `3h` / custom do not auto-off; Agents settle is not that clock). `/status` reply includes:
    1. Keep the watch on/off (armed / disarmed)
    2. How long mode: ∞ / 1h / 3h / custom minutes / Agents (name the mode; no fake remaining countdown unless Core has a real end clock that will turn the watch off)
    3. Lid: open or unconfirmed vs confirmed closed (same `LidCloseConfirm` / stable closed signal as hygiene — not a single raw `AppleClamshellState` edge). Never report closed on an unconfirmed close.
    4. Agents (when relevant): selected tools; busy-seen-this-arm?; in settle wait after local busy signals stop? Local heuristics only
    5. Last-end honesty if any: real `DisengageReason` + time (same as Watch caption)
    6. Safety facts that affect the watch: low-battery threshold; thermal auto-off on/off. LPM copy honesty as already specified (no ended-copy while forced watch still holds) — omit an LPM line if that state is unknown; do not invent a sensor. **Unlocked (Core + UI after Review CLEAR + Boss merge of this bar):** live laptop battery — charge % and discharging vs on AC from the same sensor Core already uses for low-battery auto-off. Shape: `Battery 62% · discharging` or `Battery 62% · on AC` (plain equivalent OK). Omit if unknown. Keep the threshold + thermal lines. Reply copy only — not a Notif battery gauge card. Ban time-to-empty, health-gauge / °C / warranty, invent %.
    Soft verify of the dump + `/help` mirror: **passed** (user optical, 2026-09-24). Soft Mac prove of live battery after Core+UI (rebuild; live % matches the Mac; `/help` short mention that `/status` includes live battery when known). Do not claim live battery shipped or Mac-proven until that check.
  - **Channels:** (1) Discord **incoming webhook URL** the user creates in their own server — outbound POST only; (2) Telegram **user’s own bot** — token + chat id from BotFather / `getUpdates` for outbound; same bot for inbound commands. **No shared Agrypnos bot. No companion app. No telemetry / stealth network.**
  - **Secrets** (webhook URL / bot token / chat id) live in Application Support (`notif-secrets.json`, mode 0600). **Not Keychain** — unsigned builds prompt for the login password, which looks like Agrypnos wants the Mac password. Never plaintext prefs, logs, or README examples with real secrets. Popover fields are dotted; an eye button reveals the value.
  - **UI:** **Notif** after Agents: **Watch · Power · Agents · Notif · General**. Default still **Watch**. Controls: outbound opt-in (default OFF); Discord URL field; Telegram token + chat id fields; reveal buttons on those fields; clear/remove that deletes the saved file; **Telegram inbound on/off + short command list / help** (landed; polish landed: slash `/arm` `/disarm` `/status` `/help`, wake-miss, lid-gated `/disarm`; Mac-proven). Facts-richer `/status` is Telegram reply copy (**landed**, Mac-proven), not a new Notif control. Live battery on `/status` is **unlocked** (same reply copy, not a Notif card). Still **no** separate settings window. Still no Licence/About tabs. Still no fake remote-control panel.
  - **Plain copy:** “POST to *your* webhook” / “message *your* Telegram bot” / “Commands on *your* Telegram bot: /arm, /disarm, /status, /help.” Ban “we notify your phone”, “agent stopped”, “job finished”, live-asleep replies, “disarm always sleeps”.
  - **Honesty:** the user owns the webhook/bot. Agrypnos only POSTs when outbound Notif is enabled and the matching secrets are set. Agrypnos only accepts Telegram commands when inbound is on and token + chat id are set, and only while it can poll (Mac awake). No live-asleep reply — no relay. Discord webhook is outbound-only.
  - **Docs:** `SECURITY.md` allows opt-in POST to the user’s webhook/bot and inbound poll/update on that same user bot; still no telemetry / stealth network. Do not write “no network calls” as an absolute. Still no shared bot. Name that confirmed lid-closed Telegram `/disarm` may `pmset sleepnow` (not a new sudoers grant).
  - **Self-serve docs (required):**
    - README: step-by-step Discord (Server Settings → Integrations → Webhooks → New Webhook → copy URL) and Telegram (BotFather `/newbot` → token; message the bot; get chat id via `getUpdates` or a clear equivalent). What to paste where in Agrypnos. How to test outbound (arm Agents, produce a local busy signal, wait idle, expect one POST, then Keep the watch off). How to enable inbound (same BotFather bot; chat with the bot; inbound on in Notif; `/arm` `/disarm` `/status` `/help`). BotFather menu matches those four via `setMyCommands` or equivalent; `/help` asleep note + confirmed lid-gated `/disarm`; `/help` says `/status` returns these watch facts (short) — dump is **landed** (Mac-proven, user optical 2026-09-24); after live battery ships, `/help` also says `/status` includes live battery when known. Wake-miss drain without applying (not leftover setup/quit drain). How to turn off / clear secrets. Discord inbound is not this slice. Do not describe live battery as already shipped.
    - In-app Notif help must point at the same steps (short in the popover; full detail in README, linked or paraphrased).
  - **Out of this slice:** Enriched-status B (task text / finish ETA) is **scrapped** — will not implement; Review blocks any PR that adds it. Live battery on `/status` is **unlocked above**, not that scrapped item. Discord inbound (webhook stays outbound; Discord bot-token inbound) stays parked. Notification Center as the Notif path stays idea-only. Do not invent them. Power A/B is **unlocked** in Power (not this Notif slice).

**Unlocked (Core + Agrypnos UI):** thermal auto-off — Power toggle, **default ON**. ON: while armed, `.serious` / `.critical` ends the watch. OFF: skip that path in Core (battery / leftover LPM unchanged). Stays in Power with floor / battery / ramp. No settings window. Plain caption only (thermal pressure turns the watch off). Ban °C, “safe temp”, health-gauge, warranty claims. Duration / arming copy must not say thermal still applies when the toggle is off.

**Unlocked (Core + Agrypnos UI after Review CLEAR + Boss merge of this bar):** live laptop battery on Telegram `/status` — extend the landed dump. Live charge from the same sensor Core already uses for low-battery auto-off. Shape: `Battery 62% · discharging` or `Battery 62% · on AC` (plain equivalent OK). Omit if unknown. Keep low-battery threshold + thermal on/off lines. Reply copy only — not a Notif battery gauge card. After it ships, `/help` says (short) that `/status` includes live battery when known; keep asleep note + lid-gated `/disarm` + the existing watch-facts line. Soft Mac prove after implement (rebuild; live % matches the Mac). Ban time-to-empty, health-gauge / °C / warranty, invent %. Facts-richer dump stays landed/Mac-proven. Enriched-status B (task text / finish ETA) is **scrapped**. Discord inbound stays parked.

**Unlocked (Core + Agrypnos UI after Review CLEAR + Boss merge of this bar):** Power A/B — mutually exclusive panel modes. Default **A**. Switching A↔B must be clear in **Power** (segmented or equivalent native control). Same gates as hygiene: armed + lid confirmed closed (`LidCloseConfirm` / stable closed — not a single raw `AppleClamshellState` edge). Unconfirmed close must not apply floor or `displaysleepnow`. Keyboard backlight off + battery / thermal / LPM safety still apply under both. Never floor + `displaysleepnow` together.
- **A (default):** current path — brightness floor on confirmed lid-close + lid-open brightness return ramp. Panel stays on (dimmed). Ban copy that claims display sleep / screen off / asleep for mode A. Ramp chrome stays visible.
- **B:** real panel sleep on confirmed lid-close via `displaysleepnow` (or equivalent — Core picks the smallest reliable path). Hide the lid-open ramp control/chrome while B is selected (ramp only applies when restoring from the floor path). Plain copy: display asleep / panel sleeps with confirmed lid close. Honesty: this **is** display sleep for mode B only — do not claim it for A or for the Keep the watch toggle.
Soft Mac prove after implement: A = floor+ramp, no surprise display-sleep claim; B = confirmed lid-close panel actually sleeps; switch A↔B exclusive; open-lid disarm/use does not leave the panel wrongly asleep. Ban watt claims, Wi-Fi/BT kill, inventing sleep while the lid is open. Not claimed shipped. Discord inbound stays parked. Enriched-status B (task text / finish ETA) is **scrapped**.

**Landed (Mac-proven):** facts-richer Telegram `/status` dump + `/help` mirror — dump live WatchEngine state Agrypnos already knows (Keep the watch on/off; How long mode named, no fake countdown on remembered-only; lid open or unconfirmed vs confirmed closed; Agents selected / busy-seen-this-arm / settle-wait when relevant; last-end honesty if any; safety prefs that affect the watch). Reply copy only — not a new Notif popover control. `/help` says (short) that `/status` returns these watch facts; keep asleep note + lid-gated `/disarm`. User optical **passed** 2026-09-24. Ban invent ETA, think-detection, countdown on remembered-only How long. Live battery is **unlocked above**, not claimed shipped. Enriched-status B (task text / finish ETA) is **scrapped**. Discord inbound stays parked.

**Landed (Mac-proven):** Telegram inbound polish — BotFather slash menu `/arm` `/disarm` `/status` `/help` (`setMyCommands` or equivalent); wake-miss drain (no live-asleep reply; drain queued commands without applying; facts-only missed-while-asleep); lid-gated force-sleep on Telegram `/disarm` only (lid open or unconfirmed: clear hold, no sleep; confirmed lid-close: clear hold and `pmset sleepnow`). User optical **passed** 2026-09-24 (all five). Discord inbound stays parked.

**Landed (Mac-proven):** Open-lid brightness — no surprise dim to floor after disengage with the lid open (user optical, 2026-09-24). Floor write only when armed + lid confirmed closed + Power A; nil capture skips the write. Power B must not leave the panel wrongly asleep on open-lid disarm/use (soft-prove after B ships).

**Landed (Mac-proven):** Agents picker optical + OpenCode process/session (user optical, 2026-09-24). Still not every provider. Still not think-detection.

**Gated:** donate — no donate control until there is a live URL.

### V2 park (do not implement)

Discord inbound stays idea-only — webhook is outbound-only; Discord bot-token inbound is a separate slice. Do not unlock.

### Scrapped (will not implement)

Enriched-status B — rich status (task text / finish ETA). Dead. Not parked. Not idea-only. Will not implement. Review blocks any PR that adds task text or a finish ETA to `/status` or elsewhere.

### Out of V1

App Store sandbox, notarization pipeline, providers beyond Cursor, Claude Code, Codex, and OpenCode, fake benchmarks, Wi-Fi/BT kill, Dock UI, separate settings window, **Licence** tab, **About** as a toolbar tab, donate without a live URL, `displaysleepnow` on engage / while the lid is open, claiming display sleep or “screen off” for Power A or for the Keep the watch toggle, think-detection / “still thinking” claims, Discord inbound (webhook stays outbound; Discord bot-token inbound stays idea-only), enriched-status B (task text / finish ETA — **scrapped**, will not implement), a shared Agrypnos bot, Notification Center as the Notif path, inventing ETA in Telegram replies, live-asleep Telegram replies / a sleep relay, applying Telegram commands that arrived while the Mac was asleep, “disarm always sleeps.”

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
- On a Mac: open-lid brightness (arm lid open / confirmed close floor + keyboard dark / reopen ramp / no surprise dim after disengage) **passed** (user optical, 2026-09-24). Until someone confirms Agents idle-after-wait turns Keep the watch off (How long stays Agents) and safety auto-off allows sleep, say so. Timed How long presets do not auto-off. Do not claim Mac runtime you did not run.
- Soft verify (floor write / nil capture): **passed** (user optical, 2026-09-24) — arm → confirmed close → reopen mid-watch (ramp) → end watch → use the Mac with the lid **open** for a while with **no surprise dim to floor**. Missing capture after disengage must not write the floor. Do not apply hygiene on a single raw clamshell flicker.
- Core (Linux): nil display capture must **skip** the brightness write (do not return / fall back to floor) — same honesty as keyboard. Floor write only when armed + lid-close confirmed + Power A. Never write floor under Power B. Unconfirmed close must not apply floor or `displaysleepnow`.
- Soft verify (Telegram two-way + polish): **passed** (user optical, 2026-09-24) — Notif inbound on → `/` menu shows `/arm` `/disarm` `/status` `/help`; `/help` honesty + asleep note; cmds while asleep → on wake “missed while asleep”, no auto-apply; lid open `/disarm` → watch off, Mac stays awake; lid closed (confirmed) `/disarm` → watch off + Mac sleeps. No live-asleep reply.
- Soft verify (facts-richer Telegram `/status`): **passed** (user optical, 2026-09-24) — `/status` lines match live WatchEngine state (armed/disarmed, How long mode, lid open vs confirmed closed, Agents facts when relevant, last-end if any, safety prefs). Omit unknown lines. No ETA, no think-detection, no countdown on remembered-only How long. `/help` names that `/status` returns these watch facts and still has the asleep note + lid-gated `/disarm`.
- Soft verify (live battery on Telegram `/status`): after Core+UI, rebuild; live % matches the Mac (`Battery 62% · discharging` / `Battery 62% · on AC` or plain equivalent; omit if unknown). Keep threshold + thermal lines. `/help` short mention that `/status` includes live battery when known. Ban time-to-empty, health-gauge / °C / warranty, invent %. Do not claim Mac-proven until that check.
- Soft verify (Power A/B): after Core+UI, rebuild. A = confirmed lid-close floor + ramp, no surprise display-sleep claim. B = confirmed lid-close panel actually sleeps (`displaysleepnow` or equivalent); ramp chrome hidden. Switch A↔B exclusive (never floor + `displaysleepnow` together). Open-lid disarm/use does not leave the panel wrongly asleep. Unconfirmed close applies neither. Do not claim Mac-proven until that check.
- Soft verify (Agents picker + OpenCode): **passed** (user optical, 2026-09-24) — Agents multi-select optical; OpenCode local process + session files. Do not claim other providers or think-detection.
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
| **Review** | Gates. File size, TDD, no watt fiction, no god files, no false display-sleep claims for Power A or the Keep the watch toggle, floor write only on armed + confirmed lid close + Power A (not a single raw `AppleClamshellState` edge; never floor under Power B), nil display capture never writes floor, no surprise dim after disengage with the lid open, no M2-only lid/hygiene branches, open-lid brightness is Mac-proven (user optical 2026-09-24), plain popover copy, no false ended-copy under LPM forced-watch, no settings window, no Licence/About tabs, Notif is landed V2 (popover switcher **Watch · Power · Agents · Notif · General**, one-way idle-after-wait, Application Support secrets `0600` + dotted/reveal, self-serve Discord/Telegram, no shared bot, no Keychain login prompt; Telegram two-way is landed and Mac-proven — user’s bot, inbound on/off + command help in Notif, replies are facts only; Telegram inbound polish is landed and Mac-proven — slash `/arm` `/disarm` `/status` `/help` + BotFather `setMyCommands` (or equivalent) so the menu matches; `/help` asleep honesty (if the bot isn’t replying, Mac likely asleep / Agrypnos isn’t polling); no live-asleep reply / no relay; wake-miss drain without applying (auto-apply on wake is a regression) then facts-only missed-while-asleep; Telegram `/disarm` lid-gated only (lid open or unconfirmed: clear hold, never sleep; confirmed lid-close: clear hold and `pmset sleepnow`); do not ship disarm-always-sleeps; popover/hotkey disarm stay as specified (sleep path is Telegram `/disarm` only); facts-richer Telegram `/status` dump + `/help` mirror is landed and Mac-proven (user optical 2026-09-24; reply copy, not a new Notif control; `/help` names these watch facts and keeps asleep note + lid-gated `/disarm`); live laptop battery on `/status` unlocked for Core+UI after this docs merge — same sensor as low-battery auto-off; shape `Battery 62% · discharging` / `Battery 62% · on AC` (omit if unknown); keep threshold + thermal lines; reply copy only, not a Notif battery gauge card; `/help` short mention after it ships; Power A/B unlocked for Core+UI after this docs merge — mutually exclusive; default A (floor+ramp, panel stays on dimmed, ban display-sleep copy for A); B is real panel sleep on confirmed lid-close via `displaysleepnow` (or equivalent); hide ramp chrome while B; never floor+`displaysleepnow` together; same armed + lid-confirm gates; keyboard off + battery/thermal/LPM still apply; still block invent ETA, think-detection, countdown on remembered-only How long, time-to-empty, health-gauge / °C / warranty, invent battery %, `displaysleepnow` on toggle or while the lid is open, watt claims, Wi-Fi/BT kill, shared bot, Discord-fake-inbound, NC-as-Notif; enriched-status B (task text / finish ETA) is **scrapped** — Review blocks any PR that adds it), status item is landed (**Armed.** / **Agents.** non-countdown; no fake timer), per-tool Agents include is landed and Mac-proven (multi-select Cursor · Claude Code · Codex · OpenCode; require ≥1; default all on; no separate track-all toggle; busy signals only from selected tools; OpenCode is local process + session files, Mac-proven; still not every provider, still not think-detection), section-switch popover height must animate (block sudden resize / hard cut; no cross-section paint; height hugs the active section), donate gated on live URL | Shipping unreviewed slop |
| **Boss** | Sequence, merge order, “stop” on parked V2 (Discord inbound); block scrapped B (task text / finish ETA) | Writing all the code |

Parallel foundations are forbidden. One track. If you find a second scaffold, delete yours or stop.

## Personality / popover copy

Warm and direct. Not a mascot. Not a coffee-cup clone. Light personality in **tone** is fine; capability captions must be **plain**.

**Hard:** every popover caption says what the control does. Ban mysterious metaphors for real behavior — no “kill the keys,” “floor the panel,” “sleeps with you,” or vague “when they settle” / “go quiet” as the only explanation. (Internal/product terms like *settle grace* in this file are fine; idle-wait **title** may stay short; **help** must say local busy signals → settle buffer → idle-after-wait POST and Keep the watch off. Ban “still thinking” / “agent finished.” Power B may say the panel sleeps with confirmed lid close — that is the honest B caption, not the “sleeps with you” metaphor.)

Good: “Armed. Waiting for lid close — then brightness floor + keyboard backlight off. Auto-off at 15% battery.” (Power A)
Good: “Armed. Waiting for lid close — then the panel sleeps + keyboard backlight off.” (Power B — after it ships)
Good: “Brightness floor. Panel stays on (dimmed).” (Power A)
Good: “Display asleep on confirmed lid close.” (Power B — after it ships)
Good: “Stays on until you turn it off (battery / thermal still apply).”
Good: “Watch turns off after local busy signals stay idle through the wait (battery / thermal still apply).”
Good: “How long to wait after local busy signals stop, before the idle-after-wait POST. Then Keep the watch turns off. Buffer so a quiet gap mid-run (no file write / low CPU) doesn’t look finished. Not still thinking — we only see local process and session activity.”
Good: “Keeps the Mac awake with the lid closed.”
Good: “Thermal pressure turns the watch off.”
Good: “POST to *your* webhook when Agents stay idle after the wait.”
Good: “Message *your* Telegram bot. Agrypnos does not run a shared bot.”
Good: “Commands on *your* Telegram bot: /arm, /disarm, /status, /help.”
Good: “If the bot isn’t replying, the Mac is likely asleep / Agrypnos isn’t polling.”
Good: “Missed while asleep.”
Good: “/disarm with the lid open turns Keep the watch off and does not sleep the Mac. With the lid confirmed closed it turns Keep the watch off and sends the Mac to sleep.”
Good: “Armed.” / “Disarmed.” / “Keep the watch is on.” (Telegram arm/disarm replies — facts only)
Good: “Keep the watch is on. How long is Agents. Lid open.” (Telegram `/status` — facts only; omit lines that don’t apply)
Good: “Battery 62% · discharging” / “Battery 62% · on AC” (Telegram `/status` live battery after it ships — omit if unknown)
Good: “/status returns Keep the watch, How long, lid, Agents facts when relevant, last watch end, and safety prefs.” (`/help` — short; dump landed)
Good: “/status includes live battery when known.” (`/help` after live battery ships — short)
Good: “Armed.” / “Agents.” (status item — landed, not a countdown)
Good: “Which tools count as busy.”
Bad: “Sleeps with you when the lid closes.” / “I’ll floor the panel and kill the keys.” / “When they settle, sleep may return.”
Bad: “We track every AI.”
Bad: “1h 12m remaining” on the status item or Telegram `/status` when How long is remembered-only and will not auto-off.
Bad: “after the agent finishes thinking” / “we know it’s still thinking” / “when the job is done.”
Bad: °C, “safe temp”, health-gauge, or warranty claims for thermal auto-off or the `/status` battery line.
Bad: “World-class AI-powered sleep prevention maximizing battery.” / “We force the display asleep on toggle.” / “Lid close turns the screen off.” when Power A is selected or when we only floored brightness.
Bad: claiming display sleep / screen off / asleep for Power A. Floor + `displaysleepnow` at once. Inventing panel sleep while the lid is open.
Bad: ended/standing-down copy while Low Power Mode forced-watch is still holding the Mac awake.
Bad: “We notify your phone.” / “Agent stopped.” / “Job finished.” (Notif outbound is idle after wait; POST to *your* webhook / message *your* Telegram bot. Telegram `/status` dumps live watch facts, not that the agent stopped. Arm/disarm replies stay armed/disarmed facts — same ban.)
Bad: inventing a finish ETA or task text in `/status` (enriched-status B — **scrapped**; will not implement; Review blocks).
Bad: “2h remaining” / time-to-empty on the `/status` battery line. Inventing a battery percent when the sensor is unknown. A Notif battery gauge card.
Bad: live “Mac is asleep.” / implying Agrypnos answered during sleep. No relay.
Bad: “Disarm always sleeps the Mac.” / lid-open `/disarm` sending the Mac to sleep.
Bad: applying a Telegram command that arrived while the Mac was asleep as if it ran live.

## OSS

MIT. No analytics. Privileged work is the sudoers grant — keep it two exact commands, `visudo -c` before install, document it in `SECURITY.md`.
