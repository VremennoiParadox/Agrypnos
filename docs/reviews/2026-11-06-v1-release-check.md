# V1 release check — 2026-11-06

Pre-release pass over `main` at `dba9763` (Auto-on merged). It covers code, popover UI, first-run path, packaging, and docs. It builds on the [October audit](2026-10-27-v1-release-audit/REPORT.md). That audit's 19 fixes are in. I spot-checked 1 (unanswered question ends the watch in `WatchEngine.tick`), 5 (`finishDisengageHygiene` drops the capture only on `sleepnow == .ok`), and 6 (`pollLid` ignores a nil lid read).

Nothing here is fixed yet. The decisions you need to make are at the end.

## Evidence used

| What | Result |
|---|---|
| `swift test` (Core + Mac suites) | 874 tests, **6 failures, all in `OpenCodePluginNativeTests`** (see B3) |
| `Scripts/check-file-sizes.sh` | Pass. `WatchRuntime.swift` is at 597 / 600 |
| Compiler | 5 Swift 6 concurrency warnings (M9) |
| Popover render | Every section rendered offscreen from the real `PopoverController`, off and armed, light mode. Dark mode could not be rendered faithfully offscreen; check it on the Mac |
| `dist/Agrypnos.app` | 0.1.0 (1), ad-hoc signed, hardened runtime, no team, arm64 + x86_64. Resources: `AppIcon.icns`, `Assets.car`, `grant.sh`. **No `agrypnos-opencode.js`** |
| Your Auto-on run today | `/private/tmp/claude-501/agrypnos-live.log`, `pmset -g log`, and the Claude Code transcript (entry types and times only) |

---

## Blockers

### B1. Agents mode ends in the middle of a long model reply (your run today)

**What happened.** Idle wait was 1m 30s (the minimum). Timeline from the app log:

| Time | Event |
|---|---|
| 12:59:33 | Auto-on armed |
| 13:00:43 | Lid confirmed closed. Sleep panel slept the display |
| 13:02:43 | Claude Code wrote a tool result and sent the next request to the model |
| 13:03:28 → 13:05:18 | No transcript write, CPU under 5%. Busy reads false. Idle wait runs out |
| 13:05:18 | `watch end reason=agentsSettled lidConfirmed=true`. Bot message, then `sleepnow` |
| 13:05:22 | Claude Code writes the model's reply. The Mac is already going to sleep |

The agent was this Claude Code session. It spent about 2 min 40 s producing one reply. During that time Claude Code writes nothing to the transcript and its CPU stays low, because it is waiting on the network. Agrypnos tolerates roughly 45 s session freshness plus the idle wait, so about 2 m 15 s at your setting and about 2 m 45 s at the 2 m default. Long replies routinely run longer than that.

**The signal that was available.** The transcript's last entries were a `tool_result` and an `api-request` with no assistant reply after them. In other words the turn was still open. Every finished Claude Code turn ends with an assistant entry whose `stop_reason` is `end_turn`.

**Fix options (your call, see Q1):**
- **(a) Open-turn signal.** For Claude Code (and Codex, whose session files have the same shape), count the session as busy while its newest entry shows a turn that is still open and the agent process is alive. Cap it, for example no write for 10 minutes means not busy, so a crashed or stuck agent cannot hold the Mac awake forever. This is still a local session file. It does read entry *types*, not just mtimes, so the bar's busy-signal list changes. Copy stays the same: no "still thinking" claims.
- **(b) Longer idle wait.** Raise the default (and maybe the minimum). Simple, but any reply longer than the wait still fails.
- **(c) Both.**

Related, also from today's log: Auto-on armed and ended twice while you were using the Mac with the lid open (12:37 → 12:42, 12:50 → 12:53). Each end sent a bot message, because Watch-end POST is on. See H1.

### B2. The OpenCode plugin file is missing from every built app

`Apps/Agrypnos/Resources/agrypnos-opencode.js` is not in `Scripts/generate-xcodeproj.py`. The project file listed it until `345cf65` (the Auto-on card commit) regenerated `project.pbxproj` from the generator and dropped it. Neither `dist/Agrypnos.app` nor the Debug build you are running contains the file.

What the user sees: **Enable OpenCode forwarding** fails with "OpenCode: couldn't write setup files or start the local connection. Check config permissions." That sends them to check permissions for a file we never shipped.

Fix: add the resource to the generator, regenerate, and make `build-macos.sh` fail if any expected resource is missing. CI never builds the app (see T1), which is how this slipped through.

### B3. OpenCode forwarding only works on exactly OpenCode 1.18.32

The version is hard-coded in three places: `agrypnos-opencode.js:47`, `OpenCodeBridgeSocket.swift:132`, `OpenCodePluginQuestionSource.swift:67`. This Mac has OpenCode **1.18.34**. The plugin quietly turns itself off. The popover then says "OpenCode: installed, waiting. Restart OpenCode once to load forwarding." forever, and restarting does not help. This is also why the native end-to-end test fails: the fixture runs the installed 1.18.34.

Anyone who installs OpenCode today gets a newer version. Fix options are in Q3.

### B4. No downloadable build

The README says to build with Xcode. The app is ad-hoc signed, not notarized, and has no release asset. For "users on GitHub" this is the first screen they hit. See Q2. Whichever route you pick, these follow:
- **App Translocation.** A downloaded app opened from `~/Downloads` runs from a random read-only path. The Claude and Codex hooks store the app's absolute path, so they break on the next launch. Either ship a DMG that teaches drag-to-Applications, or check `Bundle.main.bundlePath` for `/AppTranslocation/` and ask the user to move the app first.
- **The license** is not in the app bundle (MIT requires the notice to ship with copies).
- **The version** is still 0.1.0 (1). Pick the release number in `Info.plist` and the generator, then tag it.

---

## High

### H1. Auto-on with a short idle wait flaps during normal use
Today Auto-on turned Keep awake on and off three times in 30 minutes. With Watch-end POST on, each end is a bot message. B1 (a) removes most of the flapping. Separately, decide whether a watch that Auto-on started, ending with the lid open, should message at all (Q5).

### H2. Codex card repeats its help as the status line, cut off mid-sentence
`WatchRuntime+CodexAlert.swift:14` returns `QuestionSetupChrome.codexHelp` when alerts are off. The 2-line status slot shows the help a second time, truncated at "…approval, while". Claude and OpenCode say "…: forwarding off." Fix: "Codex: alerts off."

### H3. Cards have large empty bands
The popover uses fixed y-offsets with a hand-estimated maximum line count for each text (`CopyWrap.swift`, `PopoverStackLayout.swift`). Every card reserves room for its longest possible text:
- **How long:** 8 lines reserved plus the countdown, 5 used. About 100 pt of blank on the first screen a new user sees.
- **Wait after agent signals stop:** blank band between the help and the slider.
- **Watch-end POST, Auto-on, Count terminal sessions, Thermal auto-off:** the switch sits at the bottom right, below a gap. **Keep awake, Keyboard backlight, Launch at login** put the switch on the title row. Two patterns for the same control.
- **Forward agent questions:** large gaps between its paragraphs.

The same scheme can also clip text if copy grows past its guessed line count. Fix options are in Q4.

### H4. Notif secret fields are too narrow to read
Placeholders are cut off: "paste bot tol", "from getUpd". Cause: the label column grew to 152 pt for "Telegram user id" / "Discord user id" (`CopyWrap.swift`, `secretFieldLabelWidthPoints`). The October health note already proposed the fix: label the row "User id", keep the long name for VoiceOver, and restore the narrow label column.

### H5. Uninstall can strand the wake hold, and there are no uninstall steps
- `Scripts/ungrant.sh` deletes the sudoers rule without running `pmset -a disablesleep 0` first. If Keep awake is on at that moment, neither the app nor the crash helper can clear it anymore. The Mac then won't sleep with the lid closed until reboot.
- The README has no uninstall section. Leftovers: the Claude hook in `~/.claude/settings.json`, the Codex hook in `~/.codex/hooks.json`, the OpenCode plugin and `tui.json` entry, the login item, `~/Library/Application Support/Agrypnos`, and the sudoers rule.
- Someone who downloaded the app has no `Scripts/` folder. Give them the two commands inline.

### H6. Local banners show as "Script Editor", or not at all
`UserNotify.post` runs `osascript display notification`. macOS attributes those banners to Script Editor. They may never appear if Script Editor has no notification permission. This path carries grant-missing, low battery, thermal, Low Power Mode, hotkey failure, and wake-hold failures. Verify on a clean account. The option is in Q6. This is the local banner, not the Notif bot path, so the parked "Notification Center as Notif" item does not cover it.

---

## Medium

- **M1. The default How long is ∞.** The README Quick start says to pick Agents first, and Auto-on only works on Agents. A new user who just flips Keep awake gets a watch that never ends by itself (Q7).
- **M2. Grant flow.** Clicking **Not now** shows "The lid-close grant isn't installed yet. macOS will ask once.", which is wrong after a decline. The admin prompt runs synchronously on the main thread with a 120 s timeout (`GrantAndNotify.swift`). The menu bar and popover freeze while the password dialog is up, and a slow typist past 2 minutes loses the dialog.
- **M3. Jargon on first-run screens.** "Watch-end POST" uses an HTTP verb as a title. The How long hint says "lid confirmed closed … open or unconfirmed" (the bar's own good example omits "or unconfirmed"). That hint is 5 lines long on a fresh install. "Sends the Mac to sleep by the end of the timer unless the lid is open" reads awkwardly. Suggested direction, within the bar: "Message when Keep awake ends", and "When the timer ends, the Mac goes to sleep unless the lid is open."
- **M4.** The Discord card help wraps "/help" as "/" + "help" across two lines.
- **M5. The armed color doesn't match.** The menu-bar eye is blue / gold / purple by mode. The popover header eye is always gold when armed, and the Keep awake card is always lavender.
- **M6.** The popover refreshes every 5 s even while closed, and calls `SMAppService.mainApp.status` each time (`PopoverController.swift:219`). It's small, but it is constant background work in an app whose job is battery.
- **M7.** If the prefs fail to decode, every setting silently resets to its default (`PreferencesStore.swift:17`). The store also writes a stray `batteryFloorPercent` key that nothing reads.
- **M8.** A second launch (for example, login item plus a manual open) quits with "Couldn't take ownership of the wake hold. Agrypnos may already be running." It would be friendlier to open the running instance's popover.
- **M9.** 5 Swift 6 warnings: "reference to captured var 'self' in concurrently-executing code" (`WatchRuntime+Poll.swift:98`, `DiscordInboundGatewayClient.swift:98,258`, `TelegramInboundPoller.swift:153,179`). Not bugs today. They become errors in Swift 6 mode.
- **M10.** Popover: the **General** section mixes card and bare rows (Launch at login is in a card; Shortcut and Quit are not). The **Last watch end** card on a fresh install says only "Keep awake has not ended yet." It could hide until there is an end to show.

## Tests and CI

- **T1.** CI runs only the Linux Core tests and the size cap. The app never builds in CI and `AgrypnosMacTests` never runs there. That is how B2 shipped. Add a `macos-14` job: build the app, assert the bundled resources, and run the Mac tests with the native OpenCode test skipped.
- **T2.** `OpenCodePluginNativeTests` is the only end-to-end OpenCode check, and it has been red since October. Fix it alongside B3, or skip it with a clear reason. Do not leave it permanently red.

## Ponytail (cuts, not bugs — do after the release fixes)

- `NotifSecretsStore.swift:7` — yagni: `NotifSecrets` copies `NotifSecretsPayload` field for field. Use the payload type.
- `WatchRuntime.swift:258-330` — shrink: six near-identical `setNotif…` setters (~70 lines). One setter keyed by field.
- `AgrypnosCopy.swift` `durationHint(remainingSeconds:)` — delete: the parameter is ignored.
- `WatchEngine.swift` `rollbackDisarmFailure(lidClosed:)` — delete: the parameter is ignored.
- `WatchEngine.applyTelegramInbound` — delete: pass-through to `applyInbound`.
- `WatchRuntime.swift` — yagni-in-reverse: 597 lines and ~70 stored properties, the "AppDelegate 2" the bar warns about. The ~20 question-relay properties belong in their own object before the next feature lands.
- `PopoverStackLayout` + `CopyWrap` — native: if Q4 goes to stack views, most of these two files go away.

net: about -150 lines possible without the layout change.

## Cleared

- The agent walker reads only `~/.claude`, `~/.codex`, `~/.cursor`, and `~/.local/share/opencode` (or the env overrides). No Documents/Desktop access, so no surprise macOS privacy prompts.
- Auto-on gate matches the bar: 30 s of continuous busy, lid not closed, safety would not end it at once, waits for quiet after any end, never runs the grant installer, never changes How long.
- Wake hold, crash guard, quit, and lid-confirm paths are unchanged since the October audit cleared them.

## Not checked here (needs eyes on the Mac)

- Dark mode for every section.
- First launch on a clean user account: Gatekeeper, the grant prompt, where notifications appear.
- Esc and Cmd-Tab with the popover open (it closes only on clicks elsewhere).

---

## Decisions (answered 2026-11-06)

| # | Decision | What it means for the fix list |
|---|---|---|
| Q1 | You will raise your own idle wait. No new busy signal, no default change | B1 stays a known limitation: a model reply longer than about freshness (45 s) + idle wait still ends the watch. No code change. Say this plainly in the idle-wait help and the README |
| Q2 | Notarized DMG | Needs a **Developer ID Application** certificate. In October this Mac had only Apple Development / Distribution ones. You create the certificate and store a `notarytool` keychain profile yourself (Apple ID credentials are yours to enter). I write the archive → sign → notarize → staple → DMG script, add the license to the bundle, and rewrite README install and uninstall around the DMG |
| Q3 | Accept newer OpenCode | Gate on the `question.reply` / `question.list` API instead of the exact version, verify end to end on 1.18.34 with the native test, and show the detected version in the status line |
| Q4 | Trim card heights now | Size each card to its real text, one switch position. Stack views stay after V1 |
| Q5 | Quiet Auto-on ends | A watch Auto-on started that ends with the lid open sends no bot message |
| Q6 | Real notifications | Local banners move from `osascript` to `UNUserNotificationCenter` |
| Q7 | Default How long: Agents | New installs start on Agents. Saved prefs keep theirs |

Q5, Q6, and Q7 are new human decisions. They go into `AGENTS.md` with today's date before the code changes, the same way earlier decisions were recorded.

Everything else in this report (B2, B3, H2–H5, M2–M10, T1, T2) needs no decision and goes on the fix list as written.

## Original questions

| # | Question | My recommendation |
|---|---|---|
| Q1 | B1: open-turn signal, longer idle wait, or both? | Both: the open-turn signal with a 10-minute cap, plus a 3-minute default idle wait |
| Q2 | B4: Developer ID + notarized download, unsigned zip with Gatekeeper steps, or build-from-source only? | Developer ID + notarized DMG, if you have or can get the $99 account. Otherwise an unsigned DMG with clear "Open Anyway" steps |
| Q3 | B3: accept newer OpenCode 1.18.x (verify on 1.18.34 here), or keep 1.18.32 and say so in the popover? | Accept any version that has the `question.reply` / `question.list` API, re-run the native test on 1.18.34, and show the detected version in the status line |
| Q4 | H3: trim each card to its real text now, or move the popover to stack views? | Trim now (small, safe before release). Stack views after V1 |
| Q5 | H1: should an Auto-on watch that ends with the lid open send a bot message? | No. Message only when the lid was confirmed closed, or the watch was turned on by hand |
| Q6 | H6: switch local banners to the system notification API (asks permission once, shows as Agrypnos)? | Yes |
| Q7 | M1: should new installs default How long to Agents? | Yes |

---

## Fix status (branch `v1-release-fixes`)

| Item | Status |
|---|---|
| B1 | Your call: no code change. Idle-wait help, README, and `AGENTS.md` now name the long-reply limit and say to raise the wait |
| B2 | Fixed. Plugin bundled again; `build-macos.sh` fails on a missing runtime resource |
| B3 | Fixed. 1.18.32 and newer accepted; status line names the version. Native end-to-end test passes on 1.18.34. Live bot check on 1.18.34 still yours |
| B4 | On hold until you have checked the app on your Mac |
| H1 | Fixed: an Auto-on watch ending with the lid open sends no bot message |
| H2 | Fixed: "Codex: alerts off." |
| H3 | Fixed: cards fit their measured text; switches on the title row |
| H4 | Fixed: "User id" caption, fields full width again |
| H5 | Fixed: `ungrant.sh` clears the hold first; README Uninstall section |
| H6 | Fixed: UserNotifications banners, permission asked once at launch |
| M1 | Fixed: new installs start on Agents |
| M2 | Copy fixed, password dialog gets 5 minutes. The app still waits on the dialog synchronously |
| M3 | How long hints shortened. The "Watch-end POST" title is unchanged (the README, bot guide, and agent bar all use it) |
| M4, M10 | Not done (cosmetic) |
| M5 | Header eye uses the mode color. The Keep awake card tint is unchanged |
| M6, M8 | Fixed |
| M7 | Stray key dropped. A prefs decode failure still resets to defaults |
| M9 | 1 of 5 fixed. The other 4 are in the Telegram and Discord pollers, left alone because they can't be live-tested here |
| T1 | macOS CI job added |
| T2 | Passes on 1.18.34 |
| Ponytail cuts | Not done, after the release as planned |

Found while fixing: the Xcode app target compiles `MenuBar/` and the package tests don't, so a missing import in the popover passed `swift test` and failed only the app build. The new CI job builds the app on every push.
