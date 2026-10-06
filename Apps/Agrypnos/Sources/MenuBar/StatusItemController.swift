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
    private var displayedGlyph = AgrypnosGlyph.off
    private var displayedColor = NSColor.secondaryLabelColor
    private var displayedAppearance: NSAppearance.Name?

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
            button.wantsLayer = true
            button.image = GlyphFactory.image(.off, color: displayedColor)
            displayedAppearance = button.effectiveAppearance.name
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
        let battery = runtime.lastBatteryReading
        var glyph = AgrypnosGlyph.off
        var tooltip = AgrypnosCopy.menuTooltipOff
        if on {
            glyph = (battery?.onBatteryDischarging ?? false) ? .armed : .on
            tooltip = AgrypnosCopy.menuTooltip(
                engaged: true,
                leftover: runtime.adoptedLeftover,
                onBattery: battery?.onBatteryDischarging ?? false,
                lidClosed: runtime.engine.lidClosed,
                panelPowerMode: runtime.preferences.panelPowerMode
            )
            if runtime.preferences.duration == .untilAgentsSettle,
               runtime.engine.settle.sawBusy,
               let last = runtime.engine.settle.lastBusyAt,
               Date().timeIntervalSince(last) < runtime.preferences.agentSettleGrace
            {
                glyph = .busy
            }
        }
        let chrome = StatusItemChrome.make(
            state: runtime.statusItemState,
            remainingSeconds: runtime.engine.statusItemRemainingSeconds(now: Date())
        )
        if let button = item.button {
            let color: NSColor
            if !on { color = .secondaryLabelColor }
            else if runtime.preferences.duration == .indefinite { color = .systemBlue }
            else if runtime.preferences.duration == .untilAgentsSettle { color = .systemPurple }
            else { color = AgrypnosPalette.gold }
            let appearance = button.effectiveAppearance.name
            if glyph != displayedGlyph || color != displayedColor || appearance != displayedAppearance {
                button.image = GlyphFactory.image(glyph, color: color)
                displayedGlyph = glyph
                displayedColor = color
                displayedAppearance = appearance
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
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.35
        animation.toValue = 1
        animation.duration = 0.28
        button.layer?.add(animation, forKey: "watchPulse")
    }
}
