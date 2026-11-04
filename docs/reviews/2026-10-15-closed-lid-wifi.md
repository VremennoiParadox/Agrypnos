# Closed-lid Wi-Fi — 15 October 2026

Agrypnos has no command that turns Wi-Fi off. On a long closed-lid Agents watch, two different things can look the same from the phone.

This Mac, checked while the watch was off: MacBook Air, M4, model identifier `Mac16,12`. `SleepDisabled` was `0`.

## What the bot message proves

A message on your phone from your Discord or Telegram bot left this Mac. `NotifIdlePoster` sends one HTTPS request, waits at most 3 seconds, and does not wait for the interface to come back (`waitsForConnectivity = false`).

- The phone got the message: this Mac had a working route to Discord or Telegram for that request.
- The phone got nothing, and the Mac showed “Couldn't message your Discord bot.” or “Couldn't message your Telegram bot.”: that request failed.

The Agents sentence is `Agrypnos: local busy signals went idle after the wait.` Discord adds ` Asking the Mac to sleep.` when this end will run `pmset sleepnow`. Telegram sends the idle sentence only.

That sentence means Agrypnos already decided the selected tools looked idle. It does not mean Agrypnos saw a Wi-Fi failure.

## What Agrypnos actually runs

Privileged grant, two commands, nothing else (`Sources/AgrypnosCore/Power/SudoersGrant.swift`):

```
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -a disablesleep 1
```

Other power commands, run as you, not through that grant:

| Command | When | What Apple’s `pmset` man page on this Mac says |
|---|---|---|
| `pmset sleepnow` | Closed-lid watch end (Agents idle, timer, safety, user-off, inbound `/disarm`) | “causes an immediate system sleep” |
| `pmset displaysleepnow` | Power B, confirmed lid close only | “causes display to go to sleep immediately” |
| `caffeinate -u -t 1` | Wake the panel after Power B, one shot | Declares the user active. Turns the display on if it is off. |

`disablesleep` is absent from this Mac’s `pmset` man page. Apple’s `pmset` source sets only `kIOPMSleepDisabledKey` (`SleepDisabled` in `pmset -g`), then calls `IOPMSetSystemPowerSetting`. The comment there says powerd configd picks that up and sends it to xnu. That branch does not touch Wi-Fi, `tcpkeepalive`, or `networkoversleep`.

Source: [apple-oss-distributions/PowerManagement `pmset.m`](https://github.com/apple-oss-distributions/PowerManagement/blob/3c3457838445194a85e09161bec9726420ba0402/pmset/pmset.m) (`ARG_DISABLESLEEP`, and the `IOPMSetSystemPowerSetting` loop).

`/usr/bin/pmset` on this Mac contains the strings `disablesleep` and `tcpkeepalive`. It does not contain `wifi`, `wi-fi`, `airport`, or `80211`.

In current xnu, closing the clamshell is demand sleep: “Demand Sleep is initiated by pressing the front panel power button, closing the clamshell, or selecting the menu item.” That path calls `privateSleepSystem`, which returns `kIOReturnNotPermitted` unless `checkSystemSleepEnabled()` passes. The check fails when `userDisabledAllSleep` is set. The kernel comment calls that flag the “user-space sleep kill switch” and says the conditions above it “peg the system at full wake.” The conditions below “prevent system sleep but do not prevent dark wake.”

Source: [xnu `IOPMrootDomain.cpp`](https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/iokit/Kernel/IOPMrootDomain.cpp) (`shouldSleepOnClamshellClosed` is a separate desktop-mode check; the kill switch is `checkSystemSleepAllowed`).

`tcpkeepalive` on this Mac is `1`. Apple’s `pmset` source warns that setting it to `0` “disables TCP Keep Alive mechanism when sytem is sleeping.” That is a sleep-time keepalive. Agrypnos never writes it. The kill switch above is what holds an armed watch in full wake, so that sleep-time switch is not an awake-association control.

`networkoversleep` on this Mac is `0`. The man page: it “affects how OS X networking presents shared network services during system sleep” and “changing its value is unsupported.” Agrypnos never writes it.

No `networksetup`, Wi-Fi framework, or interface power call exists in the app. The project bar forbids killing Wi-Fi.

## Order when Agents mode ends with the lid closed

Test `testLidClosedAgentsSettleDisengagesAndRequestsSleep` expects this command list:

1. `.disengage(.agentsSettled)`
2. `.postIdleAfterWaitNotif`
3. `.requestSleep`

Runtime order matches that: send the bot message, clear `SleepDisabled`, then `pmset sleepnow` if the lid is still confirmed closed (`Apps/Agrypnos/Sources/WatchRuntime+Poll.swift`, `finishTickCommands`).

So a phone message and a later Wi-Fi drop can both be Agrypnos doing the designed end of an Agents watch:

1. Local process and session signals were already quiet through the idle wait (default 2 minutes).
2. The bot message went out while the route still worked.
3. The Mac was asked to sleep (`pmset sleepnow`). The man page calls that immediate system sleep. Apple does not document that system sleep switches the Wi-Fi radio off. What it does document is that the machine leaves full wake. The phone message already left before that command.

Cursor counts as busy only when its process is running and a session file was written inside the freshness window (45 seconds). CPU does not count for Cursor. A Cursor process that is still alive, with no fresh session write, looks idle. Claude Code and Codex can also count CPU. OpenCode is process plus session files.

“Idle” here means those local signals stopped. It does not mean Agrypnos measured the Wi-Fi interface.

## The 11 October incident is the other pattern

[docs/reviews/2026-10-11-overnight-cursor-investigation.md](docs/reviews/2026-10-11-overnight-cursor-investigation.md) already logged a night where Cursor recorded connection timeouts and DNS failure from about 02:40, and the power log showed no system sleep through 11:00. Agrypnos kept running. The retained Wi-Fi events did not say why the route failed. A later Agrypnos send saw the route unavailable.

That night is a real network failure while the Mac stayed awake. `sleepnow` does not explain it. Nothing in the power commands above turns the radio off either. The report left the network cause unknown. This pass did not reopen those raw logs, and today’s `wifid` log query returned no events (the watch was off).

## Closed lid, from Apple

[Put your Mac to sleep or wake it](https://support.apple.com/guide/mac-help/put-your-mac-to-sleep-mh10330/mac): “On a Mac laptop, close the display.”

Apple’s MacBook Air guide says you close the lid after an external display is connected, then keep using the Mac with that display and accessories: [Connect an external display to MacBook Air](https://support.apple.com/guide/macbook-air/connect-an-external-display-apd8cdd74f57/mac). The fetched page is the current guide (it mentions M5 and says most steps apply to other models). The closed-lid sentence is tied to an external display.

[If your external display is dark or low resolution](https://support.apple.com/en-us/102501): “If the display is connected to a Mac laptop computer with a closed lid, make sure that the Mac is connected to power and using an external keyboard and mouse.”

Agrypnos holds the Mac awake with the lid closed and no external display. Apple’s documented lid-close gesture is sleep. The kernel kill switch above is what keeps the watch from taking that sleep. Those articles do not say Wi-Fi powers off when something else holds the machine in full wake.

[MacBook Air (13-inch, M4, 2025) Repair Manual](https://support.apple.com/en-us/122003) lists “Left Speaker with Antenna” and “Right Speaker with Antenna” as procedures, and lists “Display” separately. Apple does not say in that manual where the signal goes when the lid is closed.

This Mac: `net.inet.tcp.always_keepalive` is `0`, and `net.inet.tcp.keepidle` is `7200000`. Apple’s TCP header defines the idle time before keepalive probes, when a socket has them enabled, as 120 minutes (`TCPTV_KEEP_IDLE`, 1 ms ticks). Apple’s networking notes say an idle TCP connection stays open until the program closes it, unless keepalive is on for that socket. Apple does not document a long-lived connection dying while a short HTTPS request still succeeds. Source: [xnu `tcp_timer.h`](https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/bsd/netinet/tcp_timer.h), [Avoiding Common Networking Mistakes](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/NetworkingOverview/CommonPitfalls/CommonPitfalls.html).

## Is it fixable in Agrypnos?

No Wi-Fi patch belongs in this app.

- A radio power cycle would be a new network control. The bar forbids that, and it would not explain the 11 October DNS failures while the Mac stayed awake.
- Changing `tcpkeepalive` or `networkoversleep` would edit sleep-time settings Apple marks as unsupported to change (`networkoversleep`). They are not awake-association switches.
- Stopping `sleepnow` on Agents idle would change a landed sleep path. That path runs after the agent already looked idle. It explains a drop that happens with the bot’s “Asking the Mac to sleep.” It does not explain a drop while the watch is still armed.

Practical split, next time, about one minute:

1. Read the bot sentence.
2. Open the lid and look at the menu-bar eye and the Watch section’s last-end line.

| What you see | What happened |
|---|---|
| Discord text includes “Asking the Mac to sleep.” Watch is off. Last end is agents idle. | Agrypnos ended the watch and asked the Mac to sleep. The phone message went out first. |
| Watch still armed (eye still blue, gold, or purple). Wi-Fi menu shows disconnected. Other phones still online. | The Mac stayed awake and this Mac’s association dropped. Agrypnos has no switch that does that. |
| Phones and the Mac drop together. | The router or the upstream link dropped. The bot message can still arrive if the link came back before the 3-second send. |

An Ethernet adapter avoids the Wi-Fi radio. That is a cable, not an Agrypnos change.
