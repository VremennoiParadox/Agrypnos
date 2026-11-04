# Invariant call-site sweep

- verdict: CLEAR
- blockers: 0
- high: 0
- scope: Grepped the repo except `.build`, `.git`, and `docs/reviews` for `sleepnow`, `displaysleepnow`, `disablesleep`, `SleepDisabled`, brightness write APIs, keyboard backlight writes, `AppleClamshellState`, `NWListener`, `bind`/`listen`, webhook, Interactions Endpoint, `SecItem`/Keychain, and logs of token/chat id/channel id. Read every Swift/script hit that can execute. Doc and test mentions are not call sites. Sudoers checked in `Scripts/grant.sh`, `Apps/Agrypnos/Resources/grant.sh`, `SudoersGrant`, and `SECURITY.md`.

## Product promise

User-off (popover, hotkey, or Quit, which calls the same off path) and inbound `/disarm` run `pmset sleepnow` only after stable lid-close confirm. Lid open or unconfirmed clears the wake hold and stays awake. Already off with the lid confirmed closed still clears the hold and runs `sleepnow`.

Timer expiry turns Keep awake off, leaves How long alone, and requests sleep unless the lid is known open. An unavailable or unconfirmed-closed reading still requests sleep on that path only.

Agents idle-after-wait and battery, thermal, and Low Power Mode sleep only when the watch’s lid was already closed and the sensor is still closed. A never-busy arm does not post and does not disarm.

Power B runs `displaysleepnow` only while armed, lid confirmed closed, and mode B. It does not disarm, does not sleep the Mac, and is never paired with a floor write.

Turning Keep awake on does not sleep the display or turn the keyboard backlight off on a single raw clamshell read. The floor is written only while armed, lid confirmed closed, and Power A. A nil brightness capture writes nothing.

## Call sites

| file:line | call | legal? | matrix rule | result |
|---|---|---|---|---|
| `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift:44` | `pmset sleepnow` | yes — timer: sleep unless `readLid() == false`; every other reason: sleep only if `readLid() == true` | 1, 2, 3 | PASS |
| `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift:50` | `pmset displaysleepnow` | yes — armed, confirmed, mode B, and raw lid closed; separate case from floor and from `sleepnow` | 4 | PASS |
| `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift:55` | `caffeinate -u -t 1` | yes — panel wake only; not Mac sleep and not display sleep | 4 | PASS |
| `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift:62` | `setBrightness(floor)` | yes — `applyBrightnessFloor`, `shouldWriteFloor` (armed + confirmed + Power A), and raw lid closed | brightness | PASS |
| `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift:67` | `setKeyboard(0)` | yes — armed, confirmed, preference on, raw lid closed | 5 | PASS |
| `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift:81` | ramp `setBrightness` to captured | yes — `effects.floor`, Power A ramp, nil capture returns nil and skips | brightness | PASS |
| `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift:96` | restore `setBrightness(captured)` | yes — only if a floor was applied and capture is non-nil | brightness | PASS |
| `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift:102` | restore `setKeyboard(captured)` | yes — only if keyboard was turned off and capture is non-nil | brightness | PASS |
| `Apps/Agrypnos/Sources/Power/BrightnessFloorController.swift:59` | `DisplayServicesSetBrightness` | yes — only through `set`, and `set` is reached from the coordinator/ramp gates above | brightness | PASS |
| `Apps/Agrypnos/Sources/Power/KeyboardBacklightController.swift:57` | `IORegistryEntrySetCFProperty` | yes — live callers are the coordinator lines above; `setOff()` at line 11 has no caller | 5 | PASS |
| `Apps/Agrypnos/Sources/Power/SleepDisabledController.swift:23` | `pmset -a disablesleep 0/1` via `sudo -n` | yes — wake hold only; not `sleepnow` | wake hold | PASS |
| `Sources/AgrypnosCore/Power/KernelQuitPolicy.swift:19` | crash helper `pmset -a disablesleep 0` | yes — the clear half of the two-command grant | wake hold | PASS |
| `Apps/Agrypnos/Sources/Power/MachineSensors.swift:20` | read `AppleClamshellState` | yes — one raw read; confirm is `LidCloseConfirm` | lid confirm | PASS |
| `Apps/Agrypnos/Sources/Power/MachineSensors.swift:33` | `pmset -g batt` | yes — read | read | PASS |
| `Apps/Agrypnos/Sources/Power/SleepDisabledController.swift:16` | `pmset -g` | yes — read | read | PASS |
| `Sources/AgrypnosCore/Power/SudoersGrant.swift:5` | two `disablesleep` commands | yes | sudoers | PASS |
| `Scripts/grant.sh:25` | same two commands | yes | sudoers | PASS |
| `Apps/Agrypnos/Resources/grant.sh:25` | same two commands | yes | sudoers | PASS |
| `Sources/AgrypnosCore/Notif/DiscordInboundRequest.swift:105` | `PATCH /api/v10/webhooks/{app}/{interaction}/messages/@original` | yes — deferred slash edit; any other `webhooks` path returns nil | network | PASS |
| `Sources/AgrypnosCore/Notif/DiscordInboundRequest.swift:116` | `interactionsEndpointRegistration()` | yes — returns nil | network | PASS |
| `Sources/AgrypnosCore/Notif/DiscordInboundRequest.swift:43` | `POST /api/v10/channels/{id}/messages` | yes — bot channel message | network | PASS |
| `Apps/Agrypnos/Sources/Notif/DiscordInboundGatewayClient.swift:134` | outbound Gateway WebSocket | yes — client; no bind | network | PASS |
| `Apps/Agrypnos/Sources/Questions/LocalHookSocket.swift:66` | `bind` + `listen` on `AF_UNIX` | yes — filesystem socket mode `0600`; not a TCP port | network | PASS |
| `Apps/Agrypnos/Sources/Questions/OpenCodeBridgeSocket.swift:86` | `bind` + `listen` on `AF_UNIX` | yes — same; peer uid must match | network | PASS |
| `Apps/Agrypnos/Sources/Notif/NotifSecretsStore.swift:94` | `notif-secrets.json` mode `0600` | yes — Application Support; payload has token, chat id, bot token, channel id; no webhook field | secrets | PASS |
| `Apps/Agrypnos/Sources/WatchDiagnostics.swift:16` | `Logger` debug | yes — watch state only; no token, chat id, or channel id | secrets | PASS |

No `NWListener`, no `SecItem` / `kSecClass`, no M2/model branch, no production `discordWebhookURL` field.

## Gates checked

| gate | result | evidence |
|---|---|---|
| User-off / inbound `/disarm` sleeps only if stable confirm and the sensor is still closed | PASS | `WatchEngine.swift:16` `lidCloseConfirmed && rawClosed`; `WatchRuntime+Poll.swift:379` and `:387`; coordinator `:43` non-timer arm |
| Lid open or unconfirmed user-off clears hold and does not sleep | PASS | `WatchRuntime+Poll.swift:316` strips `requestSleep`; `WatchEngine.swift:365` adds it only when `wasLidClosed` |
| Already off + confirmed closed still `sleepnow` once | PASS | `WatchRuntime+Poll.swift:388` `confirmed ? [.requestSleep] : []` |
| Quit uses that same off path | PASS | `PopoverController.swift:510` `setEngaged(false)` → `disarmWatch()` |
| Hotkey uses that same off path | PASS | `AppDelegate.swift:19` `runtime.toggle()` |
| Telegram and Discord `/disarm` use that same off path | PASS | `WatchRuntime+TelegramInbound.swift:158`; `WatchRuntime+DiscordInbound.swift:225` |
| Arm does not treat one raw edge as closed | PASS | `WatchRuntime.swift:380` passes `lidClosed: false`, then one `observeLid`; `LidCloseConfirm.swift:49` needs `pulseInterval` |
| Timer sleeps unless the lid is known open; nil or raw-closed still sleeps | PASS | `WatchRuntime.swift:454` sets `timerExpired` only for `.disengage(.timerExpired)`; coordinator `:43` `readLid() != false`; `WatchRuntime+Poll.swift:326` strips only `rawClosed == false` |
| Agents / battery / thermal / LPM are not the user-off gate | PASS | `WatchEngine.swift:365` sleeps those reasons when `wasLidClosed`; poll `:326` keeps sleep when the sensor is still closed |
| Never-busy arm: no post, no disarm | PASS | `AgentSettleTracker.swift:42` stays `.quiet` without `sawBusy`; `NotifIdlePostPolicy.swift:13` posts only `agentsSettled && sawBusy` |
| Power B display sleep does not disarm and does not run `sleepnow` | PASS | `PanelPowerMode.swift:35` and `:44`; `lidCloseCommands` never appends `.requestSleep` |
| Floor and `displaysleepnow` are mutually exclusive | PASS | `PanelPowerMode.swift:53` floor only for mode A; `:58` display sleep only for mode B |
| Floor write after disengage is captured restore only | PASS | `HygieneRestore.swift:18` returns `captured` and ignores floor; coordinator `:95` skips nil |
| No Keychain, no incoming webhook, no Interactions Endpoint, no TCP listen | PASS | rows above |
| Sudoers is exactly two `pmset disablesleep` commands | PASS | `SECURITY.md:10`; `Scripts/grant.sh:25` |

## Findings

None.

## Handoffs

None. `sleepnow` is not a thin wrapper: `PowerHygieneCoordinator.apply` re-reads the lid before the process runs. The engine’s reason choice matches the matrix, so nothing moves to another slice.

## Needs a Mac

This audit did not run the app, `swift test`, or `xcodebuild`. Whether `pmset sleepnow`, `displaysleepnow`, DisplayServices, and the keyboard registry write do what the gates ask is still a live-Mac fact. The source gates for those calls are classified above.

## Unproven

None. Every executable hit in the sweep was read and classified.
