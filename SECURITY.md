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

When Notif is enabled, Agrypnos may POST **once** to **your** Discord incoming webhook and/or **your** Telegram bot after Agents mode has seen local busy this arm and then stayed quiet through the idle wait. Default **off**. Empty fields skip that channel. Secrets (webhook URL, bot token, chat id) live in Keychain, not plaintext prefs. This is not telemetry. Agrypnos does not run a shared bot.

## What we will not do

- Telemetry, analytics, or stealth network
- Kernel extensions
- Broad sudo
- Storing your password
- A shared Agrypnos bot
