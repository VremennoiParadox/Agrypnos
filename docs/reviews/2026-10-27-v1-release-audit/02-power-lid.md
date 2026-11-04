# Power, lid, brightness

- verdict: PASS
- blockers: 0
- high: 0
- scope: Power A/B, stable lid-close confirm, brightness floor, lid-open ramp, and keyboard backlight. Read on `final-fixes` at `78738d7` (power paths clean). `swift test` and `xcodebuild` were not run. Battery threshold, thermal toggle, and Low Power Mode are handed to SF. Mac `pmset` / IOKit execution that follows a correct Core command is cited below; a Mac-only gap is a handoff.

## Product promise

Keep awake on with the lid open holds the Mac awake and leaves the panel and keyboard backlight alone. Hygiene waits for a stable closed lid: two `AppleClamshellState` samples at least 0.25s apart. One raw sample applies neither the brightness floor nor `displaysleepnow`.

Power A is the default (`floor`). On that confirmed close, while armed, Agrypnos writes the brightness floor and turns the keyboard backlight off. The floor default is 15%, clamped to 1–40, so 0% becomes 1%. The panel stays on. This path does not call `displaysleepnow`.

Power B (`displaySleep`) on that same confirmed close calls `displaysleepnow` and turns the keyboard backlight off. It does not write the floor, does not turn Keep awake off, and does not call `pmset sleepnow`. How long stays as set.

The two panel commands are mutually exclusive. There is no M2-only branch in `Sources/` or `Apps/Agrypnos/Sources/Power`.

A floor write requires armed, confirmed closed, and Power A, and the Mac adapter also requires the raw lid to still read closed. After disengage, a brightness write is the captured pre-hygiene level. A nil capture skips the write. The floor argument is ignored.

Opening the lid while still armed, after hygiene ran: Power A ramps that capture over 1, 2, or 3 seconds (default 2) and turns the keyboard backlight on. Power B wakes the panel, skips the ramp, and turns the keyboard backlight on. Keep awake and How long stay as they were.

`prd/v1-scope.md` adds no floor or ramp numbers. Its item 4 still says engage requests display sleep. The release bar and this code do not. That sentence is a docs handoff.

The floor and keyboard switches default on. Turning the floor switch off stores `applyBrightnessFloor = false` and the next confirmed close skips the floor write. That is the stored preference, not a second mode.

## Gates checked

| Gate | Result | Evidence |
|---|---|---|
| Hygiene only after stable lid-closed confirm. One raw `AppleClamshellState` sample applies nothing. Unconfirmed close applies neither floor nor `displaysleepnow` | PASS | `LidCloseConfirm.sample` returns nil on the first closed sample (`Sources/AgrypnosCore/Power/LidCloseConfirm.swift:45-52`). Confirm needs `pulseInterval` 0.25s (`:7`, `:49-51`). `WatchEngine.observeLid` returns commands only for that `.closed` edge (`Sources/AgrypnosCore/Session/WatchEngine.swift:256-268`). `lidCloseCommands` with `lidCloseConfirmed: false` appends neither floor nor display sleep (`Sources/AgrypnosCore/Power/PanelPowerMode.swift:53-60`). Arm passes `lidClosed: false`, then one `observeLid` (`Apps/Agrypnos/Sources/WatchRuntime.swift:376-381`). The 0.25s pulse is only while a close is pending (`Apps/Agrypnos/Sources/WatchRuntime+Lid.swift:38-44`, `LidCloseConfirm.swift:81-83`). The raw read is labeled as one sample (`Apps/Agrypnos/Sources/Power/MachineSensors.swift:8-10`). |
| Power A default: confirmed close while armed writes the floor (default 15, range 1–40, never 0) and turns the keyboard backlight off. Panel stays on. No `displaysleepnow` | PASS | Default `PanelPowerMode.floor` (`PanelPowerMode.swift:11-14`). `shouldWriteFloor` is armed and confirmed and `.floor` (`:27-33`). Close commands are floor then keyboard off (`:53-63`). Range `1...40`, default 15 (`Sources/AgrypnosCore/Session/UserPreferences.swift:6-7`, clamp `:105-107`). Mac floor write re-checks that gate and `readLid() == true` (`Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift:56-63`). `displaysleepnow` is a separate case (`:46-51`). |
| Power B: confirmed close while armed calls `displaysleepnow` and turns the keyboard off. No floor write. Keep awake stays on. No `pmset sleepnow` | PASS | `shouldSleepDisplay` (`PanelPowerMode.swift:35-41`). Close commands (`:58-63`) omit `.requestSleep` and `.applyBrightnessFloor`. `lidDidClose` does not clear `engaged` (`WatchEngine.swift:236-243`). Mac `requestDisplaySleep` runs `displaysleepnow` only (`PowerHygieneCoordinator.swift:46-51`). `sleepnow` is the other case (`:42-45`). |
| Never floor and `displaysleepnow` together. No M2-only branch | PASS | The two appends are separate mode checks (`PanelPowerMode.swift:53-60`). A→B while confirmed closed returns display sleep without floor; B→A returns wake then floor (`WatchEngine.swift:143-153`). No `M2`, `hw.model`, or `AppleSilicon` match under `Sources/` or `Apps/Agrypnos/Sources/Power`. |
| Floor write only when armed, confirmed closed, and Power A. Lid open skips it. After disengage, the only brightness write is a captured level | PASS | `shouldWriteFloor` (`PanelPowerMode.swift:27-33`). Engage with the lid flag clear returns `[.engage]` only (`WatchEngine.swift:285-294`). Disengage does not append `.applyBrightnessFloor` (`:346-367`). Mac passes `lidCloseConfirmed: engine.lidCloseConfirmed && readLid() == true` (`WatchRuntime.swift:453`). Restore writes `captured` (`PowerHygieneCoordinator.swift:90-98`). |
| Nil capture skips the brightness write and does not fall back to the floor. Same for keyboard restore | PASS | `displayBrightnessToRestore` returns `captured` and discards `floor` (`Sources/AgrypnosCore/Power/HygieneRestore.swift:16-21`). `keyboardBrightnessToRestore` returns `captured` (`:11-14`). Ramp bails when that returns nil (`PowerHygieneCoordinator.swift:72-75`). Restore writes only `if let captured` (`:95-96`, `:101-103`). |
| Lid open while still armed: Power A ramps the capture over 1/2/3s (default 2) and turns the keyboard on. Power B skips the ramp, wakes the panel, and turns the keyboard on. Keep awake and How long stay | PASS | `lidOpenCommands` (`PanelPowerMode.swift:68-82`). `showsLidOpenRamp` is A only (`:15`). Ramp seconds `1...3`, default 2 (`UserPreferences.swift:12`, `:62`, `:120-122`; `HygieneRestore.swift:5-8`). `lidDidOpen` leaves `engaged` set and does not change duration (`WatchEngine.swift:246-254`). Mac ramp also requires `showsLidOpenRamp` (`PowerHygieneCoordinator.swift:69-81`). |
| Toggle / engage does not blank the panel, call `displaysleepnow`, or turn the keyboard backlight off | PASS | Shipping arm uses `lidClosed: false` (`WatchRuntime.swift:380`). That engage result is `[.engage]` (`WatchEngine.swift:285-294`). The coordinator ignores `.engage` (`PowerHygieneCoordinator.swift:40`). Inbound arm uses the same false flag (`WatchEngine.swift:165-168`). Leftover adopt does too (`Apps/Agrypnos/Sources/WatchRuntime+Kernel.swift:99-100`). |

`userSetEngaged(true, lidClosed: true)`, `adoptLeftoverKernel(lidClosed: true)`, and a direct `lidDidClose` mark confirmed without a new sample (`WatchEngine.swift:286-289`, `:100-103`, `:236-238`). The comment on `markConfirmedClosed` says the caller already confirmed (`LidCloseConfirm.swift:39-42`). No shipping arm passes that shortcut. The one shipping `lidDidClose` runs after disengage, while Keep awake is off, and its commands are discarded (`Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:391-395`).

## Findings

None.

## Handoffs

- SF: battery threshold, thermal toggle, and Low Power Mode were not judged. `SafetyInputs` `Sources/AgrypnosCore/Power/Safety.swift:3-20`. Reasons `.batteryFloor` `:25`, `.thermal` `:26`, `.lowPowerMode` `:29`, included in `turnsWatchOff` `:33-39`. `AutoOffEvaluator.reason` thermal `:63`, battery `:64-68`, Low Power Mode `:70-71`. Slider range and clamp `UserPreferences.swift:4`, `:101-103`. Thermal default `:28`, `:63`.
- MAC: `pmset` and DisplayServices / keyboard IOKit. The coordinator re-checks the Core gates before `displaysleepnow` (`PowerHygieneCoordinator.swift:46-51`), the floor write (`:56-63`), and keyboard off (`:65-68`). `DisplayServicesSetBrightness` is `BrightnessFloorController.set` (`Apps/Agrypnos/Sources/Power/BrightnessFloorController.swift:24-28`, `:59-61`). Keyboard IOKit write is `KeyboardBacklightController.write` (`Apps/Agrypnos/Sources/Power/KeyboardBacklightController.swift:54-58`). `setOff()` (`:11-13`) has no caller.
- MAC: a failed `pmset sleepnow` still drops the captured restore. `finishDisengageHygiene` treats any non-nil `sleepnow` as “do not restore” (`WatchRuntime+Poll.swift:359-367`). `PmsetCommandOutcome.from` stores a non-zero exit as `.failed`, which is non-nil (`Sources/AgrypnosCore/Power/PmsetCommandOutcome.swift:10-12`). `dropSavedHygieneWithoutWrite` then nils the capture and clears the effect flags (`WatchRuntime.swift:486-491`). The panel can stay at the floor and the keyboard can stay off, including after the lid is opened, because sampling stops once the watch is off. Core `shouldRestoreAfterDisengage` (`HygieneRestore.swift:24-29`) is only referenced from tests. Popover and hotkey off on a successful sleep are a different path: they are supposed to leave the panel alone while the Mac sleeps.
- MAC: `prepareForTermination` disengages with `lidClosed: false` when the watch is still armed (`WatchRuntime+Kernel.swift:70-78`). Popover Quit turns Keep awake off first (`Apps/Agrypnos/Sources/MenuBar/PopoverController.swift:508-511`), so the button uses the sampled off path. A terminate that skips that button tells Core the lid is open. Power B can then receive `wakeDisplay`.
- MAC: Power B lid-open wake is `caffeinate -u -t 1` (`PowerHygieneCoordinator.swift:11`). Core’s command is `.wakeDisplay` (`Sources/AgrypnosCore/Session/WatchTypes.swift:11-13`). Whether that pulse wakes the panel, and only the panel, needs this Mac.
- UI: copy was not reviewed. `PanelPowerMode` can represent A vs B (`writesBrightnessFloor`, `sleepsDisplay`, `showsLidOpenRamp` at `PanelPowerMode.swift:13-15`). Ramp chrome is omitted for B in layout (`Sources/AgrypnosCore/Copy/PopoverStackLayout.swift:280-282`).
- Docs: `prd/v1-scope.md:18` still says engage requests display sleep, keyboard backlight off, and the brightness floor.

## Needs a Mac

- Arm with the lid open: panel brightness and keyboard backlight stay as they were.
- Close the lid and wait past one sample: no floor and no `displaysleepnow` until the second sample (~0.25s after the first closed read).
- Power A, confirmed close: built-in panel goes to the floor percent (default 15), keyboard backlight off, panel still on. No `displaysleepnow`.
- Open the lid while still armed, Power A: brightness ramps to the captured level over the selected 1/2/3s, keyboard backlight on, Keep awake and How long unchanged.
- Power B, confirmed close: panel sleeps, keyboard backlight off, Keep awake stays on, agents keep running, no `pmset sleepnow`.
- Open the lid while still armed, Power B: panel wakes, no brightness ramp, keyboard backlight on.
- Switch A→B and B→A with the lid confirmed closed: never floor and `displaysleepnow` in the same action.
- Turn Keep awake off with the lid open after a floor: brightness returns to the capture. A nil capture leaves the panel untouched.
- If `pmset sleepnow` fails with the lid confirmed closed, check whether the floor and keyboard backlight come back. That gap is the Mac handoff above.

## Unproven

- This audit did not run `swift test` or `xcodebuild`. The gate results are from the source and the existing tests, not from a run tonight.
- Prior optical notes (floor and Power A/B, 2026-09-24 and 2026-09-25) were not repeated on this Mac tonight.
- If `CGGetOnlineDisplayList` drops the built-in panel at the confirm sample, `canSetBuiltIn()` is false (`BrightnessFloorController.swift:14-16`, `BrightnessWritePolicy.swift:14-16`) and the floor write is skipped. `lidHygieneApplied` is already set (`WatchEngine.swift:241-243`), so later polls do not retry that write. Keyboard off does not use that display list.
- Arming while the lid is already raw-closed captures `current()` before the floor (`WatchRuntime.swift:377-379`, `LidCloseConfirm.swift:30-32`). A nil read skips the later restore. A real `0` is stored as a capture (`HygieneRestore.swift:18-21`). Whether a closed-lid read returns nil or `0` was not measured tonight.
- `caffeinate -u -t 1` as the Power B panel wake was not run tonight.
