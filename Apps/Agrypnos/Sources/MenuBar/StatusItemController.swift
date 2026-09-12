import AppKit
import QuartzCore

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

@MainActor
final class StatusItemController: NSObject {
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
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = item.button {
            button.image = offGlyph
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
            tooltip = battery.onBatteryDischarging ? AgrypnosCopy.menuTooltipArmed : AgrypnosCopy.menuTooltipOn
            if runtime.preferences.duration == .untilAgentsSettle, runtime.engine.settle.sawBusy {
                glyph = busyGlyph
            }
        }
        if let button = item.button, button.image !== glyph {
            button.image = glyph
            pulse(button)
        }
        item.button?.toolTip = tooltip
        popover.refresh()
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
