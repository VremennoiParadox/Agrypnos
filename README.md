# Agrypnos

Native Swift menu-bar extra for macOS. Keep the Mac awake with the lid closed while coding agents work, then let it sleep when the watch ends. Greek *agrypnos*: sleepless.

MIT. No telemetry. No stealth network.

## What it does

- **Keep the watch** — ON = armed while the lid is open. The machine may already be held awake (`pmset disablesleep`). The display stays usable; Agrypnos does **not** blank the panel, call `displaysleepnow`, or turn the keyboard backlight off on that toggle.
- **Lid close** — with the watch armed, sleep is blocked via `pmset disablesleep`. Brightness drops to the **floor %** you set (default 15%, range 1–40; never 0%). Keyboard backlight off. Brightness write only — not `displaysleepnow`, not display sleep, not “screen off”.
- **Lid open mid-watch** — brightness ramps back over **1 / 2 / 3 seconds** (default 2s). Keyboard backlight on.
- **Hold until end** — timer (`∞` / `1h` / `3h` / custom minutes) or Agents mode (busy → stay; after local busy signals stop, **idle wait**, then allow sleep).
- **Safety** — low battery (slider 5–100%, default 15%), thermal auto-off on `.serious` / `.critical` (Power toggle, default on), reboot clears SleepDisabled, launch-at-login never re-arms.

V1 agents: Cursor, Claude Code, Codex. Local heuristics (process list + session-file mtimes; Claude/Codex may also use CPU). Correctness over coverage.

## Not this product

- Not an App Store sandbox build (V1).
- Not a watt-marketing page. We do not publish numbers we did not measure.
- Not a promise to detect every agent provider.
- Does **not** kill Wi-Fi or Bluetooth (out of scope unless a later spec says otherwise).
- Does **not** force the display asleep when you arm Keep the watch.
- Does **not** run a shared Discord or Telegram bot, companion app, or stealth network.
- Does **not** “notify your phone,” claim “agent stopped,” or offer two-way remote commands / task text / finish ETA. Notif is one-way POST to *your* webhook or *your* bot, idle after wait.

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

Needs a Mac to run the menu-bar extra. Until someone arms Keep the watch with the lid **open** (screen stays usable), closes the lid (brightness floor + keyboard dark), reopens mid-watch (ramp from prefs + keyboard on), and confirms timer/Agents end allows sleep, do not claim that path is proven.

Until someone proves **Low Power Mode** while the watch is armed (lid open and lid closed) and confirms the Mac stays awake, do not claim LPM cannot force a watch. Until someone proves **lid-closed auto-off** (timer, Agents settle, battery, thermal) **requests sleep** with the lid still closed, do not claim that path.

Until someone proves a **wedge** (clamshell + power + external display, or a sleep assertion Agrypnos did not take) and confirms `pmset disablesleep` is not enough under a closed lid, do not claim Agents detection plus drop-keep-awake is the whole closed-lid story.

## V1 settings (popover only)

V1 controls exist in the menu-bar popover. There is no separate settings window. A slim text switcher at the top shows one section at a time. V1: **Watch** · **Power** · **Agents** · **General**. The popover opens on Watch. Unlocked V2 **Notif** inserts after Agents once that slice lands: **Watch** · **Power** · **Agents** · **Notif** · **General**.

- **Watch:** Keep the watch, duration presets plus custom minutes, arming caption
- **Power:** brightness floor % (default **15%**; range 1–40; never 0%), keyboard backlight off, low-battery auto-off **5–100%** (default 15%), brightness return when the lid opens **1 / 2 / 3 s** (default **2s**), thermal auto-off (default on)
- **Agents:** idle wait after local busy signals stop (**2 minutes – 15 minutes**, default **2 minutes** / 120s; stored prefs below 2m clamp up to 2m) before allowing sleep. Settle buffer on local process and session activity — not “still thinking,” not “agent finished.” Per-tool include still locked.
- **Notif:** (unlocked V2 — implement next) opt-in Discord webhook and/or your Telegram bot. Default off. See [Notif](#notif-unlocked-v2) for self-serve setup.
- **General:** remappable global hotkey (default `⌥⌘A`), launch at login, quit

Still locked until after Mac prove: status-item remaining time, per-tool Agents include list. Donate stays gated until there is a live URL.

## Notif (unlocked V2)

Opt-in. Default **off**. One-way outbound only: a **one-shot POST** when Agents mode is armed and local busy signals stay quiet through the idle wait. The event is **idle after wait** — not “agent stopped,” not “job finished,” not “still thinking.”

You own the destination. Agrypnos does not run a shared bot, a companion app, or telemetry. It only POSTs when Notif is on and the matching secrets are set. Secrets live in Keychain — never in plaintext prefs, logs, or example URLs in this file.

The **Notif** popover section is the next implementation slice (not in the app until that lands). In-app help there should stay short and point at these same steps.

### Discord — your incoming webhook

1. Open Discord and go to **your** server (you need permission to manage webhooks).
2. **Server Settings → Integrations → Webhooks → New Webhook**.
3. Name it, pick the channel, **Copy Webhook URL**.
4. In Agrypnos: menu-bar extra → popover → **Notif** → paste that URL into the Discord field and turn Discord on.
5. Do not paste the URL into chat, screenshots, or issue reports. It is a secret.

The URL looks like `https://discord.com/api/webhooks/…` — this README will not include a real one.

### Telegram — your own bot

1. In Telegram, open **BotFather** and send `/newbot`. Follow the prompts (display name, then a username ending in `bot`).
2. BotFather replies with a **bot token**. Copy it. Treat it as a password.
3. Open the bot you just created and send it a message (tap **Start** or type anything). The bot must have seen you once before `getUpdates` can show a chat id.
4. Get the **chat id**. In a browser, open (replace `YOUR_TOKEN` with the token; do not commit or screenshot it):

   `https://api.telegram.org/botYOUR_TOKEN/getUpdates`

   In the JSON, find `"chat":{"id":` — that number is the chat id. For a private chat it is a positive integer; for a group it is often negative. A clear equivalent is any client that calls the same `getUpdates` method with your token and reads `result[].message.chat.id`.
5. In Agrypnos: popover → **Notif** → paste the **token** and **chat id** into the Telegram fields and turn Telegram on.

Agrypnos does not ship a bot for you to add. If BotFather did not give you the token, you do not have a bot yet.

### What to paste where

| You created | Paste in Agrypnos **Notif** |
|---|---|
| Discord webhook URL | Discord URL field |
| Telegram bot token | Telegram token field |
| Telegram chat id | Telegram chat id field |

Leave a channel empty and off if you do not use it. Either channel, or both, is fine. Nothing is sent while Notif is off.

### How to test

1. Turn **Notif** on and save at least one channel’s secrets.
2. In **Watch**, arm Keep the watch with duration **Agents**.
3. When local busy signals stop, wait the idle wait (**Agents** section; default 2 minutes, range 2–15).
4. Expect **one** Discord webhook POST and/or **one** message from *your* Telegram bot. Copy should say idle after wait — not that the agent stopped or the job finished.
5. If nothing arrives: Notif off, missing/wrong secret, Agents not armed, or busy signals still counting as activity. Agrypnos will not POST to a destination you did not configure.

### Turn off / clear secrets

- Switch **Notif** off in the popover. POSTs stop. Default is off.
- Use the Notif section’s clear/remove control to delete Keychain entries (webhook URL, bot token, chat id).
- On Discord you can also delete the webhook: **Server Settings → Integrations → Webhooks**.
- On Telegram you can revoke or delete the bot in BotFather (`/revoke` or `/deletebot`).

Two-way remote (arm/disarm/status via bot) and rich status (task text / finish ETA) are not this product. Idea-only. Do not expect them.

## Honesty

- Armed ≠ black screen.
- IOKit assertions do not survive lid close; `pmset disablesleep` is the lid story.
- Reboot clears SleepDisabled. That is a feature.
- Launch-at-login never re-arms the watch.
- Notif POSTs only to *your* webhook or *your* bot, and only when enabled with secrets set.

## License

MIT. See [LICENSE](LICENSE).
