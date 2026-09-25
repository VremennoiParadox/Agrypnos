# Agrypnos

Native Swift menu-bar extra for macOS. Keep the Mac awake with the lid closed while coding agents work, then let it sleep when you turn the watch off, when Agents stay idle through the wait, or on safety auto-off. Greek *agrypnos*: sleepless.

MIT. No telemetry. No stealth network.

## What it does

- **Keep the watch** — ON = armed while the lid is open. The machine may already be held awake (`pmset disablesleep`). The display stays usable; Agrypnos does **not** blank the panel, call `displaysleepnow`, or turn the keyboard backlight off on that toggle.
- **Lid close** — with the watch armed, sleep is blocked via `pmset disablesleep`. Keyboard backlight off. **Power A (default, Dim panel, Mac-proven):** brightness drops to the **floor %** you set (default 15%, range 1–40; never 0%). Brightness write only — not `displaysleepnow`, not display sleep, not “screen off”. Panel stays on (dimmed). **Power B (Sleep panel, Mac-proven):** confirmed lid-close uses real **panel/display** sleep (`displaysleepnow` or equivalent). Panel only — B does **not** turn Keep the watch off and does **not** put the Mac to sleep by itself. Keep the watch still holds closed-lid wake. Agents keep running. Mutually exclusive with A. Same stable lid-close confirm as hygiene — not one raw clamshell flicker.
- **Lid open mid-watch** — **Power A:** brightness ramps back over **1 / 2 / 3 seconds** (default 2s). Keyboard backlight on. **Power B:** ramp chrome is hidden (ramp only applies when restoring from the floor path).
- **Hold until you turn it off** — How long stays as you set it. Timer does not flip Keep the watch. Duration **Agents** turns Keep the watch off after local busy this arm, then idle through the wait. Battery / thermal (and leftover Low Power Mode) still can.
- **Safety** — low battery (slider 5–100%, default 15%), thermal auto-off on `.serious` / `.critical` (Power toggle, default on), reboot clears SleepDisabled, launch-at-login never re-arms.

V1 agents: Cursor, Claude Code, Codex, and OpenCode. Local heuristics only (process list + session-file mtimes; Claude/Codex/OpenCode may also use CPU). OpenCode looks at `~/.local/share/opencode` (or `$XDG_DATA_HOME/opencode`) — local process + session mtime (Mac-proven). Which tools count as busy is a multi-select of those four in the **Agents** popover (at least one stays on; default all on). Busy signals come only from the tools left on. Correctness over coverage. Not every provider.

## Not this product

- Not an App Store sandbox build (V1).
- Not a watt-marketing page. We do not publish numbers we did not measure.
- Not a promise to detect every agent provider.
- Does **not** kill Wi-Fi or Bluetooth (out of scope unless a later spec says otherwise).
- Does **not** force the display asleep when you arm Keep the watch.
- Does **not** run a shared Discord or Telegram bot, companion app, or stealth network.
- Does **not** “notify your phone,” claim “agent stopped,” or invent task text / finish ETA. Task text / finish ETA is **scrapped** — will not implement. Discord webhook is outbound-only — it does not receive commands. Notif outbound stays one-way POST to *your* webhook or *your* Telegram bot, idle after wait.
- Telegram two-way (`/arm` `/disarm` `/status` `/help` on *your* bot) is in Notif. Same token + chat id as outbound. Notif lists the slash commands, asleep honesty, and lid-gated `/disarm`. Wake-miss drain stays Core + Mac wiring. User optical on two-way + polish **passed** (2026-09-24). `/status` dumps live WatchEngine facts (Keep the watch, How long, lid, Agents, last end, safety prefs). User optical on that dump + `/help` **passed** (2026-09-24). Live laptop battery on `/status` is **Mac-proven** (user optical 2026-09-25): `Battery N% · discharging` / `on AC`; omit if unknown; `/help` names it; not a Notif gauge card. Discord inbound (same four commands on *your* Discord bot, not the webhook) is in **Notif** as a separate card (toggle + bot token + channel id). Live Gateway against *your* bot still needs a Mac — **not claimed shipped / not Mac-proven**. **Power A** (Dim panel, floor+ramp, default) and **Power B** (Sleep panel — panel/display sleep only via `displaysleepnow`; Keep the watch still holds the Mac awake; agents keep running) plus the A↔B switch are **Mac-proven** (user optical 2026-09-25). Enriched-status B (task text / finish ETA) is **scrapped** — will not implement. Full steps: [Notif](#notif).

## Privileged work

One-time scoped sudoers grant for **exactly two** `pmset disablesleep` commands. `visudo -c` before install. See [SECURITY.md](SECURITY.md).

## Repo layout

| Path | Role |
|---|---|
| `Sources/AgrypnosCore/` | Portable logic. Linux-testable. No AppKit. |
| `Tests/AgrypnosCoreTests/` | Heuristics, timers, state machine. |
| `Apps/Agrypnos/` | macOS menu-bar extra. AppKit + IOKit. Needs a Mac. |
| `Scripts/` | `verify-linux.sh`, `check-file-sizes.sh`, Mac `build.sh` |
| `prd/` | Product scope. |

`AgrypnosCore` decides. Mac adapters execute (`pmset`, IOKit, `NSStatusItem`, Carbon hotkey, lid events).

## Build

**Linux (Core tests):**

```bash
swift test
./Scripts/verify-linux.sh
```

**macOS (app):**

```bash
./Scripts/build.sh
```

Needs a Mac to run the menu-bar extra. User optical on open-lid brightness **passed** (2026-09-24): arm with the lid open (screen stays usable); confirmed lid close (brightness floor + keyboard dark); reopen mid-watch (ramp + keyboard on, Keep the watch still on); after the watch ends, lid-open use with no surprise dim to floor. User optical on Power A/B and Telegram `/status` live battery **passed** (2026-09-25): Dim panel / Sleep panel picker + caption; A = floor+ramp, panel stays on; B = panel sleeps on confirmed lid close, ramp hides, Keep the watch still holds; A↔B exclusive; `/status` live % matches the Mac menu bar (or omit if unknown); `/help` names live battery. Discord inbound is **not** Mac-proven.

Until someone proves **Low Power Mode** while the watch is armed (lid open and lid closed) and confirms the Mac stays awake, do not claim LPM cannot force a leftover watch. Until someone proves **lid-closed safety auto-off** (battery, thermal) **requests sleep** with the lid still closed, do not claim that path.

Until someone proves a **wedge** (clamshell + power + external display, or a sleep assertion Agrypnos did not take) and confirms `pmset disablesleep` is not enough under a closed lid, do not claim Agents detection plus drop-keep-awake is the whole closed-lid story.

## Settings (popover only)

Controls live in the menu-bar popover. There is no separate settings window. A slim text switcher at the top shows one section at a time. **Watch** · **Power** · **Agents** · **Notif** · **General**. The popover opens on Watch.

- **Watch:** Keep the watch, duration presets plus custom minutes, arming caption, last-end caption (last real watch end)
- **Power:** mutually exclusive panel mode **A** (Dim panel — brightness floor + lid-open ramp, default, Mac-proven) vs **B** (Sleep panel — panel/display sleep on confirmed lid-close via `displaysleepnow`, Mac-proven). B does not turn Keep the watch off and does not put the Mac to sleep by itself. Keep the watch still holds. Agents keep running. Power explains A vs B **in the popover** (Dim panel / Sleep panel picker + a caption under the picker + help; when B is selected, ramp chrome hides and help says why). Brightness floor % (default **15%**; range 1–40; never 0%; Power A). Keyboard backlight off. Low-battery auto-off **5–100%** (default 15%). Brightness return when the lid opens **1 / 2 / 3 s** (default **2s**; Power A; hide while B). Thermal auto-off (default on)
- **Agents:** idle wait after local busy signals stop (**2 minutes – 15 minutes**, default **2 minutes** / 120s; stored prefs below 2m clamp up to 2m) before the idle-after-wait POST and turning Keep the watch off. Settle buffer on local process and session activity — not “still thinking,” not “agent finished.” Which tools count as busy: multi-select Cursor, Claude Code, Codex, and OpenCode. At least one stays selected (default all on). Busy signals come only from the tools left on. Selecting all of them is how every listed tool counts.
- **Notif:** opt-in idle-after-wait POST (default **off**). Opt-in switch, Discord URL (webhook — outbound-only), Telegram token + chat id, Telegram inbound on/off (default **off**, separate from the POST opt-in) with `/arm` `/disarm` `/status` `/help` on *your* bot, Discord inbound on/off (default **off**, separate from outbound and from Telegram inbound) with bot token + channel id on *your* Discord bot (live Gateway still needs a Mac — not claimed shipped / not Mac-proven), and Clear secrets. Wake-miss drain does not apply commands that arrived while the Mac was asleep. Lid-open `/disarm` does not sleep; confirmed lid-closed `/disarm` may `pmset sleepnow`. `/status` dumps live WatchEngine facts (reply copy, not a new Notif control). User optical **passed** (2026-09-24) for Telegram inbound. Live laptop battery on `/status` is **Mac-proven** (user optical 2026-09-25; same reply copy, not a Notif card). Self-serve setup lives in the Notif section; same steps: [Notif](#notif).
- **General:** remappable global hotkey (default `⌥⌘A`), launch at login, quit

The menu-bar extra shows **Armed.** while Keep the watch is on for ∞ / 1h / 3h / custom minutes, and **Agents.** while it is on and How long is Agents. Off is the glyph only. Not a remaining-time countdown — How long timers do not auto-off. Donate stays gated until there is a live URL.

## Notif

Opt-in. Default **off**. Outbound is one-way: a **one-shot POST** when Agents mode is armed, Agrypnos has seen a **local busy signal this arm**, and those signals then stay quiet through the idle wait. The event is **idle after wait** — not “agent stopped,” not “job finished,” not “still thinking.” Timer, battery, thermal, Low Power Mode, and manual off do not send this POST. If nothing was busy this arm, nothing is sent. Discord webhook stays outbound-only.

Core decides; the Mac adapter POSTs to **your** Discord incoming webhook and/or **your** Telegram bot when Notif is on and the matching secrets are set. Paste those secrets in the popover **Notif** section and turn the opt-in on. Discord POSTs only if a URL is set. Telegram POSTs only if both token and chat id are set. Fields show dots; the eye button reveals a paste so you can check it. In-app help in that section has the same steps as below.

You own the destination. Agrypnos does not run a shared bot, a companion app, or telemetry. Secrets live in `~/Library/Application Support/Agrypnos/notif-secrets.json` (mode 0600) — never Keychain (that login-password prompt), never plaintext prefs, logs, or example URLs in this file. Values saved in an older Keychain build are not imported; paste them again.

### Discord — your incoming webhook

1. Open Discord on desktop or the website and go to **your** server (you need permission to manage webhooks).
2. **Server Settings → Integrations → Webhooks → New Webhook**.
3. Name it, pick the channel, **Copy Webhook URL**.
4. Popover → **Notif** → paste that URL into the Discord field and turn Notif on.
5. Do not paste the URL into chat, screenshots, or issue reports. It is a secret.

The URL looks like `https://discord.com/api/webhooks/…` — this README will not include a real one.

This URL is **outbound-only**. Agrypnos POSTs idle-after-wait here. It does **not** receive `/arm` or other commands. Commands need a separate Discord bot — [Discord inbound](#discord-inbound-your-bot).

### Discord inbound (your bot)

A **different** secret from the webhook. Not a shared Agrypnos bot. You own the bot. Default inbound **off**, separate from the outbound POST opt-in and from Telegram inbound. Empty bot token or empty channel id: no inbound. Live Gateway against *your* bot still needs a Mac — **not claimed shipped / not Mac-proven**.

Same command surface as Telegram, on **one shared WatchEngine path**: **`/arm`** **`/disarm`** **`/status`** **`/help`** (Discord-native slash may map to those same commands). No second arm/disarm stack. Replies are facts only. Ban “agent stopped,” “job finished,” “still thinking.” `/status` dumps the same live WatchEngine facts as Telegram (including live battery when known). Enriched-status B (task text / finish ETA) is **scrapped**. Agrypnos does **not** reply while the Mac is asleep (no relay). `/help` keeps the asleep note (if the bot isn’t replying, the Mac is likely asleep / Agrypnos isn’t receiving updates) and lid-gated `/disarm`. Wake-miss drain: commands that arrived while the Mac was asleep are drained without applying **if** anything was queued, then **Missed while asleep.** Do not scrape channel history on wake. Lid-gated `/disarm` is the same as Telegram: lid open or unconfirmed → Keep the watch off, Mac stays awake; confirmed lid-close → Keep the watch off and `pmset sleepnow`. This sleep path is inbound `/disarm` only — not the popover or hotkey. Receive on the Mac — do not set Discord’s Interactions Endpoint URL, and do not open a listen port.

**In Notif:** Discord inbound on/off + short command/help list + bot token + channel id (dotted + reveal). Keep the webhook paste block as outbound-only — never paste the bot token into the webhook field.

1. Open the [Discord Developer Portal](https://discord.com/developers/applications) → **New Application** → name it → **Create**. This is *your* app, not an Agrypnos bot.
2. **Bot** → **Reset Token** → copy the **bot token**. Treat it as a password. Do not paste it into the Discord webhook URL field.
3. Invite the bot to **your** server: **OAuth2 → URL Generator**. Scopes: `bot` and `applications.commands`. Bot permissions: **Send Messages** (smallest that can reply). Copy the generated URL, open it, pick the server, authorize. You need permission to add a bot to that server.
4. In Discord: **User Settings → Advanced → Developer Mode** on. Right-click the channel the bot should take commands in → **Copy Channel ID**. That id is the allowlist (same role as Telegram’s chat id). Commands only from that channel. If it is a server channel, anyone who can post there can send those commands.
5. Popover → **Notif** → Discord inbound: paste the **bot token** and **channel id**, turn **Discord inbound** on (separate from Notif outbound). Agrypnos registers the four slash commands on *your* bot so Discord’s `/` menu matches. Rebuild on a Mac to prove the live Gateway — not claimed Mac-proven.

Agrypnos does not ship a Discord bot for you to add. If the Developer Portal did not give you a bot token, you do not have a bot yet.

### Telegram — your own bot

1. In Telegram, search **@BotFather** and send `/newbot`. Follow the prompts (display name, then a username ending in `bot`).
2. BotFather replies with a **bot token**. Copy it. Treat it as a password.
3. Open the bot you just created and send it a message (tap **Start** or type anything). The bot must have seen you once before `getUpdates` can show a chat id. For a **group**, add the bot to the group and send a message there.
4. Get the **chat id**. In a browser, open (replace `YOUR_TOKEN` with the token; do not commit or screenshot it). The token will sit in that tab’s history — close the tab when you are done:

   `https://api.telegram.org/botYOUR_TOKEN/getUpdates`

   In the JSON, find `"chat":{"id":` — that number is the chat id. Fake shape only:

   `{"ok":true,"result":[{"message":{"chat":{"id":123456789,"type":"private"}}}]}`

   For a private chat the id is a positive integer; for a group it is often negative. A clear equivalent is any client that calls the same `getUpdates` method with your token and reads `result[].message.chat.id`.
5. If `"result":[]` is empty: you opened the URL before messaging the bot, or another client already consumed the update. Message the bot (or the group) again, then reload.
6. Popover → **Notif** → paste the **token** and **chat id** and turn Notif on.

Agrypnos does not ship a bot for you to add. If BotFather did not give you the token, you do not have a bot yet.

### Telegram inbound — /arm /disarm /status /help (your bot)

Same BotFather bot and token as outbound. Not a shared Agrypnos bot. Discord webhook stays outbound-only — Discord inbound is a separate bot (token + channel id), not the webhook. See [Discord inbound](#discord-inbound-your-bot).

**In Notif:** inbound on/off (default **off**, separate from the outbound POST opt-in). When inbound is on and token + chat id are set, Core polls `getUpdates` and **`/arm`** **`/disarm`** **`/status`** **`/help`** (slash; bare arm/disarm/status still work) hit Keep the watch. `/help` is facts only. Agrypnos registers **`setMyCommands`** on *your* bot so Telegram’s `/` menu matches. Only the saved chat id counts; other chats are ignored. Empty token or chat id: no inbound. Replies are facts (armed / disarmed / current status / help). `/status` dumps live WatchEngine facts: Keep the watch on/off; How long mode (∞ / 1h / 3h / custom minutes / Agents — name the mode, no fake countdown; Agents settle is not an end clock); lid open or unconfirmed vs confirmed closed (same `LidCloseConfirm` as hygiene — never report closed on an unconfirmed close); Agents when relevant (selected tools, busy-seen-this-arm, in settle wait); last-end honesty if any (real `DisengageReason` + time); safety prefs (low-battery threshold, thermal auto-off on/off); live laptop battery when known (`Battery 62% · discharging` / `Battery 62% · on AC` — omit if unknown; same sensor as low-battery auto-off). LPM copy honesty as already specified (no ended-copy while forced watch still holds) — omit an LPM line if unknown. Ban invent ETA, “still thinking,” “job finished.” Enriched-status B (task text / finish ETA) is **scrapped** — will not implement. Not “agent stopped,” not “job finished,” not “still thinking.” Agrypnos does **not** reply while the Mac is asleep (no relay). User optical on the facts dump + `/help` **passed** (2026-09-24). Live battery on `/status` **passed** (user optical, 2026-09-25 — live % matches the Mac menu bar, or omit if unknown).

**Leftover drain:** on setup / quit / inbound off, the first `getUpdates` acks leftover messages without running them. That leftover drain is silent and is **not** wake-from-sleep.

**Wake-miss drain:** commands that arrived while the Mac was asleep are drained without applying. The bot then replies **Missed while asleep.** They do not arm or disarm after the fact. A poller restart on wake is this path, not leftover drain.

**Lid-gated `/disarm`:** always clears Keep the watch / the wake hold. Lid **open** or lid-close **not** confirmed: Mac stays awake. Lid-close **confirmed** (same stable closed signal as brightness, not one raw clamshell flicker): also `pmset sleepnow`. This sleep path is inbound `/disarm` only (Telegram landed; Discord inbound uses the same WatchEngine path) — not the popover or hotkey.

When inbound is on:

1. Paste token + chat id as above.
2. Turn **inbound** on in **Notif** (separate from the outbound POST opt-in). Default inbound is off.
3. Chat with *your* bot (the same chat id you saved).
4. Send **`/arm`** **`/disarm`** **`/status`** **`/help`**. Turn inbound off in Notif to stop command handling. Clear secrets still deletes the saved token and chat id.

User optical on Telegram two-way + polish **passed** (2026-09-24): bot menu shows the four slashes; `/help` has the asleep note and lid-gated `/disarm`; commands queued while the Mac is asleep are drained without applying, then **Missed while asleep.** (no reply during sleep); lid-open `/disarm` turns Keep the watch off and does not sleep; confirmed lid-closed `/disarm` turns Keep the watch off and the Mac sleeps.

Core `/status` dumps live WatchEngine facts; `/help` says `/status` returns those facts and includes live battery when known. User optical on the facts dump **passed** (2026-09-24). Live battery % matching the Mac menu bar **passed** (user optical, 2026-09-25).

### What to paste where

| You created | Paste in Agrypnos **Notif** |
|---|---|
| Discord webhook URL | Discord URL field (outbound only — does not receive commands) |
| Discord bot token | Discord inbound bot token field (not the webhook URL) |
| Discord channel id | Discord inbound channel id field |
| Telegram bot token | Telegram token field |
| Telegram chat id | Telegram chat id field |

Use the webhook, Telegram, Discord inbound, or any mix. Leave a field empty if you do not use that channel. Outbound POSTs do not fire while Notif is off, or while the matching outbound secret is missing. Discord inbound is a separate on/off — empty token or channel id: no inbound.

### How to test

1. Turn **Notif** on and save at least one channel’s secrets.
2. In **Watch**, arm Keep the watch with duration **Agents** (`∞` / `1h` / `3h` / custom do not send this POST).
3. Run an agent Agrypnos can see so a **local busy signal** is recorded this arm. Cursor, Claude Code, Codex, and OpenCode all count by default. In **Agents**, leave on only the tools that should count (at least one stays on). OpenCode local process + session files are Mac-proven.
4. Let that go idle, then wait the idle wait (**Agents** section; default 2 minutes, range 2–15).
5. Expect **one** Discord webhook POST and/or **one** message from *your* Telegram bot. Copy should say idle after wait — not that the agent stopped or the job finished. Keep the watch turns off. How long stays **Agents**.
6. If nothing arrives: Notif off, missing/wrong secret, duration was not Agents, this arm never saw busy, or busy signals are still counting as activity. Agrypnos will not POST to a destination you did not configure.

### Turn off / clear secrets

- Switch **Notif** off in the popover. POSTs stop. Default is off.
- Switch Telegram inbound off in **Notif** to stop Telegram command handling. Default inbound is off.
- Switch Discord inbound off in **Notif** to stop Discord command handling. Default Discord inbound is off.
- Use **Clear secrets** in the Notif section to delete the saved webhook URL, bot tokens, chat id, and Discord channel id.
- On Discord you can also delete the webhook: **Server Settings → Integrations → Webhooks**. Reset or delete the inbound bot in the Developer Portal (**Bot → Reset Token**, or delete the application).
- On Telegram you can revoke or delete the bot in BotFather (`/revoke` or `/deletebot`).

Enriched-status B (task text / finish ETA) is not this product. **Scrapped** — will not implement. Discord inbound uses *your* bot token + channel id (webhook stays outbound-only). Live Gateway still needs a Mac — not claimed shipped / not Mac-proven. Do not expect a shared Agrypnos Discord bot.

## Honesty

- Armed ≠ black screen. Power A (Dim panel, default) floors brightness on confirmed lid close — that is not display sleep. Power B (Sleep panel) sleeps the **panel/display only** (`displaysleepnow`). It does **not** turn Keep the watch off and does **not** put the Mac to sleep by itself. Keep the watch still holds the Mac awake. Agents keep running. The Keep the watch toggle never sleeps the panel. Power explains A vs B **in the popover** (Dim panel / Sleep panel picker + caption; Sleep panel hides brightness return). User optical on Power A/B **passed** (2026-09-25).
- IOKit assertions do not survive lid close; `pmset disablesleep` is the lid story.
- Reboot clears SleepDisabled. That is a feature.
- Launch-at-login never re-arms the watch.
- Notif POSTs only to *your* webhook or *your* bot, and only when enabled with secrets set.
- Telegram inbound (`/arm` `/disarm` `/status` `/help`) uses *your* bot when inbound is on and token + chat id are set. No live reply while the Mac is asleep; wake-miss drain does not apply queued commands; lid-open `/disarm` does not sleep the Mac; confirmed lid-closed `/disarm` does. User optical on two-way + polish and on the `/status` dump **passed** (2026-09-24). Notif `/help` names live battery on `/status` when known. Live battery % matching the Mac menu bar **passed** (user optical, 2026-09-25).
- Discord inbound (`/arm` `/disarm` `/status` `/help` on *your* Discord bot) uses a bot token + channel id, not the webhook. Same WatchEngine path and the same wake-miss / lid-gated `/disarm` honesty as Telegram. Default off. Rebuild on a Mac to prove the live Gateway — not claimed shipped / not Mac-proven.
- Open-lid brightness: after the watch ends, lid-open use does not surprise-dim to floor. User optical **passed** (2026-09-24).
- Agents picker + OpenCode local process/session: user optical **passed** (2026-09-24). Still not every provider. Still not think-detection.

## License

MIT. See [LICENSE](LICENSE).
