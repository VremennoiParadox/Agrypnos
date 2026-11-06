import AppKit
import QuartzCore

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension PopoverController {
    func addAutoArmCard(_ card: CardView, contentW: CGFloat, ci: CGFloat, cw: CGFloat, swW: CGFloat, swH: CGFloat) {
        addRainbowFill(to: card)
        addPrefTitle(AgrypnosCopy.autoArm, in: card, ci: ci, width: cw)
        _ = PopoverForm.help(
            AgrypnosCopy.autoArmHelp,
            in: card,
            y: CGFloat(PopoverStackLayout.prefHelpY),
            x: ci,
            width: cw,
            lines: PopoverCopyLayout.autoArmHelpMaxLines
        )
        autoArmSwitch = PopoverForm.switchControl(
            in: card,
            y: CGFloat(PopoverStackLayout.autoArmControlY),
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

    /// Soft rainbow under the card's labels so Auto-on stands out. Text stays on the card's usual colors.
    private func addRainbowFill(to card: CardView) {
        let gradient = CAGradientLayer()
        gradient.colors = [NSColor.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple]
            .map { $0.withAlphaComponent(0.3).cgColor }
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = card.bounds
        gradient.cornerRadius = 11
        gradient.cornerCurve = .continuous
        gradient.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        card.layer?.insertSublayer(gradient, at: 0)
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
