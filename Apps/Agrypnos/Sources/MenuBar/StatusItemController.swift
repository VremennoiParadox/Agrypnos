import AppKit
import QuartzCore

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

@MainActor
final class StatusItemController: NSObject {
    static let autosaveName = "Agrypnos"

    private let item: NSStatusItem
    private let runtime: WatchRuntime
    private let popover: PopoverController
    private let offGlyph = GlyphFactory.image(.off)
    private let onGlyph = GlyphFactory.image(.on)
    private let armedGlyph = GlyphFactory.image(.armed)
    private let busyGlyph = GlyphFactory.image(.busy)

    init(runtime: WatchRuntime, popover: PopoverController) {
        self.runtime = runtime
        self.popover = popover
        // Notch Macs clip extras that land near the camera. Register a trailing
        // preferred position before creating the item so SystemUIServer parks us
        // with Wi‑Fi/Battery instead of under the notch.
        UserDefaults.standard.register(defaults: [
            "NSStatusItem Preferred Position \(Self.autosaveName)": 9999,
            "NSStatusItem Visible \(Self.autosaveName)": true
        ])
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = Self.autosaveName
        item.isVisible = true
        super.init()
        if let button = item.button {
            button.image = offGlyph
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.setAccessibilityTitle(AgrypnosCopy.appName)
            button.target = self
            button.action = #selector(clicked)
        }
        refresh()
    }

    @objc private func clicked() {
        guard let button = item.button else { return }
        popover.toggle(relativeTo: button)
    }

    func refresh() {
        let on = runtime.engaged
        let battery = BatteryMonitor.reading()
        var glyph = offGlyph
        var tooltip = AgrypnosCopy.menuTooltipOff
        if on {
            glyph = battery.onBatteryDischarging ? armedGlyph : onGlyph
            tooltip = AgrypnosCopy.menuTooltip(
                engaged: true,
                leftover: runtime.adoptedLeftover,
                onBattery: battery.onBatteryDischarging,
                lidClosed: runtime.engine.lidClosed
            )
            if runtime.preferences.duration == .untilAgentsSettle,
               runtime.engine.settle.sawBusy,
               let last = runtime.engine.settle.lastBusyAt,
               Date().timeIntervalSince(last) < runtime.preferences.agentSettleGrace
            {
                glyph = busyGlyph
            }
        }
        let chrome = StatusItemChrome.make(
            state: runtime.statusItemState,
            remainingSeconds: runtime.engine.statusItemRemainingSeconds(now: Date())
        )
        if let button = item.button {
            if button.image !== glyph {
                button.image = glyph
                pulse(button)
            }
            apply(chrome, to: button)
        }
        item.button?.toolTip = tooltip
        popover.refresh()
    }

    private func apply(_ chrome: StatusItemChrome, to button: NSButton) {
        button.title = chrome.title
        button.setAccessibilityTitle(chrome.accessibilityTitle)
        switch chrome.imagePosition {
        case .imageOnly:
            button.imagePosition = .imageOnly
            button.imageHugsTitle = false
        case .imageLeading:
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
        }
        switch chrome.length {
        case .square:
            item.length = NSStatusItem.squareLength
        case .variable:
            item.length = NSStatusItem.variableLength
        }
    }

    private func pulse(_ button: NSButton) {
        button.wantsLayer = true
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.35
        animation.toValue = 1
        animation.duration = 0.28
        button.layer?.add(animation, forKey: "watchPulse")
    }
}
