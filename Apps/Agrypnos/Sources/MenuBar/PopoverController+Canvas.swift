import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension PopoverController {
    func makeController() -> NSViewController {
        let layout = PopoverStackLayout.make()
        let power = PopoverStackLayout.make(section: .power)
        let agents = PopoverStackLayout.make(section: .agents)
        let general = PopoverStackLayout.make(section: .general)
        let W = CGFloat(PopoverStackLayout.width)
        let pad = CGFloat(PopoverStackLayout.pad)
        let ci = CGFloat(PopoverStackLayout.inset)
        let contentW = W - pad * 2
        contentWidth = contentW
        let cw = contentW - ci * 2
        let root = GlassView(frame: NSRect(x: 0, y: 0, width: W, height: CGFloat(layout.popoverHeight)))
        root.material = .popover
        root.blendingMode = .behindWindow
        root.state = .followsWindowActiveState
        popoverRoot = root

        let document = FlippedView(frame: NSRect(x: 0, y: 0, width: W, height: CGFloat(layout.contentHeight)))
        popoverDocument = document
        let scroll = NSScrollView(frame: root.bounds)
        let clip = FlippedClipView(frame: scroll.contentView.frame)
        clip.drawsBackground = false
        scroll.contentView = clip
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.horizontalScrollElasticity = .none
        scroll.documentView = document
        popoverScroll = scroll
        root.addSubview(scroll)

        let mark = NSImageView(frame: NSRect(x: pad, y: 14, width: 18, height: 18))
        mark.image = GlyphFactory.image(.on)
        mark.contentTintColor = .labelColor
        document.addSubview(mark)
        headerMark = mark
        let title = LabelFactory.make("Agrypnos", font: .systemFont(ofSize: 14, weight: .semibold), color: .labelColor)
        title.frame = NSRect(x: pad + 24, y: 13, width: contentW - 24, height: 20)
        document.addSubview(title)

        sectionControl = NSSegmentedControl(
            labels: PopoverSection.titles,
            trackingMode: .selectOne,
            target: self,
            action: #selector(sectionChanged(_:))
        )
        sectionControl.segmentDistribution = .fillEqually
        sectionControl.segmentStyle = .rounded
        sectionControl.controlSize = .small
        sectionControl.selectedSegment = PopoverSection.default.rawValue
        sectionControl.setAccessibilityLabel("Section")
        sectionControl.frame = NSRect(
            x: pad,
            y: CGFloat(layout.sectionSwitcher.y),
            width: contentW,
            height: CGFloat(layout.sectionSwitcher.height)
        )
        document.addSubview(sectionControl)

        let sw = NSSwitch().intrinsicContentSize
        let swW = sw.width > 0 ? sw.width : 38
        let swH = sw.height > 0 ? sw.height : 21

        watchCard = PopoverForm.card(in: document, slot: layout.watch!, pad: pad, width: contentW)
        mainCard = watchCard
        watchSwitch = PopoverForm.switchRow(
            in: watchCard,
            y: ci,
            title: AgrypnosCopy.keepWatch,
            contentW: contentW,
            ci: ci,
            cw: cw,
            swW: swW,
            swH: swH,
            target: self,
            action: #selector(watchToggled(_:))
        )
        caption = LabelFactory.wrapping(
            "",
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor,
            lines: PopoverCopyLayout.captionMaxLines
        )
        caption.frame = NSRect(x: ci, y: ci + 28, width: cw, height: PopoverMetrics.captionHeight)
        caption.preferredMaxLayoutWidth = cw
        watchCard.addSubview(caption)

        durationCard = PopoverForm.card(in: document, slot: layout.duration!, pad: pad, width: contentW)
        addDurationCard(durationCard, contentW: contentW, ci: ci, cw: cw)

        lastWatchEndCard = PopoverForm.card(in: document, slot: layout.lastWatchEnd!, pad: pad, width: contentW)
        addLastWatchEndCard(lastWatchEndCard, ci: ci, cw: cw)

        hygieneCard = PopoverForm.card(in: document, slot: power.hygiene!, pad: pad, width: contentW)
        addHygieneCard(hygieneCard, contentW: contentW, ci: ci, cw: cw, swW: swW, swH: swH)

        batteryCard = PopoverForm.card(in: document, slot: power.battery!, pad: pad, width: contentW)
        addBatteryCard(batteryCard, contentW: contentW, ci: ci, cw: cw)

        settleCard = PopoverForm.card(in: document, slot: agents.settle!, pad: pad, width: contentW)
        addSettleCard(settleCard, contentW: contentW, ci: ci, cw: cw)

        rampCard = PopoverForm.card(in: document, slot: power.ramp!, pad: pad, width: contentW)
        addRampCard(rampCard, ci: ci, cw: cw)

        thermalCard = PopoverForm.card(in: document, slot: power.thermal!, pad: pad, width: contentW)
        addThermalCard(thermalCard, contentW: contentW, ci: ci, cw: cw, swW: swW, swH: swH)

        let notif = PopoverStackLayout.make(section: .notif)
        notifEnableCard = PopoverForm.card(in: document, slot: notif.notifEnable!, pad: pad, width: contentW)
        addNotifEnableCard(notifEnableCard, contentW: contentW, ci: ci, cw: cw, swW: swW, swH: swH)

        notifDiscordCard = PopoverForm.card(in: document, slot: notif.notifDiscord!, pad: pad, width: contentW)
        addNotifDiscordCard(notifDiscordCard, ci: ci, cw: cw)

        notifTelegramCard = PopoverForm.card(in: document, slot: notif.notifTelegram!, pad: pad, width: contentW)
        addNotifTelegramCard(notifTelegramCard, ci: ci, cw: cw)

        notifSetupCard = PopoverForm.card(in: document, slot: notif.notifSetup!, pad: pad, width: contentW)
        addNotifSetupCard(notifSetupCard, ci: ci, cw: cw)

        notifClearCard = PopoverForm.card(in: document, slot: notif.notifClear!, pad: pad, width: contentW)
        addNotifClearCard(notifClearCard, ci: ci, cw: cw)

        loginCard = PopoverForm.card(in: document, slot: general.login!, pad: pad, width: contentW)
        loginSwitch = PopoverForm.switchRow(
            in: loginCard,
            y: CGFloat(PopoverStackLayout.loginSwitchRowY),
            title: AgrypnosCopy.launchAtLogin,
            contentW: contentW,
            ci: ci,
            cw: cw,
            swW: swW,
            swH: swH,
            target: self,
            action: #selector(loginToggled(_:))
        )

        shortcutLabel = LabelFactory.make(AgrypnosCopy.shortcutLabel, font: .systemFont(ofSize: 13), color: .labelColor)
        shortcutLabel.frame = NSRect(x: pad, y: CGFloat(general.shortcutY!), width: 90, height: 22)
        document.addSubview(shortcutLabel)
        hotkeyButtonY = CGFloat(general.shortcutY!)
        document.addSubview(recorder.button)
        layoutHotkeyButton()

        hotkeyHint = LabelFactory.wrapping(
            "",
            font: .systemFont(ofSize: 11),
            color: .tertiaryLabelColor,
            lines: PopoverCopyLayout.hotkeyHintMaxLines
        )
        hotkeyHint.frame = NSRect(
            x: pad,
            y: CGFloat(general.hotkeyHint!.y),
            width: contentW,
            height: CGFloat(general.hotkeyHint!.height)
        )
        hotkeyHint.preferredMaxLayoutWidth = contentW
        document.addSubview(hotkeyHint)

        quitButton = NSButton(title: AgrypnosCopy.quit, target: self, action: #selector(quitApp))
        quitButton.bezelStyle = .rounded
        quitButton.controlSize = .regular
        quitButton.sizeToFit()
        quitButton.frame = NSRect(
            x: W - pad - quitButton.frame.width,
            y: CGFloat(general.quitY!),
            width: quitButton.frame.width,
            height: quitButton.frame.height
        )
        document.addSubview(quitButton)

        applySection(.watch)

        let vc = NSViewController()
        vc.view = root
        return vc
    }
}
