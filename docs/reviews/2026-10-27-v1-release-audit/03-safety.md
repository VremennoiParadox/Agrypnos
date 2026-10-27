# Safety

- verdict: PASS
- blockers: 0
- high: 0
- scope: battery threshold, thermal toggle, Low Power Mode forced-watch, sudoers grant, and whether a safety auto-off clears SleepDisabled. Lid brightness, the user-off sleep matrix, and pmset process spawning are handoffs.

## Product promise

While Keep awake is on, a discharging battery at or under the slider (5–100%, default 15%) turns it off. Thermal auto-off is a toggle, default on: `ProcessInfo.thermalState` `.serious` or `.critical` turns Keep awake off; off skips only that path. Low Power Mode plus discharging turns a leftover watch off, and leaves a watch the user armed this session alone. Reboot clears `SleepDisabled`. Launch at login does not arm. The sudoers grant is exactly two `pmset disablesleep` commands. `sleepnow` is not part of that grant. A safety end has to clear the hold so the Mac can sleep.

## Gates checked (gate | PASS/FAIL | path:line)

| Gate | Result | Evidence |
|---|---|---|
| Battery slider 5–100%, default 15%, fires only while discharging | PASS | `Sources/AgrypnosCore/Session/UserPreferences.swift:4`, `:54`, `:76`, `:101-102`; slider `Apps/Agrypnos/Sources/MenuBar/PopoverController+Cards.swift:315-331`; refresh `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift:208-212`; setter `Apps/Agrypnos/Sources/WatchRuntime.swift:159-160`; evaluator `Sources/AgrypnosCore/Power/Safety.swift:64-68`; parser `Sources/AgrypnosCore/Power/PowerStatusParser.swift:12`, `:17-18`; sample `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:32-36` |
| Thermal toggle, default on. On: `.serious` or `.critical` ends the watch. Off: skip thermal only. Battery and LPM stay. No °C, no SMC | PASS | default `Sources/AgrypnosCore/Session/UserPreferences.swift:63`, missing key `:207`; toggle `Apps/Agrypnos/Sources/WatchRuntime.swift:201-203`; UI `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift:206`; skip `Sources/AgrypnosCore/Power/Safety.swift:63` then battery `:64-68` and LPM `:70-71`; sensor `Apps/Agrypnos/Sources/Power/MachineSensors.swift:37-40` |
| LPM and discharging auto-off unless this session was armed on purpose. Forced watch is not painted as ended | PASS | `Sources/AgrypnosCore/Power/Safety.swift:70-71`; user arm `Sources/AgrypnosCore/Session/WatchEngine.swift:52-56`; leftover adopt `:96-107`; init disarmed `:33-39`; status copy `Sources/AgrypnosCore/Notif/TelegramStatus.swift:129-134` |
| Reboot clears SleepDisabled. Launch at login does not arm | PASS | login item only registers `Apps/Agrypnos/Sources/Launch/LaunchAtLoginController.swift:4-14`; launch calls `start` `Apps/Agrypnos/Sources/AppDelegate.swift:14-16`; `start` reconciles a held flag and does not call `setEngaged` `Apps/Agrypnos/Sources/WatchRuntime.swift:123-132`; new engine is disarmed `Sources/AgrypnosCore/Session/WatchEngine.swift:33-39`. Crash helper clears with the existing `disablesleep 0` line `Sources/AgrypnosCore/Power/KernelQuitPolicy.swift:12-19` |
| Sudoers grant is exactly two `pmset disablesleep` commands. `visudo` before install. `sleepnow` is not a new grant. No secrets in the script | PASS | clause `Sources/AgrypnosCore/Power/SudoersGrant.swift:4-5`; same line `Scripts/grant.sh:25` and `Apps/Agrypnos/Resources/grant.sh:25`; `visudo -cf` on the snippet before install `Scripts/grant.sh:37-43`; `SECURITY.md:10` and `:15` match that clause and the pre-install check. `sleepnow` is `/usr/bin/pmset` with no sudo `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift:42-44`. Sudo is only `disablesleep` `Apps/Agrypnos/Sources/Power/SleepDisabledController.swift:20-25` via `Apps/Agrypnos/Sources/Support/ProcessRunner.swift:9-14` |
| Safety auto-off ends the watch and clears SleepDisabled | PASS | armed tick returns `disengage` `Sources/AgrypnosCore/Session/WatchEngine.swift:203-213`; command list includes `.disengage` `:346` and `.requestSleep` when the lid was confirmed closed `:363-366`; poll treats that disengage as a kernel release `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:207-221`, `:251-258`; release is `disablesleep 0` plus readback `Apps/Agrypnos/Sources/WatchRuntime+Kernel.swift:36-40`. A failed readback rolls the watch back on `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:262-266` instead of leaving it logically off while the hold remains. An armed watch is never on the idle probe that skips safety `Sources/AgrypnosCore/Session/WatchTickProbe.swift:28-31` |

## Findings

None.

## Handoffs

- PW: lid brightness, floor write, and Power A/B panel hygiene. Not reviewed here.
- WE: popover, hotkey, and inbound user-off sleep matrix. Safety uses the same confirmed-lid `requestSleep` line inside `disengage` (`WatchEngine.swift:363-366`). That matrix was not re-audited.
- MAC: `pmset` process spawning and readback on this Mac. The grant script does not skip `visudo`. No spawn handoff for a missing check.
- Docs: `SECURITY.md:18` still says I2 is not Mac-proven. The grant sentence there matches the two-command rule and says `sleepnow` is not a new grant. That stale proof label is not a wider sudoers line.

## Needs a Mac

- Plug and unplug, and confirm the slider fires only while `pmset -g batt` says Battery Power and discharging.
- Thermal toggle on, then `.serious` or `.critical`, and confirm Keep awake ends. Toggle off and confirm that state does not end it, while battery and leftover LPM still do.
- Arm on purpose with Low Power Mode on and discharging: Keep awake stays on. Adopt a leftover hold in that state: Keep awake ends.
- Confirmed lid closed plus battery, thermal, or leftover LPM: SleepDisabled reads back clear, then `pmset sleepnow`. Lid open: hold clears, no `sleepnow`.
- Reboot, then launch-at-login: SleepDisabled stays clear and the watch stays off.

## Unproven

- This pass did not run `swift test` or `xcodebuild`. The gate results are from the source and the existing tests, not from a run tonight.
- Live `ProcessInfo.thermalState` and a live battery sample were not taken on this Mac.
- Reboot clearing `SleepDisabled` is the kernel flag going away. The app does not set it in `applicationDidFinishLaunching`. That reboot was not done tonight.
- A Discord watch-end send can hold SleepDisabled until `NotifIdlePoster` returns (`WatchRuntime+Poll.swift:230-248`, bound `NotifIdlePoster.swift:7-9`). The task then calls `disarmKernel`. Cancel paths that were read start another clear or a new arm. That race was not executed.
