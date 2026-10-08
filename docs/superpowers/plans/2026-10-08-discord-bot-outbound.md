# Discord Bot Outbound Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete the Discord incoming webhook and send Discord outbound through the same bot token and channel id the user already pastes for commands, including one message when Agrypnos asks the Mac to sleep.

**Architecture:** Core picks one plain sentence from the disengage reason and whether this disengage will actually run `pmset sleepnow`. The Mac posts that sentence with the bot’s existing channel-message request (`POST /api/v10/channels/{id}/messages`) after the lid recheck and before `sleepnow`, bounded to 3 seconds. Telegram stays on its current timer and idle-after-wait messages. The Discord interaction follow-up (`PATCH /api/v10/webhooks/{applicationId}/{token}/messages/@original`) stays; that is how slash replies are edited, not the user’s incoming webhook.

**Tech Stack:** Swift, AgrypnosCore (Linux `swift test`), AppKit popover on Mac only.

## Global Constraints

- The human ordered this on 2026-10-08. `AGENTS.md` still parks “Discord-unify” (I11). Task 1 unparks **only** this slice. Leave parked: watt marketing, Wi-Fi/BT kill, settings window, Licence/About, donate, sudoers for sleepnow, M2-only branches, Notification Center as Notif. Enriched-status B stays scrapped.
- No file over 600 lines. New logic goes in `Sources/AgrypnosCore/Notif/DiscordBotOutbound.swift`. Do not grow `NotifIdlePostTests.swift` (527 lines); put new Core tests in `Tests/AgrypnosCoreTests/DiscordBotOutboundTests.swift`.
- One Discord setup: bot token + channel id in `notif-secrets.json` mode 0600. Not Keychain. Dotted + reveal stays. Empty token or empty channel id: no Discord outbound and no Discord inbound.
- Two switches stay. **Watch-end POST** (default off) gates outbound. **Discord inbound** (default off) gates commands. Inbound off does not block outbound. Outbound off does not block commands.
- One Discord message per disengage. Do not send the old sentence and a second sleep sentence.
- Message only when Watch-end POST is on and token + channel id are set. Lid-open user-off sends nothing. Power B `displaysleepnow` sends nothing (panel sleep, Mac stays awake).
- Copy must not say the Mac is asleep, the agent stopped, or the job finished. Say “Asking the Mac to sleep.” The POST is an attempt before `sleepnow`; the body does not claim the Mac slept.
- Do not set Discord’s Interactions Endpoint URL. Do not open a listen port. Do not scrape channel history.
- Do not add a Telegram sleep message in this slice. Telegram still messages only for timer expiry and Agents idle-after-wait.
- An old `discordWebhookURL` in `notif-secrets.json` is ignored. Do not turn that URL into a bot token. The user pastes token + channel id.
- Codex waiting alerts and question notices that used the webhook move to the same bot channel. Question buttons already use the bot; leave that path.
- Not Mac-proven until the user checks it on a Mac. Do not write “Mac-proven” for this slice.
- Plain captions. No watt claims. No shared Agrypnos bot.

---

### Task 1: Unpark this slice in AGENTS.md

**Files:**
- Modify: `AGENTS.md` (Notif Discord bullets, V2 park, Boss row)

**Interfaces:**
- Consumes: nothing
- Produces: the bar text later tasks must match

- [ ] **Step 1: Replace the parked Discord-unify line**

In the V2 park section, replace:

```markdown
**I11 stays parked.** Do not unlock Discord-unify, watt marketing, Wi-Fi/BT kill, settings window, Licence/About, donate, sudoers for sleepnow, or M2-only branches. Soft Mac Discord optical stays the existing Discord inbound check — still not Mac-proven. Enriched-status B stays **scrapped**.
```

with:

```markdown
**I11 stays parked** except the Discord bot outbound slice the human ordered on 2026-10-08. That slice deletes the Discord incoming webhook and sends Discord outbound through the user’s bot token + channel id, including one message when Agrypnos asks the Mac to sleep (`pmset sleepnow`). Still parked: watt marketing, Wi-Fi/BT kill, settings window, Licence/About, donate, sudoers for sleepnow, M2-only branches. Soft Mac Discord optical stays open — not Mac-proven. Enriched-status B stays **scrapped**.
```

- [ ] **Step 2: Replace the Discord webhook outbound rules**

In the Notif section, replace every rule that says the Discord incoming webhook is the outbound channel with these facts (keep Telegram, slash commands, wake-miss, and lid-gated `/disarm` as they are):

- Discord outbound is a bot channel message to the saved channel id. The incoming webhook URL is gone from the popover, secrets, and setup guide.
- Watch-end POST on + token + channel id: message on timer expiry, on Agents idle-after-wait, and when this disengage will run `pmset sleepnow` (user-off, inbound `/disarm`, battery, thermal, Low Power Mode, already-off confirmed-closed disarm). One message. If timer or idle-after-wait is also sending the Mac to sleep, add “Asking the Mac to sleep.” to that same sentence.
- Lid open or unconfirmed: timer and idle-after-wait still message, with no sleep sentence. User-off, battery, thermal, and Low Power Mode do not message unless this disengage will `sleepnow`.
- Power B panel sleep does not message.
- Do not claim the Mac slept.
- Codex waiting alerts use the same bot channel. “Save a Telegram chat or Discord webhook first.” becomes “Save a Telegram chat or Discord bot token and channel id first.”

In the Boss row, replace “I11 parked” with “I11 parked except Discord bot outbound (human 2026-10-08; not Mac-proven)”.

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "$(cat <<'EOF'
Unpark Discord outbound through the user's own bot.

EOF
)"
```

---

### Task 2: One Discord sentence

**Files:**
- Create: `Sources/AgrypnosCore/Notif/DiscordBotOutbound.swift`
- Test: `Tests/AgrypnosCoreTests/DiscordBotOutboundTests.swift`

**Interfaces:**
- Consumes: `DisengageReason`, `AgrypnosCopy.notifIdleBody`
- Produces: `DiscordBotOutbound.body(reason:willSleep:) -> String?`

`reason == nil` means the watch was already off and confirmed-closed disarm is only asking the Mac to sleep.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AgrypnosCore

final class DiscordBotOutboundTests: XCTestCase {
    func testTimerAndIdleKeepTheirSentence() {
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .timerExpired, willSleep: false),
            "Agrypnos: your watch timer ended."
        )
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .agentsSettled, willSleep: false),
            AgrypnosCopy.notifIdleBody
        )
    }

    func testSleepAppendsOneClauseToTheWatchEndSentence() {
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .timerExpired, willSleep: true),
            "Agrypnos: your watch timer ended. Asking the Mac to sleep."
        )
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .agentsSettled, willSleep: true),
            AgrypnosCopy.notifIdleBody + " Asking the Mac to sleep."
        )
    }

    func testSleepOnlyReasonsMessageOnlyWhenTheMacWillSleep() {
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .user, willSleep: true),
            "Agrypnos: Keep the watch is off. Asking the Mac to sleep."
        )
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .batteryFloor, willSleep: true),
            "Agrypnos: battery auto-off. Asking the Mac to sleep."
        )
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .thermal, willSleep: true),
            "Agrypnos: thermal pressure turned the watch off. Asking the Mac to sleep."
        )
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: .lowPowerMode, willSleep: true),
            "Agrypnos: Low Power Mode turned the watch off. Asking the Mac to sleep."
        )
        XCTAssertEqual(
            DiscordBotOutbound.body(reason: nil, willSleep: true),
            "Agrypnos: asking the Mac to sleep."
        )
        for reason in [DisengageReason.user, .batteryFloor, .thermal, .lowPowerMode] {
            XCTAssertNil(DiscordBotOutbound.body(reason: reason, willSleep: false))
        }
        XCTAssertNil(DiscordBotOutbound.body(reason: nil, willSleep: false))
    }

    func testQuestionAndWakeHoldFailureDoNotGetASecondSentence() {
        XCTAssertNil(DiscordBotOutbound.body(reason: .questionUnanswered, willSleep: true))
        XCTAssertNil(DiscordBotOutbound.body(reason: .questionUnanswered, willSleep: false))
        XCTAssertNil(DiscordBotOutbound.body(reason: .wakeHoldFailed, willSleep: true))
        XCTAssertNil(DiscordBotOutbound.body(reason: .wakeHoldFailed, willSleep: false))
    }

    func testBodiesDoNotClaimTheMacSlept() {
        let reasons: [DisengageReason?] = [
            .timerExpired, .agentsSettled, .user, .batteryFloor, .thermal, .lowPowerMode, nil
        ]
        for reason in reasons {
            for willSleep in [false, true] {
                let body = DiscordBotOutbound.body(reason: reason, willSleep: willSleep) ?? ""
                XCTAssertFalse(body.lowercased().contains("mac is asleep"))
                XCTAssertFalse(body.lowercased().contains("agent stopped"))
                XCTAssertFalse(body.lowercased().contains("job finished"))
            }
        }
    }
}
```

- [ ] **Step 2: Run the test and see it fail**

Run: `swift test --filter DiscordBotOutboundTests`
Expected: FAIL. `DiscordBotOutbound` is not defined.

- [ ] **Step 3: Write the function**

```swift
import Foundation

public enum DiscordBotOutbound: Sendable {
    /// One Discord channel message for this disengage. Nil sends nothing.
    /// `reason == nil` is already-off confirmed-closed disarm.
    public static func body(reason: DisengageReason?, willSleep: Bool) -> String? {
        switch reason {
        case .timerExpired:
            return willSleep
                ? "Agrypnos: your watch timer ended. Asking the Mac to sleep."
                : "Agrypnos: your watch timer ended."
        case .agentsSettled:
            return willSleep
                ? AgrypnosCopy.notifIdleBody + " Asking the Mac to sleep."
                : AgrypnosCopy.notifIdleBody
        case .user:
            return willSleep ? "Agrypnos: Keep the watch is off. Asking the Mac to sleep." : nil
        case .batteryFloor:
            return willSleep ? "Agrypnos: battery auto-off. Asking the Mac to sleep." : nil
        case .thermal:
            return willSleep ? "Agrypnos: thermal pressure turned the watch off. Asking the Mac to sleep." : nil
        case .lowPowerMode:
            return willSleep ? "Agrypnos: Low Power Mode turned the watch off. Asking the Mac to sleep." : nil
        case nil:
            return willSleep ? "Agrypnos: asking the Mac to sleep." : nil
        case .questionUnanswered, .wakeHoldFailed:
            return nil
        }
    }
}
```

- [ ] **Step 4: Run the test and see it pass**

Run: `swift test --filter DiscordBotOutboundTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Notif/DiscordBotOutbound.swift Tests/AgrypnosCoreTests/DiscordBotOutboundTests.swift
git commit -m "$(cat <<'EOF'
Pick one Discord sentence for watch end and Mac sleep.

EOF
)"
```

---

### Task 3: Discord destination is the bot

**Files:**
- Modify: `Sources/AgrypnosCore/Notif/NotifIdlePostPolicy.swift`
- Modify: `Sources/AgrypnosCore/Notif/NotifSecretsPayload.swift`
- Modify: `Sources/AgrypnosCore/Notif/NotifOutboundRequest.swift` (delete `discord(webhookURL:content:)`)
- Modify: `Sources/AgrypnosCore/Notif/NotifFieldChrome.swift` (delete `NotifDiscordFieldChrome`)
- Delete: `Sources/AgrypnosCore/Notif/DiscordWebhookURL.swift`
- Modify: `Apps/Agrypnos/Sources/Notif/NotifIdlePoster.swift`
- Modify: `Apps/Agrypnos/Sources/Notif/NotifSecretsStore.swift`
- Modify: `Apps/Agrypnos/Sources/Questions/WatchRuntime+CodexAlert.swift`
- Test: `Tests/AgrypnosCoreTests/DiscordBotOutboundTests.swift` (add the cases below)
- Modify: existing tests that construct `discordWebhookURL` or call `NotifOutboundRequestFactory.discord` so they compile. A webhook URL is no longer a destination.

**Interfaces:**
- Consumes: `DiscordBotOutbound.body`, `DiscordInboundRequestFactory.channelMessage(botToken:channelId:content:)`
- Produces: `NotifIdlePostPolicy.destinations(discordBotToken:discordChannelId:telegramBotToken:telegramChatId:) -> [NotifChannel]`

Discord is a destination only when both bot token and channel id are non-empty after trim. Telegram is unchanged (token and chat id).

- [ ] **Step 1: Add the failing policy and decode tests**

Append to `DiscordBotOutboundTests`:

```swift
func testDiscordDestinationNeedsTokenAndChannel() {
    XCTAssertEqual(
        NotifIdlePostPolicy.destinations(
            discordBotToken: "bot",
            discordChannelId: "123",
            telegramBotToken: nil,
            telegramChatId: nil
        ),
        [.discord]
    )
    XCTAssertEqual(
        NotifIdlePostPolicy.destinations(
            discordBotToken: "bot",
            discordChannelId: "  ",
            telegramBotToken: nil,
            telegramChatId: nil
        ),
        []
    )
    XCTAssertEqual(
        NotifIdlePostPolicy.destinations(
            discordBotToken: nil,
            discordChannelId: "123",
            telegramBotToken: "tg",
            telegramChatId: "9"
        ),
        [.telegram]
    )
}

func testOldWebhookURLIsIgnored() throws {
    let json = Data(#"{"discordWebhookURL":"https://discord.com/api/webhooks/1/abc","discordBotToken":"bot","discordChannelId":"123"}"#.utf8)
    let decoded = try JSONDecoder().decode(NotifSecretsPayload.self, from: json)
    XCTAssertEqual(decoded.discordBotToken, "bot")
    XCTAssertEqual(decoded.discordChannelId, "123")
    let encoded = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(decoded)) as? [String: Any]
    XCTAssertNil(encoded?["discordWebhookURL"])
}

func testChannelMessageIsTheDiscordSend() throws {
    let request = try XCTUnwrap(
        DiscordInboundRequestFactory.channelMessage(botToken: "bot", channelId: "123", content: "Agrypnos: asking the Mac to sleep.")
    )
    XCTAssertEqual(request.url.path, "/api/v10/channels/123/messages")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.headers["Authorization"], "Bot bot")
}
```

- [ ] **Step 2: Run the new tests and see them fail**

Run: `swift test --filter DiscordBotOutboundTests`
Expected: FAIL. `destinations` still takes `discordWebhookURL`.

- [ ] **Step 3: Change the destination and drop the webhook type**

`NotifIdlePostPolicy.destinations` takes `discordBotToken` and `discordChannelId` instead of `discordWebhookURL`. Append `.discord` only when both `present(...)` are true.

Remove `discordWebhookURL` from `NotifSecretsPayload`’s stored properties, init, and encode. In decode, do not read that key. Old files still decode.

Delete `DiscordWebhookURL.swift`, `NotifDiscordFieldChrome`, and `NotifOutboundRequestFactory.discord(webhookURL:content:)`.

`NotifIdlePoster.requests` builds Discord with:

```swift
if channels.contains(.discord),
   let token = secrets.discordBotToken,
   let channel = secrets.discordChannelId,
   let text = DiscordBotOutbound.body(reason: reason, willSleep: willSleep),
   let request = DiscordInboundRequestFactory.channelMessage(
       botToken: token, channelId: channel, content: text)
{
    requests.append(request)
}
```

Add `willSleep: Bool` to `requests` and to `postIfNeeded`. Callers in this task pass `false` except where Task 4 passes the real value. Telegram still uses the old timer / idle sentences, not `DiscordBotOutbound.body`.

`NotifSecretsStore` drops `discordWebhookURL` and any setter that only existed for the webhook field.

`WatchRuntime+CodexAlert.codexHasDestination` and `postCodexAlert` use the new `destinations` signature. Discord alerts use `channelMessage`, not a webhook. The missing-destination sentence is `Save a Telegram chat or Discord bot token and channel id first.`

Do not change `DiscordInboundRequestFactory.interactionEditOriginal`.

- [ ] **Step 4: Fix compile failures in tests**

Search for `discordWebhookURL` and `NotifOutboundRequestFactory.discord`. Delete webhook assertions. Where a test only needed a Discord destination, pass `discordBotToken` + `discordChannelId`. `OpenCodeQuestionSettingsTests` still decodes a legacy JSON blob that contains `discordWebhookURL`; it must keep decoding and must not require that field on the payload.

- [ ] **Step 5: Run Core tests**

Run: `swift test --filter DiscordBotOutboundTests`
Expected: PASS

Run: `swift test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Sources/AgrypnosCore/Notif Sources/AgrypnosCore/Notif/NotifFieldChrome.swift Apps/Agrypnos/Sources/Notif Apps/Agrypnos/Sources/Questions/WatchRuntime+CodexAlert.swift Tests
git commit -m "$(cat <<'EOF'
Send Discord outbound with the bot token and channel id.

EOF
)"
```

---

### Task 4: Send after the lid recheck, before sleep

**Files:**
- Modify: `Apps/Agrypnos/Sources/WatchRuntime+Poll.swift`
- Modify: `Apps/Agrypnos/Sources/Notif/NotifIdlePoster.swift`
- Modify: `Apps/Agrypnos/Sources/WatchRuntime.swift` (`postIdle` closure shape)
- Test: `Tests/AgrypnosMacTests/TimedWatchRuntimeTests.swift` (the timer POST test around the webhook URL)

**Interfaces:**
- Consumes: `DiscordBotOutbound.body(reason:willSleep:)`, `NotifIdlePoster.postIfNeeded(enabled:reason:willSleep:)`
- Produces: one bounded send, then `pmset sleepnow` only if `requestSleep` survived the lid recheck

`willSleep` is true only when `.requestSleep` is still in the command list after the existing lid recheck in `finishTickCommands`. Known-open lid already removes it. Confirmed closed keeps it.

- [ ] **Step 1: Write the failing Mac test**

In `TimedWatchRuntimeTests`, the timer test that expects `"Agrypnos: your watch timer ended."` must expect that sentence with no sleep clause when the fixture lid is open, and `"Agrypnos: your watch timer ended. Asking the Mac to sleep."` when the fixture lid is confirmed closed. The Discord request URL path must be `/api/v10/channels/{id}/messages`, not `/api/webhooks/`.

Add one case: user-off with confirmed lid closed and Watch-end POST on, with bot token + channel id saved, records one Discord body `Agrypnos: Keep the watch is off. Asking the Mac to sleep.` and one `sleepnow`. User-off with the lid open records no Discord body and no `sleepnow`.

- [ ] **Step 2: Run the Mac test and see it fail**

Run the timed-watch test target the repo already uses for `TimedWatchRuntimeTests` (Mac build). Expected: FAIL. The open-lid timer body may already match; the closed-lid clause and the user-off message will not.

- [ ] **Step 3: Move the send to after the lid decision**

In `finishTickCommands`, after the existing block that removes `.requestSleep` for an open or unconfirmed lid:

1. `let willSleep = applyCommands.contains(.requestSleep)`
2. If Watch-end POST is on and `DiscordBotOutbound.body` is non-nil for this reason (or `reason == nil` for already-off disarm), **or** Telegram would send for `.timerExpired` / `.agentsSettled`, await `postIdle(enabled, reason, willSleep)`.
3. Then `apply(applyCommands)`, which runs `sleepnow` if it is still in the list.

The early `idlePostTask` in `handleTick` must not also POST. It may still wait so `sleepnow` does not start first, but the only `postIfNeeded` call is the one after the recheck. One send.

`applyUserOff` and already-off disarm (`[.requestSleep]` with no `.disengage`) use that same wait. If Watch-end POST is off, or token/channel are empty and Telegram will not send, do not wait; sleep immediately as today.

Question unanswered keeps its own notice. When `willSleep` is true, append `" Asking the Mac to sleep."` to that existing sentence. Do not also call `DiscordBotOutbound` for `.questionUnanswered`.

The wait stays `NotifIdlePoster.waitBound` (3 seconds). A failed or slow POST still continues to `sleepnow`.

- [ ] **Step 4: Run the Mac test and Core tests**

Expected: the timed-watch cases PASS. `swift test` PASS.

- [ ] **Step 5: Commit**

```bash
git add Apps/Agrypnos/Sources/WatchRuntime+Poll.swift Apps/Agrypnos/Sources/WatchRuntime.swift Apps/Agrypnos/Sources/Notif/NotifIdlePoster.swift Tests/AgrypnosMacTests/TimedWatchRuntimeTests.swift
git commit -m "$(cat <<'EOF'
Message the Discord bot before asking the Mac to sleep.

EOF
)"
```

---

### Task 5: Remove the webhook card

**Files:**
- Modify: `Sources/AgrypnosCore/Copy/AgrypnosCopy.swift`
- Modify: `Sources/AgrypnosCore/Copy/PopoverSection.swift`
- Modify: `Sources/AgrypnosCore/Copy/PopoverStackLayout.swift`
- Modify: `Apps/Agrypnos/Sources/MenuBar/PopoverController+Notif.swift`
- Modify: `Apps/Agrypnos/Sources/MenuBar/PopoverController+Sections.swift`
- Modify: `Apps/Agrypnos/Sources/MenuBar/PopoverController+Canvas.swift`
- Modify: `Apps/Agrypnos/Sources/MenuBar/PopoverController.swift` (drop `notifDiscordCard` if nothing else uses it)
- Modify: popover tests that list `.notifDiscord` as the webhook card: `NotifPopoverChromeTests.swift`, `DiscordInboundPopoverChromeTests.swift`, `TelegramInboundPopoverChromeTests.swift`, `QuestionNotificationLayoutTests.swift`, `PopoverSectionTests.swift`, `AgrypnosCopyTests.swift`

**Interfaces:**
- Consumes: token, channel, and inbound switch that already live on the Discord inbound card
- Produces: Notif cards `Watch-end POST`, `Discord`, `Telegram`, `Telegram inbound`, setup link. No webhook field.

- [ ] **Step 1: Update the failing copy and layout tests**

Replace webhook expectations with:

```swift
XCTAssertEqual(AgrypnosCopy.notifDiscord, "Discord")
XCTAssertEqual(
    AgrypnosCopy.notifDiscordHelp,
    "Messages this channel when Watch-end POST is on, including when Agrypnos asks the Mac to sleep. Commands: /arm, /disarm, /status, /help, when Discord inbound is on. Needs your bot token + channel id. Details in Setup instructions."
)
XCTAssertEqual(
    AgrypnosCopy.notifEnabledHelp,
    "Message your Discord bot and/or your Telegram bot when the timer ends, when Agents stay idle through the wait, or when Agrypnos asks the Mac to sleep. Off by default."
)
XCTAssertEqual(
    AgrypnosCopy.notifDiscordPostFailed,
    "Couldn't message your Discord bot."
)
XCTAssertFalse(AgrypnosCopy.notifDiscordHelp.lowercased().contains("webhook"))
XCTAssertEqual(PopoverSection.notif.cards.filter { $0 == .notifDiscord }.count, 1)
XCTAssertFalse(PopoverSection.notif.cards.contains(.notifDiscordInbound))
```

Delete the tests that measured a webhook text field under that card. The Discord card’s height is the old inbound card height (title, help, token, channel, switch). Telegram’s y is that card’s maxY plus the card gap. There is no second Discord card.

- [ ] **Step 2: Run the popover tests and see them fail**

Run: `swift test --filter NotifPopoverChromeTests`
Expected: FAIL on the old “Discord webhook URL” strings.

- [ ] **Step 3: Delete the webhook field and point the Discord card at the bot**

- `AgrypnosCopy.notifDiscord` = `"Discord"`.
- `notifDiscordHelp` = the sentence in Step 1.
- `notifEnabledHelp` = the sentence in Step 1. It must not say “webhook”.
- `notifDiscordPostFailed` = `"Couldn't message your Discord bot."`
- Delete `notifDiscordPlaceholder` and `notifDiscordInvalid` if nothing else references them.
- Remove the webhook text field, eye button, and status label from `addNotifDiscordCard`. The card shows the title, the help, token, channel, and the inbound switch (move those rows up from the old inbound card, or make `.notifDiscord` the only Discord card and delete `.notifDiscordInbound` from the section list while keeping the switch).
- One card. Do not leave an empty webhook card in the layout. Recompute `PopoverStackLayout` y positions from the cards that remain. Height still hugs the Notif section.

- [ ] **Step 4: Run Core tests**

Run: `swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Copy Apps/Agrypnos/Sources/MenuBar Tests/AgrypnosCoreTests
git commit -m "$(cat <<'EOF'
Remove the Discord webhook field from Notif.

EOF
)"
```

---

### Task 6: Setup guide, README, SECURITY

**Files:**
- Modify: `Sources/AgrypnosCore/Copy/BotGuideCopy.swift`
- Modify: `Tests/AgrypnosCoreTests/BotGuideCopyTests.swift`
- Modify: `README.md` (the Discord webhook `<details>` block near the bot block)
- Modify: `SECURITY.md` (the outbound paragraph and the lines that say the Discord webhook stays outbound-only)
- Delete: `Apps/Agrypnos/Resources/Assets.xcassets/guide-discord-webhook-integrations.imageset` and `guide-discord-webhook-copy.imageset` after nothing references them

**Interfaces:**
- Consumes: the popover copy from Task 5
- Produces: one Discord setup path in the guide and the README

- [ ] **Step 1: Update the failing guide test**

`BotGuideCopyTests` currently requires a webhook section with “Server Settings → Integrations → Webhooks → New Webhook” and “does not receive commands”. Change it so Discord guide text:

- has no “Webhooks → New Webhook” and no “Copy Webhook URL”
- says the same bot messages the channel when Watch-end POST is on, including when Agrypnos asks the Mac to sleep
- still has the bot steps: Developer Portal, Reset Token, invite with `bot` + `applications.commands` and Send Messages, Developer Mode, Copy Channel ID, inbound switch
- says an old webhook URL is unused; paste the bot token and channel id
- does not contain a sample webhook URL (`discord.com/api/webhooks/`)

- [ ] **Step 2: Run the guide test and see it fail**

Run: `swift test --filter BotGuideCopyTests`
Expected: FAIL on the webhook section.

- [ ] **Step 3: Rewrite the Discord guide and the docs**

Delete `BotGuideCopy.discordWebhook`. `BotGuide.sections(.discord)` starts at `discordBot`. Note on that section: “You own this bot. Agrypnos does not run a shared bot. The same bot messages this channel and receives commands.”

Replace the token step that says “never paste it into the webhook field” with “Paste it into Notif → Discord → Token.”

Add a step before the inbound switch: “Switch on Watch-end POST. Agrypnos messages this channel when the timer ends, when Agents stay idle through the wait, or when it asks the Mac to sleep.”

README: delete the “Discord: idle messages through a webhook” block. In the bot block, say this one bot does messages and commands. Discord commands are still not Mac-proven. Do not describe this sleep message as Mac-proven.

SECURITY.md: Discord outbound is `POST /api/v10/channels/{channel-id}/messages` with the user’s bot token, to the saved channel, when Watch-end POST is on. Same events as the bar in Task 1. Delete “Discord webhook stays outbound-only” and “incoming webhook URL”. Keep: no Interactions Endpoint URL, no listen port, no shared bot, no telemetry, secrets in `notif-secrets.json` mode 0600, confirmed lid-closed sleep is still `pmset sleepnow` with no new sudoers grant.

- [ ] **Step 4: Run Core tests and the line-count check**

Run: `swift test`
Expected: PASS

Run: `Scripts/check-file-sizes.sh`
Expected: no file over 600 lines.

- [ ] **Step 5: Commit**

```bash
git add Sources/AgrypnosCore/Copy/BotGuideCopy.swift Tests/AgrypnosCoreTests/BotGuideCopyTests.swift README.md SECURITY.md Apps/Agrypnos/Resources/Assets.xcassets
git commit -m "$(cat <<'EOF'
Document Discord messages through the user's bot.

EOF
)"
```

---

## Spec coverage

| Asked for | Task |
|---|---|
| Remove the webhook | Tasks 3, 5, 6 |
| One bot for commands and outbound | Tasks 3, 5 |
| Message when Agrypnos sends the laptop to sleep | Tasks 2, 4 |
| Don’t message when the lid is open and nothing sleeps | Task 2 (`willSleep: false`) and Task 4 (existing lid recheck) |
| Bar currently parks this | Task 1 |

Skipped: a Telegram sleep message. Add it only if the Discord sentence should also go to Telegram. Power B panel sleep stays silent.

## Mac check (not part of the Linux tests)

Do not call this Mac-proven until someone does this on a Mac:

1. Notif shows Discord token, channel, and the inbound switch. No webhook field.
2. Watch-end POST on, inbound off, token + channel set. Arm a short timer, lid confirmed closed: one bot message ending in “Asking the Mac to sleep.”, then the Mac sleeps.
3. Same timer with the lid open: the timer sentence, no sleep sentence, Mac stays awake.
4. Lid confirmed closed, turn Keep the watch off: one “Keep the watch is off. Asking the Mac to sleep.” message, then the Mac sleeps.
5. Lid open, turn Keep the watch off: no Discord message, Mac stays awake.
6. `/arm` and `/disarm` still work with inbound on, in that same channel.
7. Sleep panel (Power B) does not send this message; it only sleeps the panel.
