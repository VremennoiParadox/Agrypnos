# Ponytail audit
- verdict: INFO
## Findings
shrink: 25 stored card slots, the `slot()` switch, and the same list again in `init`. `[PopoverCard: PopoverSlot]`. [Sources/AgrypnosCore/Copy/PopoverStackLayout.swift]
shrink: `StatusItemChrome` `Length`, `ImagePosition`, empty `title`, and ignored `remainingSeconds`. Accessibility title only; the item is already `squareLength`. [Sources/AgrypnosCore/Session/StatusItemChrome.swift]
delete: second `grant.sh`, byte-identical to `Scripts/grant.sh`. Bundle `Scripts/grant.sh`. [Apps/Agrypnos/Resources/grant.sh]
native: `IsolatedFlag` NSLock box. `OSAllocatedUnfairLock` at the Discord heartbeat (Mac only; Core stays Linux-safe). [Sources/AgrypnosCore/Session/IsolatedFlag.swift]
native: How long uses `trackingMode: .selectAny` plus `segmentSelection` / `exclusiveSelectedIndex`. `NSSegmentedControl` `.selectOne` and `selectedSegment` (`-1` while minutes are custom). [Sources/AgrypnosCore/Power/DurationPickerChrome.swift]
yagni: `reply(intent:engaged:duration:)` ignores `engaged` and `duration` on both bots. The status reply overload. [Sources/AgrypnosCore/Notif/TelegramInbound.swift]
shrink: `writeClaudeSettings` and `writeCodexHooks` are the same temp-and-replace. One helper. Leave the secrets writer (mode 0600) alone. [Apps/Agrypnos/Sources/Questions/WatchRuntime+ClaudeHook.swift]
yagni: `NotifEnableChrome`, `TelegramInboundChrome`, `DiscordInboundChrome`, `BatteryFloorChrome`, `BrightnessFloorPercentChrome`, and `nextRevealed`. `UserPreferences` defaults or ranges, and `!revealed`. [Sources/AgrypnosCore/Notif/NotifFieldChrome.swift]
delete: `keyboardBrightnessToRestore`, only tests call it. `restoreKeyboard` already skips a nil capture. [Sources/AgrypnosCore/Power/HygieneRestore.swift]
yagni: `sessionFreshness` 15...120 with no control, and `claudeCodexCPUBusyThreshold` always passed as 5. Constants 45 and 5. [Sources/AgrypnosCore/Session/UserPreferences.swift]
net: -340 lines, -0 deps possible.
## Do not cut
keep: Lid-close stable confirm before hygiene. One raw clamshell edge is not enough. [Sources/AgrypnosCore/Power/LidCloseConfirm.swift]
keep: Nil brightness capture skips the write. Do not fall back to the floor. [Sources/AgrypnosCore/Power/HygieneRestore.swift]
keep: Power A floor and Power B `displaysleepnow` stay mutually exclusive. [Sources/AgrypnosCore/Power/PanelPowerMode.swift]
keep: User-off and inbound disarm sleep only when the lid is confirmed closed. Timer expiry still sleeps when the lid is not known open. [Sources/AgrypnosCore/Session/WatchEngine.swift]
keep: Empty agent selection is rejected and the previous set is kept. [Sources/AgrypnosCore/Agent/AgentIncludeChrome.swift]
keep: Count terminal sessions as busy stays default off. [Sources/AgrypnosCore/Session/UserPreferences.swift]
keep: OpenCode stays out of CPU-busy. [Sources/AgrypnosCore/Agent/AgentKindClassifier.swift]
keep: Wake-miss drain acks commands without applying them. [Sources/AgrypnosCore/Notif/TelegramInboundPolish.swift]
keep: Commands only from the saved chat id or channel id. [Sources/AgrypnosCore/Notif/TelegramInbound.swift]
keep: Secrets stay in `notif-secrets.json` mode 0600, not Keychain. [Apps/Agrypnos/Sources/Notif/NotifSecretsStore.swift]
keep: sudoers grant stays exactly two `pmset disablesleep` commands. [Sources/AgrypnosCore/Power/SudoersGrant.swift]
## Unproven
Left `docs/superpowers`, gitignored `.worktrees`, and a full `NSStackView` replacement of the popover uncounted; Linux tests own the y math, and a stack view was not shown to be shorter.
