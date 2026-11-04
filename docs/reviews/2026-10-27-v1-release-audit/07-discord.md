# Discord

- verdict: no blockers, no highs — two mediums
- blockers: 0
- high: 0
- scope: `Sources/AgrypnosCore/Notif/Discord*.swift`, Discord branches in the watch-end poster and poll, Discord tests, and the Mac Gateway client. Telegram poll and WatchEngine sleep policy are handoffs.

## Product promise

The user owns the bot. Inbound and outbound use that bot token plus one channel id. There is no incoming webhook, no Interactions Endpoint URL, and no listen port. Receive is a Gateway WebSocket from this Mac. Commands are `/arm` `/disarm` `/status` `/help` on the same WatchEngine path as Telegram, and only from the saved channel. Empty token or empty channel id means no inbound. Inbound defaults off, separate from Watch-end POST, which also defaults off.

Wake-miss drains queued Gateway commands without applying them and without reading channel history. If a command was queued, the reply is “Missed while asleep.” There is no live reply while the Mac is asleep.

`/disarm` uses the same lid gate as popover off: open or unconfirmed does not sleep the Mac; confirmed closed runs `sleepnow` even if Keep awake was already off. `/status` is the same facts as Telegram, including battery when known, with no ETA or task text.

Outbound is one bot channel message to the saved channel when Watch-end POST is on and both token and channel id are set. Events are timer expiry, settle after busy was seen this arm, and a disengage that will `pmset sleepnow` (user-off, inbound disarm, battery, thermal, Low Power Mode, already-off confirmed-closed disarm). Timer or idle-after-wait that is also sleeping the Mac adds “Asking the Mac to sleep.” The body does not say the Mac slept. Power B panel sleep does not message. A never-busy arm does not message.

Secrets stay in Application Support `notif-secrets.json` mode 0600. Not Keychain. Not logs.

## Gates checked

| Gate | Result | Evidence |
|---|---|---|
| User’s own bot. Token + channel id. No shared bot | PASS | Payload fields `Sources/AgrypnosCore/Notif/NotifSecretsPayload.swift:6-7`, `:10-16`. No hardcoded bot token in the Discord sources. |
| Incoming webhook URL is gone. No webhook paste, webhook POST, or stored webhook field | PASS | Decode/encode never read or write `discordWebhookURL` `NotifSecretsPayload.swift:82-97`. Token paste that contains `/api/webhooks/` is rejected `Sources/AgrypnosCore/Notif/NotifFieldChrome.swift:72-76`; channel id must be digits `:81-91`. Outbound is `POST /api/v10/channels/{id}/messages` `DiscordInboundRequest.swift:33-46`. `api` returns nil for any `webhooks` path except `PATCH .../messages/@original` `:120-137`, `:370-376` in `Tests/AgrypnosCoreTests/DiscordInboundPolishTests.swift`. That PATCH is the deferred slash edit (`DiscordInboundRequest.swift:90-107`), not a user webhook. Do not delete it. |
| No Interactions Endpoint URL. No listen port. No public callback. Gateway on the Mac | PASS | `interactionsEndpointRegistration()` is nil `DiscordInboundRequest.swift:115-118`. `listenPort` is nil `DiscordInboundGateway.swift:5-9`. The Mac client opens `URLSessionWebSocketTask` `Apps/Agrypnos/Sources/Notif/DiscordInboundGatewayClient.swift:124-139`. It does not bind. Unix sockets in the question hooks are not this path. |
| Commands only from the saved channel. Empty token or empty channel: no inbound | PASS | `shouldReceive` `DiscordInbound.swift:31-39`. Channel must match, including trim, or the intent is ignore `:41-68`. Mac apply uses that policy `WatchRuntime+DiscordInbound.swift:169-176`. Gateway `sync` does not start unless `shouldReceive` `DiscordInboundGatewayClient.swift:71-78`, `:114-122`. |
| Inbound default off, separate from Watch-end POST default off | PASS | `discordInboundEnabled: Bool = false` and `notifEnabled: Bool = false` are separate keys `Sources/AgrypnosCore/Session/UserPreferences.swift:65`, `:67`. Tests `Tests/AgrypnosCoreTests/DiscordInboundTests.swift:6-7`. |
| Same `/arm` `/disarm` `/status` `/help`. No second arm stack | PASS | Slash menu is those four `DiscordInboundPolishTests.swift:263-267`. Mac arm calls `setEngaged(true)` and disarm calls `disarmWatch()` `WatchRuntime+DiscordInbound.swift:217-226`, the same calls as Telegram `WatchRuntime+TelegramInbound.swift:149-158`. |
| Wake-miss: drain without apply. Do not scrape history. Reply missed if something was queued. No live-asleep reply | PASS for the drain. Resume delivery is V1-DC-01 | Unseeded wake cursor `DiscordInbound.swift:164-173`. Replay records sequence and stays unseeded until `RESUMED` `DiscordGatewaySession.swift:50-55`. Dispatch does not apply `.wakeMiss` `TelegramInboundPolish.swift:34-47`. History fetch is nil `DiscordInboundRequest.swift:110-113`. Missed copy is “Missed while asleep.” `DiscordInbound.swift:226`. Sleep sets that cursor and bumps the slash epoch `WatchRuntime+TelegramInbound.swift:35-37`; wake restarts the socket `DiscordInboundGatewayClient.swift:36-41`. |
| `/disarm` lid gate, including already off | PASS at the Discord call. Sleep matrix is WE | `applyDiscordDisarm` → `disarmWatch` `WatchRuntime+DiscordInbound.swift:224-226`. Already-off confirmed close still requests sleep in the shared engine `DiscordInboundPolishTests.swift:227-231`. |
| `/status` matches Telegram, battery when known, no ETA or task text | PASS | Discord reply calls `TelegramInboundCopy.status` `DiscordInbound.swift:249-262`. Countdown only when the mode has minutes `TelegramStatus.swift:72-74`; ∞ and Agents have no minutes `DurationOption.swift:16-18`. Battery line omitted unless percent and discharging are both known `TelegramStatus.swift:120-126`. No ETA field in that reply. |
| Outbound: one channel message for timer, busy-seen settle, and `sleepnow` disengages. Sleep clause. Do not claim slept. Power B silent. Never-busy silent | PASS | Bodies `DiscordBotOutbound.swift:6-28`. Poster sends that one Discord request only when token and channel are present `NotifIdlePoster.swift:34-48`. Poll sets `willSleep` from `requestSleep`, not from panel sleep `WatchRuntime+Poll.swift:225-233`, `:339-356`. User-off uses the confirmed-lid bool `:383-398`. Never-busy does not settle: `shouldPost` requires `sawBusy` `NotifIdlePostPolicy.swift:8-14`. |
| Secrets in `notif-secrets.json` mode 0600. Not Keychain. Not logs | PASS in code | `NotifSecretsStore.swift:14-16`, `:91-111`. Discord diagnostics lines do not interpolate the token. |

## Findings

### V1-DC-01

- severity: MEDIUM
- confidence: high that the host is rejected; medium that a given wake loses the replay (Discord still accepts Resume on the generic gateway sometimes, and says that path disconnects faster)
- breaks: after the socket drops, or after the Mac sleeps, Agrypnos does not open the session URL Discord sent. Wake-miss then may never see the queued commands, so it cannot reply “Missed while asleep.” It also does not apply them, and it does not read channel history.
- evidence: `resumeURL` and the gateway-bot parser keep a host only when it `hasSuffix("gateway.discord.gg")` `DiscordInboundRequest.swift:190-191`, `:212-218`. `socketURL` uses that URL only when the check returns one; otherwise it uses Get Gateway Bot or `wss://gateway.discord.gg` `:198-209`. The client still sends Resume when the cursor can resume `DiscordGatewaySession.swift:25-27`, onto whatever URL `runConnection` opened `DiscordInboundGatewayClient.swift:124-129`. Discord’s live resume host is `gateway-<zone>.discord.gg` (example `wss://gateway-us-east1-b.discord.gg`). That string does not end in `gateway.discord.gg`. Tests only round-trip `wss://us-east.gateway.discord.gg` `DiscordGatewaySessionTests.swift:53-62`, which is not the host Discord sends. Docs: resume must use `resume_gateway_url` or the session is disconnected at a higher rate (https://docs.discord.com/developers/events/gateway).
- trigger: inbound on, token and channel saved, Gateway has reached READY, then the Mac sleeps or the socket drops. On the next connect Discord’s READY `resume_gateway_url` is the regional host.
- expected: reconnect to that `wss` host, Resume, drain replayed commands as missed, do not arm or disarm them.
- actual: the regional host is discarded. Resume is attempted on `gateway.discord.gg`. If Discord invalidates that session, the next identify does not replay, so nothing is queued locally and no missed reply is sent.
- fix_files: `Sources/AgrypnosCore/Notif/DiscordInboundRequest.swift`, `Tests/AgrypnosCoreTests/DiscordGatewaySessionTests.swift`
- fix: accept `wss` hosts that are `gateway.discord.gg`, end with `.gateway.discord.gg`, or are `gateway-` plus `.discord.gg`. Keep rejecting every other host so the bot token is not sent off Discord.
- test_first: `resumeURL(from: "wss://gateway-us-east1-b.discord.gg")` returns that host, and `socketURL` with `canResume: true` returns it. `wss://evil.example` and `wss://gateway.discord.gg.evil.com` stay nil.
- do_not: do not resume to an arbitrary URL. Do not scrape channel history when resume fails. Do not replace Gateway with an Interactions Endpoint URL or a webhook.

### V1-DC-02

- severity: MEDIUM
- confidence: high that the reply is a blank character; medium that a person reads the empty slash result as success
- breaks: `/arm` or `/disarm` outside the saved channel does not change the watch, and the slash interaction still completes with no words. The menu is global, so the command is offered in every channel.
- evidence: ignore and non-command apply both reply with U+200B for slash `WatchRuntime+DiscordInbound.swift:179-180`, `:204-205`. Wrong-channel intent is `.ignore` `DiscordInbound.swift:50-52`, and ignore never applies `TelegramInboundPolish.swift:39`. Commands are registered on the application, not one guild `DiscordInboundRequest.swift:12-30`.
- trigger: inbound on, saved channel A, user runs `/arm` in channel B.
- expected: Keep awake unchanged. The slash reply says the command was not used, in plain words.
- actual: Keep awake unchanged. The interaction is edited to a zero-width space, so Discord does not show “This interaction failed,” and it also does not show “Armed.”
- fix_files: `Apps/Agrypnos/Sources/Notif/WatchRuntime+DiscordInbound.swift`
- fix: for a slash ignore, edit the deferred reply to one sentence that the command was not applied. Keep the channel check in front of `setEngaged` / `disarmWatch`.
- test_first: a slash update whose channel id is not the saved id produces a non-empty reply and does not call arm or disarm. A matching channel still applies.
- do_not: do not apply the foreign-channel command. Do not drop the deferred ACK and leave the interaction failed. Do not filter by scraping history.

## Handoffs

- TG: command parse, drain effect, status lines, and the disarm sleep predicate are the shared Telegram types. Discord calls them. Telegram `getUpdates` was not reviewed here.
- WE: `disarmWatch` / `applyUserOff` and `disengage` decide `sleepnow`. This pass checked that Discord calls that path and that the Discord sentence follows `willSleep`. The lid matrix itself was not re-audited.
- QR: question button clicks are ignored unless the drain is live and the message channel is the saved channel `QuestionRelayCoordinator.swift:150-153`. They do not arm the watch. The click is still deferred before that check `WatchRuntime+DiscordInbound.swift:90-95`.

## Needs a Mac

- Inbound on: the `/` menu shows the four commands. A command in another channel does not arm or disarm.
- Sleep with a command in flight, then wake: missed reply, watch unchanged, no second apply. This is the V1-DC-01 check.
- Lid open `/disarm`: watch off, Mac stays awake. Confirmed closed `/disarm`: watch off and the Mac sleeps. With Watch-end POST on, one channel message, and it does not say the Mac slept.
- Timer with the lid open, then with the lid confirmed closed. Power B confirmed lid close does not send a watch-end message. An Agents arm that never saw a local busy signal does not message.
- After a save, `notif-secrets.json` is mode 0600. Console does not contain the bot token.

## Unproven

- A live READY `resume_gateway_url` from this bot was not captured tonight. The code rejects `gateway-<zone>.discord.gg` whether or not this process has seen one.
- Mac runtime tests cover timer and user-off Discord bodies `TimedWatchRuntimeTests.swift:224-326`. Battery, thermal, Low Power Mode, and already-off confirmed-closed sentences are covered in `DiscordBotOutbound.body` and the poll `willSleep` branch, not by a runtime fixture.
- The Developer Portal Interactions Endpoint URL is outside the repo. The app never registers one.
- Mode 0600 was not checked on a file this process wrote.
