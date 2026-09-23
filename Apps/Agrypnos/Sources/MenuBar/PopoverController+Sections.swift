import AppKit
import QuartzCore

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension PopoverController {
    func applySection(_ section: PopoverSection) {
        let motion = PopoverSectionResize.make(
            from: currentSection,
            to: section,
            animated: popover.isShown && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            currentHeight: Int(popover.contentSize.height.rounded()),
            currentContentHeight: Int(popoverDocument.frame.size.height.rounded())
        )
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

        applyCardSlots(layout, pad: pad, width: contentW, hideOutgoing: motion.hidesOutgoingImmediately)
        applyGeneralChrome(layout, pad: pad, contentW: contentW, hideIfAbsent: motion.hidesOutgoingImmediately)
        if motion.clipsOutgoingUntilComplete {
            bringSectionChromeToFront(section)
        }

        popoverDocument.frame.size.height = CGFloat(motion.documentHeightDuringMotion)
        popoverScroll.documentView?.scroll(.zero)

        if motion.animatesHeight {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = motion.durationSeconds
                context.allowsImplicitAnimation = motion.allowsImplicitAnimation
                if motion.timing == .easeInEaseOut {
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                }
                self.applyPopoverWindowHeight(layout.popoverHeight, width: width)
            }, completionHandler: { [weak self] in
                guard let self, self.currentSection == section else { return }
                self.applyCardSlots(layout, pad: pad, width: contentW, hideOutgoing: true)
                self.applyGeneralChrome(layout, pad: pad, contentW: contentW, hideIfAbsent: true)
                self.popoverDocument.frame.size.height = CGFloat(layout.contentHeight)
            })
        } else {
            applyPopoverWindowHeight(layout.popoverHeight, width: width)
        }
    }

    private func applyPopoverWindowHeight(_ height: Int, width: CGFloat) {
        let popH = CGFloat(height)
        popoverRoot.frame.size.height = popH
        popoverScroll.frame = popoverRoot.bounds
        popover.contentSize = NSSize(width: width, height: popH)
    }

    private func applyCardSlots(
        _ layout: PopoverStackLayout,
        pad: CGFloat,
        width: CGFloat,
        hideOutgoing: Bool
    ) {
        func apply(_ view: NSView, slot: PopoverSlot?) {
            if slot == nil, !hideOutgoing { return }
            PopoverForm.apply(view, slot: slot, pad: pad, width: width)
        }
        apply(watchCard, slot: layout.watch)
        apply(durationCard, slot: layout.duration)
        apply(lastWatchEndCard, slot: layout.lastWatchEnd)
        apply(hygieneCard, slot: layout.hygiene)
        apply(batteryCard, slot: layout.battery)
        apply(agentIncludeCard, slot: layout.agentInclude)
        apply(settleCard, slot: layout.settle)
        apply(rampCard, slot: layout.ramp)
        apply(thermalCard, slot: layout.thermal)
        apply(notifEnableCard, slot: layout.notifEnable)
        apply(notifDiscordCard, slot: layout.notifDiscord)
        apply(notifTelegramCard, slot: layout.notifTelegram)
        apply(notifSetupCard, slot: layout.notifSetup)
        apply(notifClearCard, slot: layout.notifClear)
        apply(loginCard, slot: layout.login)
    }

    private func applyGeneralChrome(
        _ layout: PopoverStackLayout,
        pad: CGFloat,
        contentW: CGFloat,
        hideIfAbsent: Bool
    ) {
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
        } else if hideIfAbsent {
            shortcutLabel.isHidden = true
            recorder.button.isHidden = true
            hotkeyHint.isHidden = true
        }

        if let y = layout.quitY {
            quitButton.isHidden = false
            quitButton.frame.origin.y = CGFloat(y)
        } else if hideIfAbsent {
            quitButton.isHidden = true
        }
    }

    private func bringSectionChromeToFront(_ section: PopoverSection) {
        for view in chrome(for: section) {
            view.superview?.addSubview(view)
        }
    }

    private func chrome(for section: PopoverSection) -> [NSView] {
        switch section {
        case .watch: return [watchCard, durationCard, lastWatchEndCard]
        case .power: return [hygieneCard, batteryCard, rampCard, thermalCard]
        case .agents: return [agentIncludeCard, settleCard]
        case .notif: return [notifEnableCard, notifDiscordCard, notifTelegramCard, notifSetupCard, notifClearCard]
        case .general: return [loginCard, shortcutLabel, recorder.button, hotkeyHint, quitButton]
        }
    }
}
