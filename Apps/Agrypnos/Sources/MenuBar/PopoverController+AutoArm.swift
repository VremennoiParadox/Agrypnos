import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension PopoverController {
    func addAutoArmCard(_ card: CardView, contentW: CGFloat, ci: CGFloat, cw: CGFloat, swW: CGFloat, swH: CGFloat) {
        addPrefTitle(AgrypnosCopy.autoArm, in: card, ci: ci, width: cw - swW - 8)
        addCollapsibleHelp(.autoArm, in: card, y: CGFloat(PopoverStackLayout.prefHelpY), ci: ci, cw: cw)
        autoArmSwitch = PopoverForm.switchControl(
            in: card,
            y: CGFloat(PopoverStackLayout.titleSwitchY),
            contentW: contentW,
            ci: ci,
            swW: swW,
            swH: swH,
            target: self,
            action: #selector(autoArmToggled(_:))
        )
        autoArmSwitch.setAccessibilityLabel(AgrypnosCopy.autoArm)
        autoArmSwitch.setAccessibilityHelp(AgrypnosCopy.autoArmHelp)
    }

    /// Auto-on only acts while How long is Agents, so the switch is live only then.
    func refreshAutoArm(_ runtime: WatchRuntime) {
        autoArmSwitch?.state = runtime.preferences.autoArmWhenBusy ? .on : .off
        autoArmSwitch?.isEnabled = runtime.preferences.duration == .untilAgentsSettle
    }

    @objc func autoArmToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        runtime?.setAutoArmWhenBusy(sender.state == .on)
        refresh()
    }
}
