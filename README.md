# Agrypnos

Native Swift menu-bar extra for macOS. Keep the Mac awake with the lid closed while coding agents work, then let it sleep when the watch ends. Greek *agrypnos*: sleepless.

MIT. No telemetry. No stealth network.

## What it does

- **Keep the watch** — ON = armed while the lid is open. The machine may already be held awake (`pmset disablesleep`). The display stays usable; Agrypnos does **not** blank the panel, call `displaysleepnow`, or turn the keyboard backlight off on that toggle.
- **Lid close** — with the watch armed, sleep is blocked via `pmset disablesleep`. Brightness drops to the **floor %** you set (default 15%, range 1–40; never 0%). Keyboard backlight off. Brightness write only — not `displaysleepnow`, not display sleep, not “screen off”.
- **Lid open mid-watch** — brightness ramps back over **1 / 2 / 3 seconds** (default 2s). Keyboard backlight on.
- **Hold until end** — timer (`∞` / `1h` / `3h` / custom minutes) or Agents mode (busy → stay; settled idle after **idle wait** → allow sleep).
- **Safety** — low battery (slider 5–100%, default 15%), thermal auto-off on `.serious` / `.critical` (Power toggle, default on), reboot clears SleepDisabled, launch-at-login never re-arms.

V1 agents: Cursor, Claude Code, Codex. Local heuristics (process list + session-file mtimes). Correctness over coverage.

## Not this product

- Not an App Store sandbox build (V1).
- Not a watt-marketing page. We do not publish numbers we did not measure.
- Not a promise to detect every agent provider.
- Does **not** kill Wi-Fi or Bluetooth (out of scope unless a later spec says otherwise).
- Does **not** force the display asleep when you arm Keep the watch.

## Privileged work

One-time scoped sudoers grant for **exactly two** `pmset disablesleep` commands. `visudo -c` before install. See [SECURITY.md](SECURITY.md).

## Repo layout

| Path | Role |
|---|---|
| `Sources/AgrypnosCore/` | Portable logic. Linux-testable. No AppKit. |
| `Tests/AgrypnosCoreTests/` | Heuristics, timers, state machine. |
| `Apps/Agrypnos/` | macOS menu-bar extra. AppKit + IOKit. Needs a Mac. |
| `Scripts/` | `verify-linux.sh`, `check-file-sizes.sh`, Mac `build.sh` |
| `prd/` | Product scope. |

`AgrypnosCore` decides. Mac adapters execute (`pmset`, IOKit, `NSStatusItem`, Carbon hotkey, lid events).

## Build

**Linux (Core tests):**

```bash
swift test
./Scripts/verify-linux.sh
```

**macOS (app):**

```bash
./Scripts/build.sh
```

Needs a Mac to run the menu-bar extra. Until someone arms Keep the watch with the lid **open** (screen stays usable), closes the lid (brightness floor + keyboard dark), reopens mid-watch (ramp from prefs + keyboard on), and confirms timer/Agents end allows sleep, do not claim that path is proven.

Until someone proves **Low Power Mode** while the watch is armed (lid open and lid closed) and confirms the Mac stays awake, do not claim LPM cannot force a watch. Until someone proves **lid-closed auto-off** (timer, Agents settle, battery, thermal) **requests sleep** with the lid still closed, do not claim that path.

Until someone proves a **wedge** (clamshell + power + external display, or a sleep assertion Agrypnos did not take) and confirms `pmset disablesleep` is not enough under a closed lid, do not claim Agents detection plus drop-keep-awake is the whole closed-lid story.

## V1 settings (popover only)

These exist in the menu-bar popover. There is no separate settings window. A slim text switcher at the top shows one section at a time. **Watch** · **Power** · **Agents** · **General**. The popover opens on Watch.

- **Watch:** Keep the watch, duration presets plus custom minutes, arming caption
- **Power:** brightness floor % (default **15%**; range 1–40; never 0%), keyboard backlight off, low-battery auto-off **5–100%** (default 15%), brightness return when the lid opens **1 / 2 / 3 s** (default **2s**), thermal auto-off (default on)
- **Agents:** idle wait after agents go quiet (15s–15m, default 90s) before allowing sleep
- **General:** remappable global hotkey (default `⌥⌘A`), launch at login, quit

Still locked until after Mac prove: status-item remaining time, per-tool Agents include list.

## Honesty

- Armed ≠ black screen.
- IOKit assertions do not survive lid close; `pmset disablesleep` is the lid story.
- Reboot clears SleepDisabled. That is a feature.
- Launch-at-login never re-arms the watch.

## License

MIT. See [LICENSE](LICENSE).
