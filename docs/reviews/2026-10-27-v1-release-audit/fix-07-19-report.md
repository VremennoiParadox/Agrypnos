# Fixes 7–19

Nothing is committed. Fixes 1–6 were left in the tree. `finishDisengageHygiene` was not edited. The Telegram wake-miss poller change was not copied onto Discord.

## Fix 7 — V1-Q-02

Send answers uses the saved Telegram user id and the saved Discord user id from `notif-secrets.json`. A destination is complete only when that id is present. Sender `99` does not edit or submit. The saved id still can. Chat id and channel id checks stay. The Notif card has two dotted fields, Telegram user id and Discord user id, empty until filled. No webhook field.

Red: `swift test --filter testSameChatClickSelectsAndWakeMissOrOtherChatDoesNot` failed to compile (`userID` was not a destination field). After the field existed but was unused, the same filter failed: a blank id still forwarded, and sender `99` edited and submitted.

`swift test --filter testOptInMigrationAndAuthorizedUsersStaySeparateFromPreferences` then failed because a stored `telegramQuestionUserId` decoded as nil.

Green: `swift test --filter QuestionRelayCoordinatorTests` — 19 tests passed, including `testSameChatClickSelectsAndWakeMissOrOtherChatDoesNot`.

`swift test --filter 'testOptInMigrationAndAuthorizedUsersStaySeparateFromPreferences|testSecretsPayloadRoundTripsAndOmitsEmptyFields|testTelegramFieldsHaveVisibleTokenAndChatIdCaptions|testNotifSectionStacksCardsAndMayScroll|testInboundChromeIsTogglePlusHelpNotARemotePanel|testDiscordCardHoldsTokenChannelAndInboundSwitch|testDelayedNativeExpiryIsClearedBeforeTenMinuteWatchDecision|OpenCodePluginRuntimeTests|ClaudeHookRuntimeTests|NotifPopoverChromeTests|TelegramInboundPopoverChromeTests|DiscordInboundPopoverChromeTests|OpenCodeQuestionSettingsTests'` — passed.

## Fix 8 — V1-TG-03

Red: `swift test --filter testTimerOutboundUsesExpiryMessageAndAgentsKeepsIdleMessage` failed. Closed-lid Telegram text was still `Agrypnos: your Keep awake timer ended.` The idle body also lacked `Asking the Mac to sleep.`

Green: `swift test --filter 'testTimerOutboundUsesExpiryMessageAndAgentsKeepsIdleMessage|testUserOffPostsDiscordSleepSentenceOnlyWhenLidIsConfirmedClosed'` — both passed. Open lid has no clause. `.user`, `.batteryFloor`, `.thermal`, and `.lowPowerMode` still produce no Telegram request.

## Fix 9 — V1-TG-02

Red: `swift test --filter 'testIdleBodyAndHelpAreIdleAfterWaitNotJobFinished|testDiscordCardIsTheBotWithoutAWebhookField'` failed. The Telegram sentence still said Agrypnos asks the Mac to sleep.

Green: `swift test --filter 'testIdleBodyAndHelpAreIdleAfterWaitNotJobFinished|testDiscordCardIsTheBotWithoutAWebhookField|testEnableAndTelegramHelpFitTallerSlots|testNotifSectionStacksCardsAndMayScroll|testNotifCopyStaysIdleAfterWaitAndNamesYourBot'` — passed. Help is 6 lines so the split fits.

## Fix 10 — V1-UI-01

Red: `swift test --filter testDurationHintsArePlainAndFitTheDurationCard` failed. Infinity, Agents, and the off state did not include the lid sentence.

Green: `swift test --filter 'testDurationHintsArePlainAndFitTheDurationCard|testTimedHintTreatsCustomMinutesLikeOtherTimers|PopoverStackLayoutTests'` — passed. An armed timer still shows only the timer sentence. The How long card is taller so the lid sentence fits.

## Fix 11 — V1-DOC-03

Red: `swift test --filter testQuestionPolicySleepsOnlyWhenTheLidIsConfirmedClosed` failed. The policy did not say Keep awake turns off, and did not say the sleep is only when the lid is confirmed closed.

Green: `swift test --filter QuestionRelayLayoutTests` — passed. `QuestionSetupChrome.policy` was edited once.

## Fix 12 — V1-DOC-02

Red: `swift test --filter testQuestionHelpDoesNotClaimDesktopApps` failed. Help still contained `desktop apps`.

Green: `swift test --filter 'testQuestionHelpDoesNotClaimDesktopApps|QuestionRelayLayoutTests'` — passed. The desktop-apps clause is gone. No desktop OpenCode installer.

## Fix 13 — V1-TG-04

Red: `swift test --filter testColdStartKeepsStoredWakeMissAndUnsetStaysLeftover` failed to compile. `startingLaunch` did not exist.

Green: `swift test --filter 'testColdStartKeepsStoredWakeMissAndUnsetStaysLeftover|testLeftoverDrainDoesNotApplyOrReply|testNewPollSessionKeepsOffsetAndSkipsQueuedCommands|TelegramInboundWakeMissTests'` — passed. A stored wake-miss stays wake-miss and `/arm` is missed-while-asleep. An unset cursor stays leftover and does not reply. `startingSession` still clears wake-miss for setup, quit, and inbound off. Discord was not changed.

## Fix 14 — V1-DC-01

Red: `swift test --filter testRejectsNonGatewayHosts` failed. `resumeURL(from: "wss://gateway-us-east1-b.discord.gg")` was nil.

Green: `swift test --filter 'testRejectsNonGatewayHosts|DiscordGatewayURLFactoryTests|DiscordGatewaySessionTests'` — passed. `wss://evil.example` and `wss://gateway.discord.gg.evil.com` stay nil.

## Fix 15 — V1-DC-02

Red: `swift test --filter testWrongChannelSlashRepliesWithoutArmingOrDisarming` failed to compile. `slashIgnoreReply` did not exist.

Green: `swift test --filter 'testWrongChannelSlashRepliesWithoutArmingOrDisarming|testWrongChannelIdIsIgnored|testMatchingChannelRoutesArmDisarmStatusHelp'` — passed. A slash ignore now says `That command was not applied.` The deferred reply is still sent. A matching channel still applies.

## Fix 16 — V1-Q-03

Red: `swift test --filter testUnrenderableLaterDiscordPanelStaysLocalBeforeOfferingControls` failed. Request count was 0, not 1. The process then trapped on an empty array index. The assertion was changed to unwrap the first request before the green run.

Green: `swift test --filter testUnrenderableLaterDiscordPanelStaysLocalBeforeOfferingControls` — passed. Both destinations configured. No question controls. One Discord sentence: `This question did not fit, so it stayed on your Mac.` If that notice cannot be built, Telegram is not dropped for the Discord overflow.

## Fix 17 — V1-UI-03

Red: `swift test --filter testPickerCopyUsesCoreChromeAndStaysHonest` failed. The Sleep panel caption did not contain the floor-path reason.

A first green grew the shared caption slot to 6 lines. `testPowerAShowsPickerCaptionRampAndHugsWithoutScroll` then failed: content height 750, clip 720, Power A needed scroll. The slot was put back to 4 lines. The Sleep panel sentence was tightened so the floor-path reason fits in those 4 lines. Dim panel still does not say display asleep or screen off. The ramp stays hidden under Sleep panel. The second help view stays hidden.

Green: `swift test --filter 'PanelPowerPopoverChromeTests|testChromeIsMutuallyExclusiveAndPlain'` — selected tests passed.

## Fix 18 — V1-UI-04

No new Core test. The report says an AppKit label is not visible to Core tests. The existing copy tests already lock `Discord inbound` and `Telegram inbound`.

`swift test --filter 'testNotifPlacesTheSwitchOnTheTelegramCard|testInboundDefaultsOffAndStaysSeparateFromOutboundPOST|testInboundDefaultsOffAndStaysSeparateFromWatchEndPOST'` — passed. Defaults stay off.

The MenuBar folder is excluded from the Swift package test target, so `swift test` does not compile `PopoverController+Notif.swift`. `xcodebuild -project Apps/Agrypnos/Agrypnos.xcodeproj -scheme Agrypnos -destination platform=macOS -configuration Debug build CODE_SIGNING_ALLOWED=NO` — **BUILD SUCCEEDED**, including that file.

Call sites after the edit: Discord inbound uses `switchRow` with `AgrypnosCopy.notifDiscordInbound`. Telegram inbound uses `switchRow` with `AgrypnosCopy.notifTelegramInbound`, and the switch accessibility label is `Telegram inbound`.

## Fix 19 — V1-DOC-04

No test. `prd/v1-scope.md` item 6 now includes OpenCode, local process and session files only, not CPU. Item 4 was left as Fix 3 wrote it.
