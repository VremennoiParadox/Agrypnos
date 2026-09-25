# Security

Agrypnos asks for one privileged trick: lid-close keep-awake via `pmset disablesleep`. Everything else (brightness floor, keyboard backlight, reading battery, polling processes in your account, reading session files in your home) runs as you.

## Sudoers grant

`Scripts/grant.sh` installs **one** drop-in at `/etc/sudoers.d/agrypnos-disablesleep`:

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

- Arguments are literal. No wildcards. `pmset -a sleep 0` still needs a password.
- File mode `0440`, owner `root:wheel`.
- `visudo -c` on the snippet before install.
- Reboot clears `SleepDisabled`. The app does not re-arm at login.

Remove with `Scripts/ungrant.sh` or `sudo rm /etc/sudoers.d/agrypnos-disablesleep`.

## What we read

Agent heuristics look at process names and mtimes of known session paths under your home directory. Transcripts are plaintext; Agrypnos does not upload them and does not parse message bodies in V1 — only modification times.

## Opt-in outbound (Notif)

When Notif outbound is enabled, Agrypnos may POST **once** to **your** Discord incoming webhook and/or **your** Telegram bot after Agents mode has seen local busy this arm and then stayed quiet through the idle wait. Default **off**. Empty fields skip that channel. Secrets (webhook URL, Telegram bot token, chat id) live in `~/Library/Application Support/Agrypnos/notif-secrets.json` (mode 0600), not Keychain and not plaintext prefs. Discord inbound bot token and channel id live in that same file when set — they are not an outbound channel. Values saved in an older Keychain build are not imported; paste them again. This is not telemetry. Agrypnos does not run a shared bot.

## Telegram inbound (your bot)

When Telegram inbound is on, Agrypnos may poll `getUpdates`, register `/arm` `/disarm` `/status` `/help` with `setMyCommands`, and send command replies on **your** BotFather bot using the same token and chat id as outbound. Default **off**. Empty token or chat id: no inbound. Commands are accepted only from the saved chat id. Agrypnos does not reply while the Mac is asleep (no relay). On wake, queued commands are drained without applying (facts-only **missed while asleep**). Confirmed lid-closed `/disarm` may call `pmset sleepnow` (same user-level path as safety auto-off; not a new sudoers grant). Lid-open or unconfirmed `/disarm` must not sleep the Mac. If that id is a group, anyone who can message that group can send those commands. Discord webhook stays outbound-only. This is not telemetry. Agrypnos does not run a shared bot.

## Discord inbound (your bot)

When Discord inbound is on, Agrypnos may receive updates on **your** Discord bot on this Mac (Gateway or equivalent — Core picks the smallest reliable path) and send command replies using a **bot token** and **channel id** stored with the other Notif secrets. Default **off**, separate from outbound Notif and from Telegram inbound. Empty token or empty channel id: no inbound. Commands are accepted only from the saved channel. The incoming webhook URL is never inbound — do not mix them. Do **not** set Discord’s Interactions Endpoint URL. Do **not** open a listen port. Same `/arm` `/disarm` `/status` `/help` WatchEngine path as Telegram (Discord-native slash may map to those commands). Agrypnos does not reply while the Mac is asleep (no relay). On wake, queued commands are drained without applying (facts-only **missed while asleep**) if anything was queued — do not scrape channel history on wake to invent missed commands. Confirmed lid-closed Discord `/disarm` may call `pmset sleepnow` (same user-level path as Telegram `/disarm`; not a new sudoers grant). Lid-open or unconfirmed `/disarm` must not sleep the Mac. If that channel is a server channel, anyone who can post there can send those commands. This is not telemetry. Agrypnos does not run a shared Discord bot. Not claimed shipped until Core+UI land.

## What we will not do

- Telemetry, analytics, or stealth network
- Kernel extensions
- Broad sudo
- Storing your password
- A shared Agrypnos bot
