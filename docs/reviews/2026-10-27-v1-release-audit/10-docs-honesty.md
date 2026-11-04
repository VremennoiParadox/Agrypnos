# Docs honesty

- verdict: FAIL
- blockers: 1
- high: 1
- scope: README.md, SECURITY.md, prd/v1-scope.md, in-app Bot setup (`BotGuideCopy`) and Question notifications copy (`QuestionSetupChrome`). AGENTS.md "Bad:" examples and tests were not flagged.

## Product promise

Keep awake on does not sleep the display. Confirmed lid close uses Power A (brightness floor, panel stays on) or Power B (panel sleep only; the Mac stays awake). Confirmed-closed `/disarm` and confirmed-closed popover/hotkey off may `pmset sleepnow` without a new sudoers grant. Sudoers is two `pmset disablesleep` commands. Notif is opt-in traffic to the user's own Telegram and Discord bot. No telemetry, no incoming webhook, no Interactions Endpoint URL, no listen port.

## Gates checked

- SECURITY allows opt-in Telegram and Discord bot traffic and denies telemetry. It does not say "no network calls." `SECURITY.md:26-36`, `SECURITY.md:109`. Secrets file is Application Support, not Keychain. `NotifSecretsStore.swift:14-16`.
- Confirmed-closed inbound `/disarm` and confirmed-closed popover/hotkey off may `pmset sleepnow`, and that is not a sudoers grant. `SECURITY.md:10`, `SECURITY.md:18`, `SECURITY.md:32`, `SECURITY.md:36`. `README.md:58-62`, `README.md:130`, `README.md:148`. `BotGuideCopy.swift:243-245`. Grant text is the two `disablesleep` commands. `SudoersGrant.swift:4-5`, `Scripts/grant.sh:25`. `sleepnow` runs as the user. `PowerHygieneCoordinator.swift:42-44`, `ProcessRunner.swift:5-14`. Sleep only when the lid close is confirmed. `TelegramInboundPolish.swift:51-55`, `WatchEngine.swift:156-179`, `WatchRuntime+Poll.swift:374-389`.
- Discord setup is bot token + channel id. Webhook URL is unused. No Interactions Endpoint URL and no listen port. `README.md:186-199`, `BotGuideCopy.swift:201-223`. `AgrypnosCopy.swift:206-211`. `DiscordInboundGateway.swift:3-7`. `NotifFieldChrome.swift:75`.
- README does not claim Cursor question forwarding, and it says Codex does not answer. `README.md:261-269`, `README.md:374-386`. Same in setup copy. `BotGuideCopy.swift:95-103`, `QuestionSetupChrome.swift:4-10`.
- README Power A keeps the panel on. Power B sleeps the display only and does not sleep the Mac or stop agents. `README.md:37-38`, `README.md:88-92`. Code: floor only for Power A, display sleep only for armed + confirmed close + Power B. `PanelPowerMode.swift:27-40`, `PanelPowerMode.swift:113-118`.
- No watt numbers, no real secret examples. `caffeinate` in `README.md:33` is the macOS tool. `prd/v1-scope.md:11` names Sleepless. Not graded: not a dangerous action, a broken setup step, or a missing sleep gate.
- Launch at login does not turn Keep awake on. Reboot clears the sleep block. `README.md:123`, `SECURITY.md:16`. Launch clears a leftover hold instead of arming. `WatchRuntime.swift:132`, `WatchRuntime+Kernel.swift:81-93`.
- Terminal sessions are off unless opted in. Settle minimum is 1 minute 30 seconds. `README.md:109-114`, `README.md:396`. `UserPreferences.swift:9-10`, `UserPreferences.swift:45-46`, `UserPreferences.swift:74`.
- `prd/v1-scope.md:20` still says Cursor, Claude Code, and Codex only. README and the agent roots include OpenCode. Not graded: it does not teach a dangerous action.

## Findings

### V1-DOC-01

- severity: BLOCKER
- confidence: high
- breaks: a reader of the V1 scope treats "turn Keep awake on" as real display sleep, and as display sleep plus the brightness floor together. That is screen-off on the toggle, which this product must not do. Power A never sleeps the display. Power B sleeps the panel only after a confirmed lid close, and never together with the floor.
- evidence: `prd/v1-scope.md:5` "The display must actually sleep." `prd/v1-scope.md:18` "Engage requests real display sleep, keyboard backlight off, brightness floor. Lid-close while engaged re-applies those." `WatchEngine.swift:285-294` engage with the lid open emits `.engage` only and resets lid confirm; it does not emit display sleep. `PanelPowerMode.swift:35-40` display sleep requires armed and confirmed lid close and Power B. `PanelPowerMode.swift:43-60` floor and display sleep are separate; lid-close commands never emit Mac sleep. `PowerHygieneCoordinator.swift:40-50` `.engage` does not run `pmset`; `displaysleepnow` runs only for `.requestDisplaySleep`.
- trigger: read the V1 scope acceptance item 4, or the opening user goal, and arm Keep awake with the lid open.
- expected: arming with the lid open changes nothing on screen. Confirmed lid close dims to the floor (Power A) or sleeps the panel only (Power B).
- actual: the scope says engage requests real display sleep and the brightness floor, and that lid close re-applies those.
- fix_files: `prd/v1-scope.md`
- fix: delete the two sentences. Do not replace them with another display-sleep-on-engage line.
- test_first: none in Swift. `PanelPowerMode.shouldSleepDisplay` already locks the gate. Do not add a test that engage requests display sleep.
- do_not: do not implement acceptance item 4. Do not call `displaysleepnow` on the Keep awake toggle or while the lid is open. Do not write the floor and `displaysleepnow` on the same lid close.

### V1-DOC-02

- severity: HIGH
- confidence: high
- breaks: Question notifications tells the user the feature works in desktop apps. OpenCode setup only registers the terminal plugin. A desktop OpenCode session is not what that button configures.
- evidence: `QuestionSetupChrome.swift:10` "This works in the CLI and the desktop apps." `QuestionSetupChrome.swift:46` "One-time setup for OpenCode 1.18.32 terminals." `OpenCodePluginInstaller.swift:16` the registration file is `tui.json`. `README.md:289-290` says this build supports OpenCode 1.18.32 interactive terminals and that desktop clients have not been verified. The in-app sentence is the one that overclaims.
- trigger: read Question notifications help and use the OpenCode desktop app after Enable OpenCode forwarding.
- expected: the help matches the installer: OpenCode forwarding is the terminal plugin. Restart the terminal app.
- actual: the help says desktop apps work.
- fix_files: `Sources/AgrypnosCore/Copy/QuestionSetupChrome.swift`
- fix: delete "This works in the CLI and the desktop apps."
- test_first: assert `QuestionSetupChrome.help` does not contain "desktop apps".
- do_not: do not add a desktop OpenCode install path to make the sentence true.

### V1-DOC-03

- severity: MEDIUM
- confidence: high
- breaks: the question card is where a user reads the 10-minute expiry. It says Agrypnos asks the Mac to sleep, with no lid gate. Open lid must not sleep. README already states the confirmed-lid path.
- evidence: `QuestionSetupChrome.swift:11` "If none comes, and Keep awake is already on, Agrypnos asks the Mac to sleep." `README.md:325-327` unanswered end uses the confirmed-lid sleep path. `WatchEngine.swift:363-367` `requestSleep` is added only for timer expiry or when the stored lid close is confirmed. `WatchRuntime+Poll.swift:279-305` an unanswered question sleeps only if that request is still present and a fresh lid sample is confirmed closed.
- trigger: Keep awake is on, the lid is open, and a forwarded question goes unanswered for 10 minutes.
- expected: the card says Keep awake turns off, and the Mac is asked to sleep only if the lid is confirmed closed.
- actual: the card says Agrypnos asks the Mac to sleep, with no lid condition.
- fix_files: `Sources/AgrypnosCore/Copy/QuestionSetupChrome.swift`
- fix: delete "Agrypnos asks the Mac to sleep." The README sentence is the one that matches the code.
- test_first: assert `QuestionSetupChrome.policy` does not claim sleep without "confirmed".
- do_not: do not make unanswered expiry call `sleepnow` while the lid is open so the sentence becomes true.

## Handoffs

None. On the checked gates, README and SECURITY match the code: sudoers, lid-gated `sleepnow`, Discord bot token + channel id, no webhook / listen port / Interactions Endpoint URL, Cursor and Codex question limits, Power A/B, launch-at-login, reboot, terminal-busy default off, settle minimum 90 seconds. No WE, PW, SF, AG, Q, TG, DC, UI, or MAC handoff. V1-DOC-02 and V1-DOC-03 are copy, not behavior.

## Needs a Mac

- Arm with the lid open and confirm the panel does not sleep. The scope doc currently says the opposite.
- Unanswered question, lid open: Keep awake off, Mac stays awake. Lid confirmed closed: `sleepnow`.
- This audit did not run `pmset` or the popover.

## Unproven

- README `138`, `139`, `184`, `259`, `264`, `274`, `366`, `385`, SECURITY `18`, `28`, `32`, `36`, and `BotGuideCopy.swift:91` still say Discord, I2, Claude forwarding, or the Codex ChatGPT check are not done. AGENTS.md records those as user-confirmed on 2026-10-11. Not graded: they underclaim proof and do not teach a different action. This audit did not repeat the Mac checks.
- OpenCode desktop was not launched. The HIGH finding is the installer writing `tui.json` only.
