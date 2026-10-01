# One-button OpenCode forwarding verification

Date: 2026-10-01. Branch: `codex/agent-question-relay`. Host: macOS, OpenCode **1.18.32**.

## Delivered behavior

After setting up their own inbound bot and answering user ID, the user selects OpenCode in Agents and clicks **Enable OpenCode forwarding** in Notif. Setup installs `configRoot/agrypnos-opencode.js`, registers its file URL in global `tui.json`, and enables forwarding. Restart OpenCode once to load the terminal plugin, then use normal interactive chats across projects without entering a server address, directory, port or password.

Installation shows waiting; only an authenticated 1.18.32 terminal increments the connected count. Disable leaves an inactive plugin. Remove deletes its registration and unchanged receipt-owned file. Bot secrets and manual HTTP settings are retained. Edited/foreign files, symlinks and unsupported `tui.json` content fail visibly. `tui.jsonc` stays byte-for-byte unchanged. The app and terminal must use the same global config root; a shell-only custom XDG root is not discoverable from an unrelated app process.

The plugin receives no bot credentials. The bridge uses same-UID Unix sockets, a random token and fresh lifecycle generation; its private directories are 0700 and files/socket 0600. There is no polling heartbeat. Native question text is sent only through the existing opted-in bot relay. A compromised same-user process remains outside this local token boundary.

## Automated evidence

- Installer and legacy migration: idempotent install, preserved other settings/JSONC, modified-file and symlink refusal, each injected write failure rolling back owned artifacts, private modes, removal and default-off migration.
- IPC: fragmented/coalesced Unicode frames, strict schemas/UTF-8/size bounds, actual temporary sockets, wrong credentials, duplicate hello, incomplete-handshake timeout, stopped-send failure and preserved existing file. Same-UID enforcement is implemented with Darwin `getpeereid`; cross-user live execution was not attempted.
- Source/plugin: native identity collisions across instances, ordered label mapping, local winner, resolution before acknowledgment, lost/spoofed acknowledgment, no duplicate native submission, unchanged reconnect deadline, unknown snapshot replay remaining local, disabled/offline behavior, disposal, return-local, ownership/label rejection and oversized frames.
- Runtime/layout: prerequisites, no arming/power commands during enable, real waiting state, listener/token revocation, install cancellation/double click, fresh sleep generation, safe removal, long config roots with short private sockets, collapsed manual form and active document sizing. Existing HTTP, bot/coordinator and timeout tests are retained.
- **Production native smoke passed:** `OpenCodePluginNativeTests.testProductionPluginRepliesThroughRealSocketToOriginalOpenCodeChat` runs actual OpenCode 1.18.32 ordinary TUI startup against a deterministic local model fixture. The production JS helper and actual Swift codec/socket/source submit B through the public native SDK. Its acknowledgment is accepted, the original session continues with a unique B marker exactly once, and disposal runs. The wrapper supplies an isolated manifest path; no global user config or bot is used. It does not simulate the native question registry, SDK, events or conversation. This is automated native evidence, separate from a human bot/Mac test.
- Task 1 independently proved two simultaneous native processes/projects, a supported native local winner and local prompt availability with absent IPC. The local-winner probe used the supported native API, not a physical keyboard click.

Commands:

```sh
swift test --disable-sandbox
node --test Tests/OpenCodePlugin/question-plugin.test.mjs
xcodebuild -project Apps/Agrypnos/Agrypnos.xcodeproj -scheme Agrypnos -configuration Debug -derivedDataPath /private/tmp/agrypnos-one-button-debug CODE_SIGN_IDENTITY=- build
xcodebuild -project Apps/Agrypnos/Agrypnos.xcodeproj -scheme Agrypnos -configuration Release -derivedDataPath /private/tmp/agrypnos-one-button-release CODE_SIGN_IDENTITY=- build
codesign --verify --deep --strict /private/tmp/agrypnos-one-button-debug/Build/Products/Debug/Agrypnos.app
codesign --verify --deep --strict /private/tmp/agrypnos-one-button-release/Build/Products/Release/Agrypnos.app
```

Swift module caches were redirected to private temporary paths. Socket/native tests require permission for temporary local sockets. Bundle resources were compared byte-for-byte with source. Final automated verification: **761 Swift tests, 0 failures; 9 JavaScript tests, 0 failures**. Debug and Release builds succeeded; both exact bundles passed signature verification and resource byte comparison. Relevant tracked/new files are at most 600 lines and `git diff --check` passed. Feature commit: `33c2006`, installer `4d8eb02`, IPC `bc1c778`; native feasibility `5a26ef7`. Build paths are the commands above; fresh review disposition follows below.

## Live evidence remains separate

| Check | Result |
|---|---|
| Prior original-chat HTTP/Telegram round trip | Human-confirmed in the handoff; preserved, not plugin proof |
| New one-button install in the user's global config | Not tested; no global user config changed |
| New production plugin → real Telegram bot → original chat | Not tested |
| New production plugin → real Discord bot → original chat | Not tested |
| Two human chats/processes with physical local answer and competing bots | Not tested; automated native/source characterization only |
| App/provider restart, lock, sleep/wake and 600-second policy on the user's Mac | Not tested for this plugin; automated lifecycle/timeout tests only |
| Notif optical, Reduce Motion, confirmed-lid Power A/B and safety | Not tested for this plugin; existing proof stays separately scoped |
| Forwarding off/on with matched workload/display/bots, energy or watts | Not measured; no energy claim |
| Headless or desktop OpenCode; other provider question forwarding | Unverified/unavailable; full-provider release remains gated |

The built app is concrete and reviewable. Live validation requires the user's existing bot and a one-time global installation; implementation authorization has not been treated as permission to send real bot messages or change those live files.
