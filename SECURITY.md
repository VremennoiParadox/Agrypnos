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
- A crash or force quit clears it too. At launch the app starts a small `/bin/sh` helper that waits on a pipe from the app. When the app process ends for any reason, the pipe closes and the helper runs `sudo -n /usr/bin/pmset -a disablesleep 0` (the existing grant, nothing new), then exits.
- Confirmed lid-closed inbound `/disarm` and popover/hotkey user-off (I2 — unlocked for Core, not Mac-proven) may call `pmset sleepnow`. Same user-level path as safety auto-off. Not a new sudoers grant. Lid-open or unconfirmed must not sleep the Mac.

Remove with `Scripts/ungrant.sh` or `sudo rm /etc/sudoers.d/agrypnos-disablesleep`.

## What we read

Agent heuristics look at process names and mtimes of known session paths under your home directory. Transcripts are plaintext; Agrypnos does not upload them and does not parse message bodies in V1 — only modification times.

## Opt-in outbound (Notif)

When Notif outbound is enabled, Agrypnos may POST **once** to **your** Discord incoming webhook and/or **your** Telegram bot after Agents mode has seen local busy this arm and then stayed quiet through the idle wait. Default **off**. Empty fields skip that channel. Secrets (webhook URL, Telegram bot token, chat id) live in `~/Library/Application Support/Agrypnos/notif-secrets.json` (mode 0600), not Keychain and not plaintext prefs. Discord inbound bot token and channel id live in that same file when set — they are not an outbound channel. Values saved in an older Keychain build are not imported; paste them again. This is not telemetry. Agrypnos does not run a shared bot.

## Telegram inbound (your bot)

When Telegram inbound is on, Agrypnos may poll `getUpdates`, register `/arm` `/disarm` `/status` `/help` with `setMyCommands`, and send command replies on **your** BotFather bot using the same token and chat id as outbound. Default **off**. Empty token or chat id: no inbound. Commands are accepted only from the saved chat id. Agrypnos does not reply while the Mac is asleep (no relay). On wake, queued commands are drained without applying (facts-only **missed while asleep**). Confirmed lid-closed `/disarm` may call `pmset sleepnow` (same user-level path as safety auto-off; not a new sudoers grant). Same lid gate as popover/hotkey user-off (I2 — unlocked for Core, not Mac-proven). Lid-open or unconfirmed `/disarm` must not sleep the Mac. If that id is a group, anyone who can message that group can send those commands. Discord webhook stays outbound-only. This is not telemetry. Agrypnos does not run a shared bot.

## Discord inbound (your bot)

When Discord inbound is on, Agrypnos may receive updates on **your** Discord bot on this Mac (Gateway or equivalent — Core picks the smallest reliable path) and send command replies using a **bot token** and **channel id** stored with the other Notif secrets. Default **off**, separate from outbound Notif and from Telegram inbound. Empty token or empty channel id: no inbound. Commands are accepted only from the saved channel. The incoming webhook URL is never inbound — do not mix them. Do **not** set Discord’s Interactions Endpoint URL. Do **not** open a listen port. Same `/arm` `/disarm` `/status` `/help` WatchEngine path as Telegram (Discord-native slash may map to those commands). Agrypnos does not reply while the Mac is asleep (no relay). On wake, queued commands are drained without applying (facts-only **missed while asleep**) if anything was queued — do not scrape channel history on wake to invent missed commands. Confirmed lid-closed Discord `/disarm` may call `pmset sleepnow` (same user-level path as Telegram `/disarm` and as popover/hotkey user-off; not a new sudoers grant). Lid-open or unconfirmed `/disarm` must not sleep the Mac. If that channel is a server channel, anyone who can post there can send those commands. This is not telemetry. Agrypnos does not run a shared Discord bot. Gateway/UI landed on main; not Mac-proven until soft Mac optical.

## Opt-in OpenCode question forwarding (test build)

Forward agent questions defaults off. OpenCode 1.18.32 remains enabled in
this test build. Claude Code question forwarding is the hook path below.
One-button setup requires OpenCode selected in Agents and
an enabled, complete inbound bot destination with an explicit answering-user ID.
It installs an owned global terminal plugin and registers it in `tui.json`,
preserving other entries and leaving `tui.jsonc` untouched. Modified or foreign
files and symlinks are refused. Disable leaves the plugin inactive; removal
only deletes unchanged receipt-owned files and its registration.

The plugin uses the public terminal SDK to observe native questions and submit
complete answers to their original requests. IPC is a bounded authenticated
Unix socket in a private 0700 directory, with a 0600 socket and a same-UID peer
check. An independent random token and lifecycle generation live in
`~/Library/Application Support/Agrypnos/opencode-bridge/bridge.json` (0600);
no bot credentials go to OpenCode. Tokens are revoked on disable, clear-secrets,
sleep, quit and source replacement. No local token protects against a compromised
process running as the same user. No question polling heartbeat is added.

The explicit manual fallback connects to the saved HTTP `127.0.0.1` server
and directory. It checks `/global/health`, reads `/global/event` and `/question`,
and may submit a complete answer to the original `/question/:id/reply`.
Redirects are rejected. The modes are exclusive. Neither mode scans ports,
starts a replacement OpenCode server, or creates replacement conversations.

Structured question text/options go to the user's existing Telegram or
Discord bot through its existing inbound connection. Callback checks include
the saved answering-user ID, destination, message, live request handle and
lifecycle generation. The Discord webhook remains outbound-only. No extra
bot consumer, listening port, shared bot or sudoers grant is added. A lost
native reply is unconfirmed and is never retried blindly.

Answering IDs and the local-server connection/password are saved alongside
bot credentials in `notif-secrets.json` (0600), not UserDefaults or Keychain.
Question content stays in memory and on the opted-in messaging service; no
local question history or content logs. Free text and approvals stay local.
Clearing secrets deletes the saved file. Sleep, shutdown and setup changes
invalidate old phone controls. Forwarding never arms the watch or overrides
manual/safety off. The existing confirmed-lid sleep path may be used after
an unanswered ten-minute watch end; a bot notification is best effort.

## Opt-in Claude Code question forwarding (test build)

Enable Claude Code forwarding merges a command hook into
`~/.claude/settings.json`. It never replaces the file and never deletes
other hook events. The command is this app with `--claude-question-hook`.
The helper talks to the running menu-bar app on a Unix socket under
`~/Library/Application Support/Agrypnos/claude-question-hook/` (directory
0700, socket 0600, same-UID peer). It does not spawn a second Claude, open a
listen port, or set a Discord Interactions Endpoint URL. If Agrypnos is not
running, the helper returns empty JSON within two seconds and does not select
an answer. No new sudoers grant. The Discord webhook stays outbound-only.

## What we will not do

- Telemetry, analytics, or stealth network
- Kernel extensions
- Broad sudo
- Storing your Mac login password (the optional OpenCode server password is separate)
- A shared Agrypnos bot
