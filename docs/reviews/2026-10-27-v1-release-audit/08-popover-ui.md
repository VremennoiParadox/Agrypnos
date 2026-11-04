# Popover and menu bar

- verdict: HOLD
- blockers: 0
- high: 2
- scope: Popover sections, captions, hotkey recorder, menu-bar glyph, and user-facing strings in `Apps/Agrypnos/Sources/MenuBar/` and `Sources/AgrypnosCore/Copy/`. Question-relay behavior and the sleep/power state machines are handoffs. This pass did not run the app.

## Product promise

The popover is the only settings surface: Watch, Power, Agents, Notif, General, opening on Watch. Section changes ease the height over 0.25s unless Reduce Motion is on, show one section, and hug that section. The menu bar is a fixed eye, colored by mode, with facts only in the tooltip and accessibility title. Keep awake is `⌥⌘A` until remapped, and a failed bind is visible. Power A and Power B are labeled and captioned; B hides brightness return. Agents is the four tools, never empty; terminal sessions start off; idle wait starts at 1m 30s. Notif secrets are dotted, revealed by the eye, cleared by deleting the secrets file, with no webhook field. Captions say what the control does, including that turning Keep awake off sleeps the Mac only when the lid is already confirmed closed.

## Gates checked

| Gate | Result | Evidence |
|---|---|---|
| Switcher Watch · Power · Agents · Notif · General, default Watch. No settings window, no Licence/About. `LSUIElement`. Bot setup window has no settings | PASS | `Sources/AgrypnosCore/Copy/PopoverSection.swift:30-49`; open forces Watch `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift:227-229`; segmented titles `PopoverController+Canvas.swift:55-64`; `LSUIElement` `Apps/Agrypnos/Resources/Info.plist:25-26`; accessory policy `AppDelegate.swift:15`. Bot guide is a titled window of text, tabs, and link buttons `BotGuideWindow.swift:7-8`, `:37-41`, `:116-118`. No preference controls |
| Height ease 0.25s ease-in-out. Reduce Motion skips it. Outgoing cards hidden before the ease. Height follows the active section | PASS in code | Plan `PopoverSectionResize.swift:17-18`, `:63-73`, `:75`. AppKit uses that duration and hides cards in a 0-duration group first `PopoverController+Sections.swift:12-16`, `:42-64`. Nil slots set `isHidden` `PopoverForm.swift:25-30`. Same-height changes do not animate. Pixel proof is Needs a Mac |
| Menu bar is a fixed eye. No visible title or countdown. Off gray, infinity blue, timed gold, Agents purple. Facts may sit in tooltip and accessibility | PASS in code | Empty title, square length, image only `StatusItemChrome.swift:31-43` applied `StatusItemController.swift:97-113`. Colors `:79-82`. Countdown argument is discarded `StatusItemChrome.swift:35`. Countdown text is the How long card `AgrypnosCopy.swift:112-118`, `PopoverController.swift:301-311`. Shared canvas `PopoverChrome.swift:72-75`. Off is `eye.slash` in gray, still an eye. Optical proof is Needs a Mac |
| Hotkey default Option-Command-A, remappable, conflict-safe. Bind failure is visible | PASS | Default key code 0 with option and command `HotkeyChord.swift:22-23`, button starts on that display `HotkeyRecorderControl.swift:16`. Unregistered chords are not saved `HotkeyBindPolicy.swift:20-23`. Failure hint `AgrypnosCopy.swift:80-87` shown on General `PopoverController.swift:214-224`. Launch failure also posts that hint `AppDelegate.swift:27-30` |
| Power A/B labels plus a visible caption. A does not say display asleep or screen off. B does not say the Mac sleeps, agents stop, or Keep awake ends. No watt number | PASS for the caption | Labels and captions `PanelPowerMode.swift:95`, `:113-119`. Caption is on the card `PopoverController+Cards.swift:213-226` and refreshed `PopoverController.swift:201-205`. Ramp card is omitted for B `PopoverStackLayout.swift:280-282` |
| When B is selected, say why brightness return is hidden | FAIL | V1-UI-03 |
| Agents: four tools, cannot save empty. I3 control starts off. Settle does not offer 15s or 30s | PASS | Four names `AgentKind.swift:1-13`. Last tool refuses to turn off `AgentIncludeChrome.swift:5-10`, UI snaps back on `PopoverController.swift:483-486`. Terminal switch is created without an on state `PopoverController+Cards.swift:388-397`; preference default is false `UserPreferences.swift:74`, `:46`. Slider range is 90...600 `UserPreferences.swift:9-10`; min label is `1m 30s` via `AgentSettleGraceChrome` `UserPreferences.swift:263-276` |
| Notif fields dotted with reveal. Clear deletes the secrets file. No webhook paste field | PASS | `NSSecureTextField` plus eye `PopoverForm.swift:240-245`, `:386`. Clear calls `removeItem` `NotifSecretsStore.swift:59-61` from `PopoverController+Notif.swift:303-306`. Discord card is token and channel id `PopoverController+Notif.swift:57-82`. Webhook text in MenuBar is a comment `PopoverForm.swift:375` |
| Captions describe the control. User-off states the lid-closed sleep truth. Thermal copy does not say thermal still applies when the toggle is off | FAIL on user-off | V1-UI-01. Thermal-off hints drop the word `AgrypnosCopy.swift:40-51`, and the popover uses those `PopoverController.swift:314-320`. Thermal card help describes the toggle `AgrypnosCopy.swift:28-29` |
| Banned claims: still thinking, job finished, agent stopped, notify your phone, disarm always sleeps, webhook receives commands, track every AI, safe temp, time-to-empty, Power A turns the screen off | PASS for those phrases | Settle help denies still thinking `AgrypnosCopy.swift:17-18` (the allowed sentence). A caption says it lowers brightness instead of shutting the screen off `PanelPowerMode.swift:116`. No other popover or Copy string uses the banned claims. Bot guide says an old webhook URL is unused `BotGuideCopy.swift:222-223` |
| Question-notification sleep sentence matches the lid gate | FAIL | V1-UI-02 |

## Findings

### V1-UI-01

- severity: HIGH
- confidence: high
- breaks: User-off copy tells the lid-closed sleep truth
- evidence: How long for infinity is "Stays on until you turn it off (battery / thermal still apply)." `Sources/AgrypnosCore/Copy/AgrypnosCopy.swift:37-38`, and with thermal off `:40-44`. Agents mode says the wait ends the watch `:32-33`, `:47-51`. The timer hint is only about timer expiry `:34-35`. `durationHint` is what the card shows `:90-104`, `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift:314-320`. The Keep awake row is a switch plus the armed lid caption `PopoverController+Canvas.swift:80-100`; that caption is hygiene, not turning the switch off `AgrypnosCopy.swift:62-77`. Menu-bar tooltips `:232-252` also omit it. The lid sentence exists for bot `/disarm` only `Sources/AgrypnosCore/Copy/BotGuideCopy.swift:243-245`. The popover and hotkey path does sleep on a confirmed close `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:374-389`
- trigger: Lid already confirmed closed. Turn Keep awake off in the popover or with the hotkey
- expected: The control says that a confirmed-closed off sends the Mac to sleep, and an open or unconfirmed lid only turns Keep awake off
- actual: Infinity and Agents hints describe staying on or ending the watch. They never say the Mac will sleep. A closed-lid off can sleep the machine with no sentence on that control
- fix_files: `Sources/AgrypnosCore/Copy/AgrypnosCopy.swift`
- fix: Add one sentence on the Keep awake path the popover already shows: turning it off with the lid confirmed closed sends the Mac to sleep; with the lid open or unconfirmed it turns Keep awake off and does not sleep the Mac. Keep the timer-expiry hint as the timer sentence
- test_first: Extend `Tests/AgrypnosCoreTests/AgrypnosCopyTests.swift` so infinity, Agents, and the off state include that lid sentence, and so none of them say disarm always sleeps
- do_not: Do not change `applyUserOff` or the lid gate. Do not say the Mac already slept. Do not add a second sleep path

### V1-UI-02

- severity: HIGH
- confidence: high
- breaks: Missing lid-sleep honesty on a popover sleep caption
- evidence: The question card prints `QuestionSetupChrome.policy` `Sources/AgrypnosCore/Copy/QuestionSetupChrome.swift:11` via `Apps/Agrypnos/Sources/MenuBar/PopoverController+Questions.swift:150-151`. That sentence says that if no answer comes and Keep awake is on, Agrypnos asks the Mac to sleep. It has no lid clause. The Mac path sleeps only when the disengage lid was confirmed closed and a new sample is still confirmed `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift:279-305`
- trigger: Question notifications open, Keep awake on, lid open. A question goes unanswered for 10 minutes
- expected: The caption says the Mac is asked to sleep only when the lid is confirmed closed
- actual: The caption states the sleep with no lid condition. Lid open does not `sleepnow`
- fix_files: `Sources/AgrypnosCore/Copy/QuestionSetupChrome.swift`
- fix: Add the confirmed-closed condition to that one sentence. Leave the 10-minute wait and the busy-agent delay as they are
- test_first: Assert `QuestionSetupChrome.policy` says the sleep happens when the lid is confirmed closed, and that it does not say the Mac always sleeps
- do_not: Do not change the timeout or `finishQuestionUnanswered`. That behavior is handoff Q

### V1-UI-03

- severity: MEDIUM
- confidence: high
- breaks: Ramp chrome hidden on B with help saying why
- evidence: B omits the ramp card `Sources/AgrypnosCore/Copy/PopoverStackLayout.swift:280-282`. The help view is created and then `isHidden = true` `Apps/Agrypnos/Sources/MenuBar/PopoverController+Cards.swift:228-241`, and refresh keeps it hidden `PopoverController.swift:203-204`. `PanelPowerChrome.help(.displaySleep)` copies the B caption `Sources/AgrypnosCore/Power/PanelPowerMode.swift:122-128`. Neither string says brightness return is hidden because the ramp only applies when restoring from the floor path. The card height is caption-only `PopoverStackLayout.swift:241-245`
- trigger: Power, choose Sleep panel
- expected: Brightness return is gone, and a visible sentence says it is gone because the ramp only applies when restoring from the floor path
- actual: Brightness return is gone. The visible caption explains Sleep panel. It does not say why the return control disappeared
- fix_files: `Sources/AgrypnosCore/Power/PanelPowerMode.swift`, `Sources/AgrypnosCore/Copy/PopoverStackLayout.swift`, `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift`, `Apps/Agrypnos/Sources/MenuBar/PopoverController+Cards.swift`
- fix: Put that one reason in the B help string and stop forcing the help hidden while Sleep panel is selected. Grow only the Power card by that help block
- test_first: Assert B help contains the floor-path reason, and that the Sleep panel stack height includes that help. Assert A still does not say display asleep or screen off
- do_not: Do not rewrite the A/B captions into new marketing. Do not show the ramp slider under B. Do not add a watt claim

### V1-UI-04

- severity: MEDIUM
- confidence: high
- breaks: Captions say what the control does. The inbound on/off is a required Notif control
- evidence: Discord and Telegram inbound use `switchControl`, which draws a switch and no title `Apps/Agrypnos/Sources/MenuBar/PopoverController+Notif.swift:83-95` and `:142-153`. `switchRow` is what places a title `PopoverForm.swift:63-89`. "Discord inbound" is only the accessibility label `PopoverController+Notif.swift:94`. The Telegram switch's accessibility label is "Telegram" `PopoverController+Notif.swift:152`, the card title, not "Telegram inbound". The row has `switchRowHeight` reserved `PopoverStackLayout.swift:216-221`. The strings exist `AgrypnosCopy.swift:200-205` and are not added as labels. Card help mentions commands; it is above the fields, not on the switch row
- trigger: Open Notif. Look at the switch under the Discord channel field or the Telegram chat field
- expected: The row reads Discord inbound or Telegram inbound
- actual: The row is a switch with no visible name. Telegram VoiceOver says Telegram
- fix_files: `Apps/Agrypnos/Sources/MenuBar/PopoverController+Notif.swift`
- fix: Use `switchRow` with `AgrypnosCopy.notifDiscordInbound` and `AgrypnosCopy.notifTelegramInbound`. Set the Telegram accessibility label to Telegram inbound
- test_first: No new Core test will catch a missing AppKit label. Add the two titles in the card builder; the existing copy tests already lock the title strings
- do_not: Do not add a second inbound card or a webhook field. Do not change the default, which is off `UserPreferences.swift:66-67`

## Handoffs

- Q: Question timeout, busy delay, and whether forwarding works in desktop apps. `QuestionSetupChrome.help` says CLI and desktop apps `QuestionSetupChrome.swift:10`. This audit only checked the sleep sentence in `policy`. `BotGuideCopy.watchAndExpiry` `BotGuideCopy.swift:132-135` says manual off wins and mentions unknown agent activity. Those claims were not traced
- WE: `applyUserOff` already sleeps on confirmed close `WatchRuntime+Poll.swift:374-389`. V1-UI-01 is the missing caption, not a second sleep stack
- PW: Ramp hiding and floor-vs-`displaysleepnow` behavior. V1-UI-03 is the missing sentence and the hidden help view

## Needs a Mac

- Section switch Watch, Power, Agents, Notif, General: height eases, Reduce Motion cuts, no ghost cards, short sections have no empty tail
- Menu-bar eye stays one width. Off gray, infinity blue, timed gold, Agents purple. No title and no countdown on the icon
- Sleep panel: brightness return is gone, and after V1-UI-03 the reason is on screen. Dim panel does not say the screen is off
- Failed hotkey: the General hint and the launch notice are readable
- Secret fields are dots until the eye is pressed. Clear secrets removes the file. Inbound switches show their names after V1-UI-04
- OpenCode "Disable" and "Remove integration" share one row `PopoverController+OpenCodePlugin.swift:12-15`. Width was not measured

## Unproven

- No `swift test` and no `xcodebuild`. No popover was opened
- `NSSwitch` starts off when the code never sets it. Terminal sessions rely on that plus the false default. It was not viewed
- Ghost pixels during the 0.25s ease were not seen. The code hides the outgoing section before the ease
- "This works in the CLI and the desktop apps" was not checked against a live Claude or OpenCode app
