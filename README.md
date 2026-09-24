# Agrypnos

Native Swift menu-bar extra for macOS. Keep the Mac awake with the lid closed while coding agents work, then let it sleep when you turn the watch off, when Agents stay idle through the wait, or on safety auto-off. Greek *agrypnos*: sleepless.

MIT. No telemetry. No stealth network.

## What it does

- **Keep the watch** — ON = armed while the lid is open. The machine may already be held awake (`pmset disablesleep`). The display stays usable; Agrypnos does **not** blank the panel, call `displaysleepnow`, or turn the keyboard backlight off on that toggle.
- **Lid close** — with the watch armed, sleep is blocked via `pmset disablesleep`. Brightness drops to the **floor %** you set (default 15%, range 1–40; never 0%). Keyboard backlight off. Brightness write only — not `displaysleepnow`, not display sleep, not “screen off”.
- **Lid open mid-watch** — brightness ramps back over **1 / 2 / 3 seconds** (default 2s). Keyboard backlight on.
- **Hold until you turn it off** — How long stays as you set it. Timer does not flip Keep the watch. Duration **Agents** turns Keep the watch off after local busy this arm, then idle through the wait. Battery / thermal (and leftover Low Power Mode) still can.
- **Safety** — low battery (slider 5–100%, default 15%), thermal auto-off on `.serious` / `.critical` (Power toggle, default on), reboot clears SleepDisabled, launch-at-login never re-arms.

V1 agents: Cursor, Claude Code, Codex, and OpenCode. Local heuristics only (process list + session-file mtimes; Claude/Codex/OpenCode may also use CPU). OpenCode looks at `~/.local/share/opencode` (or `$XDG_DATA_HOME/opencode`) — prove that process + session mtime on a Mac before claiming detection. Which tools count as busy is a multi-select of those four in the **Agents** popover (at least one stays on; default all on). Busy signals come only from the tools left on. Correctness over coverage. Not every provider.

## Not this product

- Not an App Store sandbox build (V1).
- Not a watt-marketing page. We do not publish numbers we did not measure.
- Not a promise to detect every agent provider.
- Does **not** kill Wi-Fi or Bluetooth (out of scope unless a later spec says otherwise).
- Does **not** force the display asleep when you arm Keep the watch.
- Does **not** run a shared Discord or Telegram bot, companion app, or stealth network.
- Does **not** “notify your phone,” claim “agent stopped,” or invent task text / finish ETA. Discord webhook is outbound-only. Notif outbound stays one-way POST to *your* webhook or *your* bot, idle after wait.
- Telegram two-way (arm / disarm / status on *your* bot) is Core + Mac poller in this slice. The Notif inbound toggle is a follow-up. Default inbound **off**. Do not claim Mac-proven until a Mac checks arm / disarm / status.

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

Needs a Mac to run the menu-bar extra. Until someone arms Keep the watch with the lid **open** (screen stays usable), closes the lid (brightness floor + keyboard dark), reopens mid-watch (ramp from prefs + keyboard on, Keep the watch still on), do not claim that path is proven.

Until someone proves **Low Power Mode** while the watch is armed (lid open and lid closed) and confirms the Mac stays awake, do not claim LPM cannot force a leftover watch. Until someone proves **lid-closed safety auto-off** (battery, thermal) **requests sleep** with the lid still closed, do not claim that path.

Until someone proves a **wedge** (clamshell + power + external display, or a sleep assertion Agrypnos did not take) and confirms `pmset disablesleep` is not enough under a closed lid, do not claim Agents detection plus drop-keep-awake is the whole closed-lid story.

## Settings (popover only)

Controls live in the menu-bar popover. There is no separate settings window. A slim text switcher at the top shows one section at a time. **Watch** · **Power** · **Agents** · **Notif** · **General**. The popover opens on Watch.

- **Watch:** Keep the watch, duration presets plus custom minutes, arming caption, last-end caption (last real watch end)
- **Power:** brightness floor % (default **15%**; range 1–40; never 0%), keyboard backlight off, low-battery auto-off **5–100%** (default 15%), brightness return when the lid opens **1 / 2 / 3 s** (default **2s**), thermal auto-off (default on)
- **Agents:** idle wait after local busy signals stop (**2 minutes – 15 minutes**, default **2 minutes** / 120s; stored prefs below 2m clamp up to 2m) before the idle-after-wait POST and turning Keep the watch off. Settle buffer on local process and session activity — not “still thinking,” not “agent finished.” Which tools count as busy: multi-select Cursor, Claude Code, Codex, and OpenCode. At least one stays selected (default all on). Busy signals come only from the tools left on. Selecting all of them is how every listed tool counts.
- **Notif:** opt-in idle-after-wait POST (default **off**). Opt-in switch, Discord URL, Telegram token + chat id, and Clear secrets. Telegram inbound (arm / disarm / status on *your* bot) is Core-ready (default **off**; same token + chat id). The inbound on/off control in Notif is a follow-up. Self-serve setup lives in the Notif section; same steps: [Notif](#notif).
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

### Telegram inbound — arm / disarm / status (your bot)

Same BotFather bot and token as outbound. Not a shared Agrypnos bot. Discord webhook stays outbound-only — no Discord inbound here.

Core polls `getUpdates` and drives Keep the watch when inbound is on and token + chat id are set. The popover inbound toggle is a follow-up; inbound stays **off** until that ships (or the Core pref is set). Each time the poller starts, the first successful poll acks already-queued messages without running them, so leftover traffic (setup, app quit, inbound off) does not arm the watch. Do not claim Mac-proven from this README.

When inbound is on:

1. Paste token + chat id as above.
2. Turn **inbound** on in **Notif** (separate from the outbound POST opt-in). Default inbound is off.
3. Chat with *your* bot (the same chat id you saved).
4. Commands: **arm** / **disarm** / **status** — they hit Keep the watch for real. Only the saved chat id counts; other chats are ignored. Empty token or chat id: no inbound. Replies are facts (armed / disarmed / current status). Not “agent stopped,” not “job finished,” not “still thinking.”
5. Turn inbound off in Notif to stop command handling. Clear secrets still deletes the saved token and chat id.

### What to paste where

| You created | Paste in Agrypnos **Notif** |
|---|---|
| Discord webhook URL | Discord URL field |
| Telegram bot token | Telegram token field |
| Telegram chat id | Telegram chat id field |

Use one channel, or both. Leave a field empty if you do not use that channel. Nothing is sent while Notif is off, or while the matching secret is missing.

### How to test

1. Turn **Notif** on and save at least one channel’s secrets.
2. In **Watch**, arm Keep the watch with duration **Agents** (`∞` / `1h` / `3h` / custom do not send this POST).
3. Run an agent Agrypnos can see so a **local busy signal** is recorded this arm. Cursor, Claude Code, Codex, and OpenCode all count by default. In **Agents**, leave on only the tools that should count (at least one stays on). OpenCode’s local process + session-file paths still need a Mac prove.
4. Let that go idle, then wait the idle wait (**Agents** section; default 2 minutes, range 2–15).
5. Expect **one** Discord webhook POST and/or **one** message from *your* Telegram bot. Copy should say idle after wait — not that the agent stopped or the job finished. Keep the watch turns off. How long stays **Agents**.
6. If nothing arrives: Notif off, missing/wrong secret, duration was not Agents, this arm never saw busy, or busy signals are still counting as activity. Agrypnos will not POST to a destination you did not configure.

### Turn off / clear secrets

- Switch **Notif** off in the popover. POSTs stop. Default is off.
- Switch Telegram inbound off to stop command handling (popover toggle is a follow-up; default inbound is off).
- Use **Clear secrets** in the Notif section to delete the saved webhook URL, bot token, and chat id.
- On Discord you can also delete the webhook: **Server Settings → Integrations → Webhooks**.
- On Telegram you can revoke or delete the bot in BotFather (`/revoke` or `/deletebot`).

Rich status (task text / finish ETA) is not this product. Idea-only. Discord inbound is not this product. Do not expect them.

## Honesty

- Armed ≠ black screen.
- IOKit assertions do not survive lid close; `pmset disablesleep` is the lid story.
- Reboot clears SleepDisabled. That is a feature.
- Launch-at-login never re-arms the watch.
- Notif POSTs only to *your* webhook or *your* bot, and only when enabled with secrets set.
- Telegram inbound (arm / disarm / status) uses *your* bot when inbound is on and token + chat id are set. Mac prove remains soft until a Mac checks it.

## License

MIT. See [LICENSE](LICENSE).
