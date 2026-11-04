# Agrypnos public release readiness

Audit date: 2026-10-11. Target: a downloadable macOS app, preferably a GitHub release. This is an investigation, not authorization to publish. Source inspected in the working copy on `discord-bot-outbound`; initial HEAD `6d917b4`, subsequently `033d0e4` for the separate Grok-rule removal, with substantial existing uncommitted app, question-relay, UI and documentation changes. The main agent restarted the local app separately; that is not a public distribution check.

**Recommendation: prepare a signed public beta after packaging and candidate acceptance; do not describe the present build as a finished distribution release.** The user confirmed the previously outstanding live checks on 2026-10-11: Agents settle, safety auto-off, Discord inbound/outbound, I2 user-off sleep, I3 terminal preference, Claude same-session forwarding, Codex ChatGPT-app waiting alerts, and timer physical sleep/bot delivery. These checks are passed, as recorded in [AGENTS.md](/Users/imightbeoufu/Developer/Agrypnos/AGENTS.md:209). This confirmation does not supply build/hardware/OS details or establish signing, notarization, a clean download install, or the additional recovery matrix below. Remaining work is release packaging, acceptance of that artifact, and resolving the promised scope.

## What is verified now

| Evidence | Result and limit |
|---|---|
| Inspected `dist/Agrypnos.app` | Version **0.1.0 (1)**, bundle ID `app.agrypnos.Agrypnos`, minimum macOS **14.0**, menu-bar app, **arm64 + x86_64** binary. Architecture presence is not hardware compatibility proof. |
| Actual signature | `codesign -dvvv` reports **ad-hoc**, hardened runtime enabled, **no TeamIdentifier**. `codesign --verify --deep --strict` passes locally; that is not Developer ID or Gatekeeper distribution approval. |
| Actual entitlements | `com.apple.security.app-sandbox=false` and **`com.apple.security.get-task-allow=true`**. The latter must be absent/false in a notarized distribution. The source entitlement file alone does not reveal this injected entitlement. |
| Stapled ticket | An unrestricted read-only `xcrun stapler validate` reports **no ticket stapled**. Together with ad-hoc signing, this build is not the notarized download to ship. |
| Available signing identities | Unrestricted `security find-identity -v -p codesigning` lists Apple Development/Apple Distribution identities, **no Developer ID Application identity**. This does not prove the developer account cannot create one. |
| GitHub | API returned **zero releases**. Local `git tag --list` was empty. Hosted main is `6ac0043`, earlier than the local fixes; the local running build is not automatically what a public source checkout downloads. |
| Latest hosted main CI | [Run 37599279106](https://github.com/VremennoiParadox/Agrypnos/actions/runs/37599279106): **691 tests passed**, then the job failed because a Claude relay plan has **1499 lines**, exceeding the 600-line cap. |
| Recent local verification | The main agent reports **804 tests passed with `OpenCodePluginNativeTests` excluded**, plus a successful Release build. The native production OpenCode round-trip timed out on both the baseline and fixed branch. This audit did not rerun tests or build. A skip is not proof of that integration. |
| Prior user-observed checks | The [project bar](/Users/imightbeoufu/Developer/Agrypnos/AGENTS.md) records Dim/Sleep panel behavior, open-lid brightness, Telegram commands/status, Agents selection and OpenCode activity checks. [OpenCode one-button forwarding](/Users/imightbeoufu/Developer/Agrypnos/docs/reviews/2026-10-01-opencode-one-button-verification.md:35) was user-confirmed on 2026-10-01; individual bot channels, races and the complete lifecycle matrix were not separately established. These are prior builds, not fresh acceptance of the candidate download. |

The current [build script](/Users/imightbeoufu/Developer/Agrypnos/Scripts/build-macos.sh:15) forces `CODE_SIGN_IDENTITY="-"` and copies an app into `dist`. It has no archive/export, ZIP/DMG, notarization, stapling or release-upload stage. The [workflow](/Users/imightbeoufu/Developer/Agrypnos/.github/workflows/core.yml:7) only runs Linux Core tests and the file-size check; it neither builds the Mac app nor runs the native integrations. [Version/signing defaults](/Users/imightbeoufu/Developer/Agrypnos/Scripts/generate-xcodeproj.py:248) are also generated, so editing only the Xcode project can be overwritten.

## Release blockers, in practical order

### 1. Agree what the release promises

The [native-question design](/Users/imightbeoufu/Developer/Agrypnos/docs/superpowers/specs/2026-09-29-native-agent-questions-design.md:13) still requires all four providers before release; the [project bar](/Users/imightbeoufu/Developer/Agrypnos/AGENTS.md) says the full four-provider release remains gated. Current delivery is narrower:

- **Activity watching:** Cursor, Claude Code, Codex and OpenCode, using local heuristics. This is separate from forwarding questions.
- **OpenCode questions:** user-confirmed for OpenCode 1.18.32 on one previous build; fresh candidate/native fixture and recovery acceptance remain open.
- **Claude Code questions:** same-session Mac forwarding check passed (user-confirmed, 2026-10-11).
- **Codex:** waiting alerts passed the ChatGPT-app check (user-confirmed, 2026-10-11); they do not answer questions remotely.
- **Cursor:** no question forwarding and no waiting alert.

Choose explicitly between meeting that older all-provider requirement and revising the release scope to the supported watch app with clearly labelled, optional BETA integrations. Labelling a release “beta” alone does not silently repeal the project requirement. Do not promise four-tool remote answering. Current limitations are stated in [README](/Users/imightbeoufu/Developer/Agrypnos/README.md:251).

### 2. Freeze an identifiable source candidate and get its checks green

Review and commit the intended existing changes rather than releasing from an undocumented dirty checkout. Keep build products and the CodeGraph database out of the source release. [`.gitignore`](/Users/imightbeoufu/Developer/Agrypnos/.gitignore:1) currently does not exclude `dist/`, `.derivedData/` or `.codegraph/`; the [size checker](/Users/imightbeoufu/Developer/Agrypnos/Scripts/check-file-sizes.sh:17) includes untracked non-ignored files.

Fix the existing size-cap failures without discarding their content: the tracked [Claude relay plan](/Users/imightbeoufu/Developer/Agrypnos/docs/superpowers/plans/2026-10-01-claude-question-relay.md) is 1499 lines; the current dirty [PopoverSettingsChromeTests.swift](/Users/imightbeoufu/Developer/Agrypnos/Tests/AgrypnosCoreTests/PopoverSettingsChromeTests.swift) is 602 lines. Then run the required Core/Linux checks, Mac suite, plugin tests and candidate Release build. Diagnose the native OpenCode fixture timeout, or explicitly exclude that feature from the supported release claims and document the accepted limitation; do not call the full integration suite green while skipping it. A fresh review should cover the release candidate, including the existing Discord/question/UI edits, not only the small CPU fix.

Set a release version/build consistently in [Info.plist](/Users/imightbeoufu/Developer/Agrypnos/Apps/Agrypnos/Resources/Info.plist:19), the Xcode project and its generator. Record the exact commit and artifact checksum. No need to force version 1.0; an honest 0.x beta is appropriate.

### 3. Produce a distribution build that users can open normally

For the recommended outside-App-Store route:

1. Obtain a **Developer ID Application** signing identity from the intended Apple Developer Program team. Existing Apple Development/Apple Distribution identities are different certificate types. Individual enrollment requires legal age of majority; confirm the actual authorized account holder rather than assuming eligibility. [Apple Developer ID](https://developer.apple.com/developer-id/), [enrollment requirements](https://developer.apple.com/programs/enroll/).
2. Archive/export with that identity, keep hardened runtime enabled, include a secure timestamp, and ensure the **actual final executable** has no `get-task-allow=true`. Sign every executable being shipped. Apple's standard archive/export strips that debugging entitlement; a custom distribution build can use `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`, followed by verification of the signed artifact. [Apple notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [Apple entitlement and timestamp guidance](https://developer.apple.com/documentation/security/resolving-common-notarization-issues).
3. Submit a ZIP or DMG using Xcode's Developer ID distribution flow or `notarytool`; inspect the accepted notary result and log. Staple the ticket to the app/DMG. For ZIP distribution, staple the app and then create the final ZIP; a ZIP itself cannot be stapled. [Apple custom workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
4. Verify signatures and ticket, then download the final artifact through a browser onto a clean Mac/account and test its quarantined first launch, including offline launch with the stapled ticket. Opening a locally built unquarantined app does not exercise the customer path.

A simple ZIP/DMG with the app, license and installation notes is sufficient. A PKG installer or fully automated notarization pipeline is optional for the first release. The project currently parks the notarization *pipeline*; a manual archive/export remains possible. Do not teach customers to disable Gatekeeper as the normal installation path.

### 4. Verify the packaged candidate and remaining recovery cases

The previously outstanding live checks are now user-confirmed; do not continue listing them as untested. The matrix below describes acceptance of the eventual signed download and additional recovery/compatibility cases, rather than revoking those results. Record build, Mac model, macOS version, power source, panel mode, provider/version, relevant settings, commands/log evidence and the human-observed outcome. Tests prove requested commands; actual sleep needs a physical observation/power log.

| Check | Required outcome |
|---|---|
| Open-lid arm/disarm; rapid lid close/reopen | No surprise dim/blank/keyboard-off while open; unconfirmed close applies neither panel hygiene nor manual forced sleep. |
| Confirmed closed, **Dim** and **Sleep panel** | Agent continues working; Dim only writes the floor, Sleep panel only sleeps the display. Reopen restores captured brightness/keyboard appropriately; end-watch with lid open leaves the display usable. |
| Manual/hotkey off, timer, Agents settle | **Passed, user-confirmed 2026-10-11:** I2 user-off sleep, Agents settle/disarm, timer physical sleep and bot delivery. Verify these outcomes on the packaged candidate; duration survives reopen/disarm and bot delivery cannot indefinitely delay release. |
| Each advertised activity tool; selected/unselected tools | **I3 terminal preference passed, user-confirmed 2026-10-11.** Candidate checks: busy holds the watch; cessation settles; excluded tools do not hold it; Cursor nested subagents count. Terminal activity follows the default-off preference. A never-busy Agents arm intentionally stays on. |
| Disconnect/stall reproduction | Cursor loses connectivity with Codex desktop open: stale writes plus desktop UI CPU must not hold wake through the fixed path. Include a quiet cloud response longer than the idle grace and document possible false-idle behavior. The existing [CPU fix report](/Users/imightbeoufu/Developer/Agrypnos/docs/reviews/2026-10-11-codex-desktop-cpu-fix.md) proves the defect, not the exact historical overnight cause. |
| Battery/thermal/LPM | **Safety auto-off sleep passed, user-confirmed 2026-10-11.** For candidate/recovery checks, use a battery threshold above current charge without deliberately exhausting the battery. Retain deterministic thermal failure tests; do not manufacture dangerous heat. Verify deliberate-watch LPM behavior and leftover wake-hold cleanup. |
| Quit, force quit/crash, restart, login/reboot | Normal quit and the crash guard clear `SleepDisabled`; immediate relaunch/second instance does not strand the hold. Login/reboot does not re-arm. Test auth cancellation, missing/removed grant and failed release honestly. |
| Optional Telegram/Discord | **Discord inbound commands/outbound bot messages passed, user-confirmed 2026-10-11.** Candidate checks retain opt-out, destination allowlist, disarm lid gates, one message per scoped event, and no stale `/arm` replay after offline/sleep. |
| Optional question features | **Claude same-session forwarding and Codex ChatGPT-app waiting alerts passed, user-confirmed 2026-10-11.** Additional recovery cases: two sessions, local answer vs remote click, unauthorized/stale click, disconnect, restart and sleep/wake; unanswered deadline must not override manual/battery/thermal safety. Codex alerts remain alerts only; Cursor has no question forwarding or waiting alert. The observed native fixture timeout still needs resolution. |

Add one controlled long closed-lid run after the focused checks, on battery with the normal safety threshold, including an intentional connection interruption. Record consumption rather than claiming watt savings. Test macOS 14 and both Intel/Apple Silicon if both are advertised; otherwise narrow the supported/tested combinations visibly. Private [DisplayServices brightness symbols](/Users/imightbeoufu/Developer/Agrypnos/Apps/Agrypnos/Sources/Power/BrightnessFloorController.swift:64) make OS/hardware compatibility checks particularly important.

### 5. Make installation, removal and limitations accurate

- Replace the build-only [Install section](/Users/imightbeoufu/Developer/Agrypnos/README.md:45) with download → move to `/Applications` → open → grant explanation. Setup should use the bundled [grant script](/Users/imightbeoufu/Developer/Agrypnos/Apps/Agrypnos/Sources/Support/GrantAndNotify.swift:26), not depend on a cloned repository or Xcode. Test cancellation and reinstall on a fresh account.
- Enable Claude/Codex integrations **after the app is in its final location**. Setup stores the executable's absolute path ([Claude](/Users/imightbeoufu/Developer/Agrypnos/Apps/Agrypnos/Sources/Questions/WatchRuntime+ClaudeHook.swift:57), [Codex](/Users/imightbeoufu/Developer/Agrypnos/Apps/Agrypnos/Sources/Questions/WatchRuntime+CodexAlert.swift:59)); moving/deleting the app can leave stale hooks. Test update/replacement and integration removal without touching foreign hooks.
- Ship complete uninstall instructions: disable/remove integrations, disable login, clear secrets if desired, turn the watch off and quit, **verify `SleepDisabled=0` before removing the sudoers rule**, then remove app/data. [ungrant.sh](/Users/imightbeoufu/Developer/Agrypnos/Scripts/ungrant.sh:7) currently deletes permission without clearing wake first; deleting it during an armed watch can prevent the [crash helper](/Users/imightbeoufu/Developer/Agrypnos/Apps/Agrypnos/Sources/Power/SleepDisabledController.swift:39) from clearing the hold. Provide `sudo /usr/bin/pmset -a disablesleep 0` as a recovery command, not merely “delete the app.” Bundle an ungrant tool or document exact removal commands for users without the repo.
- Reconcile stale claims: [PRD](/Users/imightbeoufu/Developer/Agrypnos/prd/v1-scope.md:7) still demands display sleep generally and on engage; acceptance still lists only three tools. [README](/Users/imightbeoufu/Developer/Agrypnos/README.md:273) says OpenCode live verification is pending despite the later human PASS. Preserve actual remaining channel/lifecycle limitations; do not simply mark everything verified. Say **requests sleep** where only command-level evidence exists.
- Keep the existing [security/privacy explanation](/Users/imightbeoufu/Developer/Agrypnos/SECURITY.md:22) accessible: local process/mtime watching, mode-0600 secrets, user-owned opt-in bots, question text sent only when enabled, and no telemetry. Provide a support/issue route and review documentation/screenshots for personal information before publication. No hosted privacy backend is required for this local-only architecture.
- Include the full MIT copyright/permission notice with the downloadable artifact. [LICENSE](/Users/imightbeoufu/Developer/Agrypnos/LICENSE:12) requires it; the inspected app resources currently contain assets and `grant.sh`, not the license. Review provenance of bundled screenshots/provider logos; no trademark/legal clearance is claimed by this audit.

### 6. Publish only the validated package

Once the candidate is fixed, signed and accepted, create the annotated `vX.Y.Z` tag matching the shipped version, attach the final ZIP/DMG and checksum to a GitHub release, and include install/uninstall steps, tested hardware/OS/providers, BETA limitations and known issues. A GitHub pre-release is appropriate for a public beta; attaching binaries is separate from GitHub's automatic source ZIP. [GitHub release instructions](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository). The project bar forbids tagging unreleased work. Nothing was tagged, uploaded or published in this audit.

## App Store is a separate project

The current app explicitly disables App Sandbox, invokes scoped privileged system commands and uses a private brightness framework. The Mac App Store requires sandboxing, and App Review 2.5.1 requires public APIs. This is a substantive compatibility redesign/review gate, not another certificate choice. Prefer Developer ID distribution for the current app. Successful macOS notarization is also not App Store approval. [Apple sandbox requirement](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox), [App Review Guidelines 2.4.5/2.5.1](https://developer.apple.com/app-store/review/guidelines/).

## Practical next slice

Freeze the intended branch changes, fix the file-size failures and clarify the beta scope. In parallel, obtain the Developer ID identity and prepare one signed/notarized candidate. Run the hardware matrix against that exact artifact, resolve any release-path failures, then package and publish it. New activity integrations, automatic updates, billing, an App Store build and measured watt marketing can remain outside this release.
