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

Remove with `Scripts/ungrant.sh`, or by hand: first `sudo /usr/bin/pmset -a disablesleep 0`, then `sudo rm /etc/sudoers.d/agrypnos-disablesleep`. Clear the setting first: without the rule, nothing can clear a hold a running watch left on until reboot.

## Asking the Mac to sleep

Agrypnos may run `pmset sleepnow` as you. It is not covered by the sudoers grant and needs no new one. It runs only after the wake hold is cleared, and only in these cases:

- You turn Keep awake off (popover, hotkey, or `/disarm` from your bot) and the lid is **confirmed closed**. `/disarm` also sleeps the Mac when Keep awake was already off.
- You quit Agrypnos with the lid confirmed closed.
- Low battery, thermal pressure, Low Power Mode, an unanswered question, or the end of the wait after agent signals stop turns Keep awake off while the lid is confirmed closed.
- A timer ends. The timer sleeps unless the lid is known to be open, so an unavailable lid reading still requests sleep.

Lid open or unconfirmed: Agrypnos clears the hold and does not sleep the Mac. A single raw lid-sensor edge never counts as closed.

## What we read

Agent heuristics look at process names and modification times of known session paths under your home directory. Transcripts are plaintext. Agrypnos does not upload them and does not read message bodies, only modification times.

## Opt-in messages and commands (Notif)

Everything in this section is off by default and uses **your own** bot. Agrypnos does not run a shared bot, and none of this is telemetry.

Secrets live in `~/Library/Application Support/Agrypnos/notif-secrets.json` (mode `0600`). They are not in the Keychain and not in plaintext preferences. The file holds the Telegram bot token, chat id, and user id, and the Discord bot token, channel id, and user id. Values saved by an older Keychain build are not imported, so paste them again. **Clear secrets** deletes the file.

### Watch-end messages

With **Watch-end POST** on and the matching token and id saved, Agrypnos sends one message to the saved chat or channel when:

- a Keep awake timer ends;
- in Agents mode, Agrypnos saw agents working since Keep awake turned on and the wait after agent signals stop ends;
- (Discord only) this change will run `pmset sleepnow`: user-off, `/disarm`, battery, thermal, Low Power Mode, or an already-off `/disarm` with the lid confirmed closed.

If the timer or the wait is also asking the Mac to sleep, that same message adds "Asking the Mac to sleep." With the lid open or unconfirmed, the timer and the wait still message and add no sleep sentence. Power B panel sleep sends nothing. Messages say Agrypnos is asking the Mac to sleep. They do not claim the Mac slept.

- **Telegram:** `sendMessage` on your bot, to the saved chat id.
- **Discord:** `POST /api/v10/channels/{channel-id}/messages` with your bot token, to the saved channel. There is no incoming webhook.

Empty fields skip that bot.

### Telegram commands

With **Telegram inbound** on, Agrypnos polls `getUpdates` on your bot, registers `/arm`, `/disarm`, `/status`, and `/help` with `setMyCommands`, and replies on the same bot with the same token and chat id. Empty token or chat id: no inbound. Commands count only from the saved chat id. If that id is a group, anyone who can message the group can send commands.

### Discord commands

With **Discord inbound** on, Agrypnos connects from your Mac to Discord's Gateway with your bot token, registers the same four application commands, and replies in the saved channel. Empty token or channel id: no inbound. Commands count only from the saved channel. If that is a server channel, anyone who can post there can send commands.

Agrypnos does not set Discord's Interactions Endpoint URL and does not open a listen port.

### While the Mac sleeps

Agrypnos does not reply and nothing relays commands while the Mac is asleep. On wake, commands that were queued are skipped without running, and the bot replies "Missed while asleep." Agrypnos does not read channel history on wake to look for missed commands.

## Question forwarding (BETA)

**Forward agent questions** is off by default. For OpenCode and Claude Code it needs one complete bot: token, chat or channel id, your user id, and that bot's inbound switch on. Only the saved user id can use **Send answers**. Codex alerts need only a token and a chat or channel id.

Question text and options go to your Telegram or Discord bot over the connection you already set up. They stay in memory and on that messaging service. Agrypnos keeps no question history or content logs, and never writes question text to `notif-secrets.json`. Free text, permission prompts, and plan approvals stay on the Mac. Sleep, shutdown, setup changes, and **Clear secrets** invalidate old phone controls. A reply that was sent but not confirmed is never retried blindly.

Forwarding never turns Keep awake on and never overrides turning it off yourself or a safety limit. If a forwarded question stays unanswered for ten minutes, Keep awake turns off once your selected agents look idle, and the usual lid rules decide whether the Mac sleeps. The bot note about that is best effort.

None of the three setups adds a sudoers grant, a listen port, a shared bot, or a Discord Interactions Endpoint URL.

### OpenCode

One-button setup needs OpenCode selected in **Agents** and a complete bot as above. It installs an Agrypnos-owned global terminal plugin and registers it in `tui.json`. Other entries stay, and `tui.jsonc` is untouched. Setup refuses symlinks and files that are modified or not Agrypnos's. **Disable** leaves the plugin installed but inactive. **Remove integration** deletes only unchanged files Agrypnos installed, plus its registration.

The plugin uses OpenCode's terminal plugin SDK to watch for native questions and to send complete answers back to the original request. It talks to Agrypnos over a Unix socket in a private `0700` directory. The socket is `0600` and Agrypnos checks that the peer runs as the same user. A random token and lifecycle generation live in `~/Library/Application Support/Agrypnos/opencode-bridge/bridge.json` (`0600`). No bot credentials go to OpenCode. Tokens are revoked on disable, **Clear secrets**, sleep, quit, and plugin replacement. A token cannot protect against a compromised process running as you.

### Claude Code

Enabling it merges a `PreToolUse` command hook for `AskUserQuestion` into `~/.claude/settings.json`. It never replaces the file or removes other hooks. The hook command is this app with `--claude-question-hook`. That helper talks to the running menu-bar app over a Unix socket under `~/Library/Application Support/Agrypnos/claude-question-hook/` (directory `0700`, socket `0600`, same-user peer). It does not start a second Claude. If Agrypnos isn't running, the helper returns empty JSON within two seconds and does not pick an answer.

### Codex

Enabling it merges a command hook into `~/.codex/hooks.json` for questions and approvals. It never replaces the file or removes other hooks (`UserPromptSubmit` and `Stop` stay). The hook command is this app with `--codex-alert-hook`. The helper talks to the running menu-bar app over a Unix socket under `~/Library/Application Support/Agrypnos/codex-alert-hook/` (directory `0700`, socket `0600`, same-user peer). It prints nothing and exits 0, and it does not answer the question. The bot message carries the question text unless Codex marks it secret. If Agrypnos isn't running, the helper still exits 0 with empty output. Watch-end POST and user ids aren't needed.

## What we will not do

- Telemetry, analytics, or stealth network
- Kernel extensions
- Broad sudo
- Storing your Mac login password
- A shared Agrypnos bot
