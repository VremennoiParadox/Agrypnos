import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension PopoverController {
    func applySection(_ section: PopoverSection) {
        currentSection = section
        let layout = PopoverStackLayout.make(section: section)
        let pad = CGFloat(PopoverStackLayout.pad)
        let width = CGFloat(PopoverStackLayout.width)
        let contentW = width - pad * 2
        sectionControl?.selectedSegment = section.rawValue
        sectionControl?.frame = NSRect(
            x: pad,
            y: CGFloat(layout.sectionSwitcher.y),
            width: contentW,
            height: CGFloat(layout.sectionSwitcher.height)
        )

        PopoverForm.apply(watchCard, slot: layout.watch, pad: pad, width: contentW)
        PopoverForm.apply(durationCard, slot: layout.duration, pad: pad, width: contentW)
        PopoverForm.apply(lastWatchEndCard, slot: layout.lastWatchEnd, pad: pad, width: contentW)
        PopoverForm.apply(hygieneCard, slot: layout.hygiene, pad: pad, width: contentW)
        PopoverForm.apply(batteryCard, slot: layout.battery, pad: pad, width: contentW)
        PopoverForm.apply(agentIncludeCard, slot: layout.agentInclude, pad: pad, width: contentW)
        PopoverForm.apply(settleCard, slot: layout.settle, pad: pad, width: contentW)
        PopoverForm.apply(rampCard, slot: layout.ramp, pad: pad, width: contentW)
        PopoverForm.apply(thermalCard, slot: layout.thermal, pad: pad, width: contentW)
        PopoverForm.apply(notifEnableCard, slot: layout.notifEnable, pad: pad, width: contentW)
        PopoverForm.apply(notifDiscordCard, slot: layout.notifDiscord, pad: pad, width: contentW)
        PopoverForm.apply(notifTelegramCard, slot: layout.notifTelegram, pad: pad, width: contentW)
        PopoverForm.apply(notifSetupCard, slot: layout.notifSetup, pad: pad, width: contentW)
        PopoverForm.apply(notifClearCard, slot: layout.notifClear, pad: pad, width: contentW)
        PopoverForm.apply(loginCard, slot: layout.login, pad: pad, width: contentW)

        applyGeneralChrome(layout, pad: pad, contentW: contentW)

        popoverDocument.frame.size.height = CGFloat(layout.contentHeight)
        let popH = CGFloat(layout.popoverHeight)
        popoverRoot.frame.size.height = popH
        popoverScroll.frame = popoverRoot.bounds
        popover.contentSize = NSSize(width: width, height: popH)
        popoverScroll.documentView?.scroll(.zero)
    }

    private func applyGeneralChrome(_ layout: PopoverStackLayout, pad: CGFloat, contentW: CGFloat) {
        if let y = layout.shortcutY, let hint = layout.hotkeyHint {
            shortcutLabel.isHidden = false
            shortcutLabel.frame.origin.y = CGFloat(y)
            recorder.button.isHidden = false
            hotkeyButtonY = CGFloat(y)
            layoutHotkeyButton()
            hotkeyHint.isHidden = false
            hotkeyHint.frame = NSRect(
                x: pad,
                y: CGFloat(hint.y),
                width: contentW,
                height: CGFloat(hint.height)
            )
        } else {
            shortcutLabel.isHidden = true
            recorder.button.isHidden = true
            hotkeyHint.isHidden = true
        }

        if let y = layout.quitY {
            quitButton.isHidden = false
            quitButton.frame.origin.y = CGFloat(y)
        } else {
            quitButton.isHidden = true
        }
    }
}
