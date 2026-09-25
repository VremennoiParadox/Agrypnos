import AppKit
import QuartzCore

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension PopoverController {
    func applySection(_ section: PopoverSection) {
        sectionMotion += 1
        let token = sectionMotion
        let motion = PopoverSectionResize.make(
            from: currentSection,
            to: section,
            animated: popover.isShown && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            currentHeight: Int(popover.contentSize.height.rounded()),
            panelPowerMode: runtime?.preferences.panelPowerMode ?? .default
        )
        currentSection = section
        let layout = PopoverStackLayout.make(
            section: section,
            panelPowerMode: runtime?.preferences.panelPowerMode ?? .default
        )
        let pad = CGFloat(PopoverStackLayout.pad)
        let width = CGFloat(PopoverStackLayout.width)
        let contentW = width - pad * 2
        sectionControl?.selectedSegment = section.rawValue
        sectionControl?.autoresizingMask = []
        sectionControl?.frame = NSRect(
            x: pad,
            y: CGFloat(layout.sectionSwitcher.y),
            width: contentW,
            height: CGFloat(layout.sectionSwitcher.height)
        )

        // Cards swap now, outside the height ease, so two sections never double-paint
        // and NSAnimationContext cannot interpolate their frames.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            self.applyCardSlots(layout, pad: pad, width: contentW)
            self.applyGeneralChrome(layout, pad: pad, contentW: contentW)
            self.popoverDocument.frame.size.height = CGFloat(motion.documentHeightDuringMotion)
        }
        popoverScroll.documentView?.scroll(.zero)

        let popH = CGFloat(layout.popoverHeight)
        if motion.animatesHeight {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = motion.durationSeconds
                context.allowsImplicitAnimation = motion.allowsImplicitAnimation
                if motion.timing == .easeInEaseOut {
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                }
                // Only contentSize eases. Hosting frames follow via autoresizing —
                // animating NSScrollView.frame leaves the clip and document out of sync.
                self.popover.contentSize = NSSize(width: width, height: popH)
            }, completionHandler: { [weak self] in
                guard let self, self.sectionMotion == token else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0
                    context.allowsImplicitAnimation = false
                    self.applyCardSlots(layout, pad: pad, width: contentW)
                    self.applyGeneralChrome(layout, pad: pad, contentW: contentW)
                    self.syncPopoverWindowHeight(layout.popoverHeight, width: width)
                    self.popoverDocument.frame.size.height = CGFloat(layout.contentHeight)
                }
                self.popoverScroll.documentView?.scroll(.zero)
            })
        } else {
            syncPopoverWindowHeight(layout.popoverHeight, width: width)
        }
    }

    /// Instant size only. Never call this inside the 0.25s height ease —
    /// animating `NSScrollView.frame` desyncs the clip from the document.
    private func syncPopoverWindowHeight(_ height: Int, width: CGFloat) {
        let popH = CGFloat(height)
        popoverRoot.frame.size.height = popH
        popoverScroll.frame = popoverRoot.bounds
        popover.contentSize = NSSize(width: width, height: popH)
    }

    private func applyCardSlots(
        _ layout: PopoverStackLayout,
        pad: CGFloat,
        width: CGFloat
    ) {
        PopoverForm.apply(watchCard, slot: layout.watch, pad: pad, width: width)
        PopoverForm.apply(durationCard, slot: layout.duration, pad: pad, width: width)
        PopoverForm.apply(lastWatchEndCard, slot: layout.lastWatchEnd, pad: pad, width: width)
        PopoverForm.apply(panelPowerCard, slot: layout.panelPower, pad: pad, width: width)
        PopoverForm.apply(hygieneCard, slot: layout.hygiene, pad: pad, width: width)
        PopoverForm.apply(batteryCard, slot: layout.battery, pad: pad, width: width)
        PopoverForm.apply(agentIncludeCard, slot: layout.agentInclude, pad: pad, width: width)
        PopoverForm.apply(settleCard, slot: layout.settle, pad: pad, width: width)
        PopoverForm.apply(rampCard, slot: layout.ramp, pad: pad, width: width)
        PopoverForm.apply(thermalCard, slot: layout.thermal, pad: pad, width: width)
        PopoverForm.apply(notifEnableCard, slot: layout.notifEnable, pad: pad, width: width)
        PopoverForm.apply(notifDiscordCard, slot: layout.notifDiscord, pad: pad, width: width)
        PopoverForm.apply(notifTelegramCard, slot: layout.notifTelegram, pad: pad, width: width)
        PopoverForm.apply(notifTelegramInboundCard, slot: layout.notifTelegramInbound, pad: pad, width: width)
        PopoverForm.apply(notifSetupCard, slot: layout.notifSetup, pad: pad, width: width)
        PopoverForm.apply(notifClearCard, slot: layout.notifClear, pad: pad, width: width)
        PopoverForm.apply(loginCard, slot: layout.login, pad: pad, width: width)
    }

    private func applyGeneralChrome(
        _ layout: PopoverStackLayout,
        pad: CGFloat,
        contentW: CGFloat
    ) {
        shortcutLabel.autoresizingMask = []
        recorder.button.autoresizingMask = []
        hotkeyHint.autoresizingMask = []
        quitButton.autoresizingMask = []
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
