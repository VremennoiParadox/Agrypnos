# Fix-pass health

SCORE: 7/10

WHY: The pass stays in the functions that already owned each bug. Question timeout is three lines in the watch tick, quit sleeps through the same sleep command, and the answering-user ids are two fields on the existing secrets file. WatchRuntime is 581 lines, still under the 600-line cap. It is a 7 because the nil-lid sleep rule grew a second classifier inside the pmset switch, the new Telegram sleep latches are not what their tests observe, and the new user-id rows widened every secret field.

FINDINGS:

- `Apps/Agrypnos/Sources/Power/PowerHygieneCoordinator.swift`: `.requestSleep` walks the command list for battery, thermal, Low Power Mode, and agents, beside the `timerExpired` flag the caller already computed the same way. Two classifiers decide whether a missing lid still sleeps. Smaller shape: one bool next to that existing flag in `WatchRuntime.apply`, and the guard stays a single read of the lid.
- `Tests/AgrypnosMacTests/TelegramInboundWakeMissRuntimeTests.swift`: the promotion test sets the poller latch by hand, so removing the arm from wake still passes. The sleep-hold test only checks a wake-miss cursor, and a poll that started anyway would write that same cursor. Smaller shape: call `noteMacDidWake`, then finish on the generation that wake leaves current, and assert the poller did not start a loop.
- `Sources/AgrypnosCore/Copy/CopyWrap.swift`: the shared secret label width went from 80 to 152 because the new rows use “Telegram user id” as the visible caption. Token and chat already use a short caption and keep the long name for accessibility, so every secret value got narrower. Smaller shape: caption “User id”, and leave the width alone.
