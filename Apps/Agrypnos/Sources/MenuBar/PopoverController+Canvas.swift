import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension PopoverController {
    func makeController() -> NSViewController {
        let layout = PopoverStackLayout.make()
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

        let document = FlippedView(frame: NSRect(x: 0, y: 0, width: W, height: CGFloat(layout.contentHeight)))
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

        let sw = NSSwitch().intrinsicContentSize
        let swW = sw.width > 0 ? sw.width : 38
        let swH = sw.height > 0 ? sw.height : 21

        let g1 = PopoverForm.card(in: document, slot: layout.watch, pad: pad, width: contentW)
        mainCard = g1
        watchSwitch = PopoverForm.switchRow(
            in: g1,
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
        g1.addSubview(caption)

        let g2 = PopoverForm.card(in: document, slot: layout.duration, pad: pad, width: contentW)
        addDurationCard(g2, contentW: contentW, ci: ci, cw: cw)

        let g3 = PopoverForm.card(in: document, slot: layout.hygiene, pad: pad, width: contentW)
        keyboardSwitch = PopoverForm.switchRow(
            in: g3,
            y: CGFloat(PopoverStackLayout.hygieneKeyboardY),
            title: AgrypnosCopy.keyboardDark,
            contentW: contentW,
            ci: ci,
            cw: cw,
            swW: swW,
            swH: swH,
            target: self,
            action: #selector(keyboardToggled(_:))
        )
        floorSwitch = PopoverForm.switchRow(
            in: g3,
            y: CGFloat(PopoverStackLayout.hygieneFloorY),
            title: AgrypnosCopy.brightnessFloor,
            contentW: contentW,
            ci: ci,
            cw: cw,
            swW: swW,
            swH: swH,
            target: self,
            action: #selector(floorToggled(_:)),
            trailing: PopoverForm.percentValueWidth + 8
        )
        floorPercentValue = PopoverForm.valueLabel(
            in: g3,
            y: CGFloat(PopoverStackLayout.hygieneFloorY),
            contentW: contentW,
            ci: ci,
            text: "\(UserPreferences.default.brightnessFloorPercent)%",
            width: PopoverForm.percentValueWidth,
            besideSwitch: swW
        )
        _ = PopoverForm.help(
            AgrypnosCopy.brightnessFloorHelp,
            in: g3,
            y: CGFloat(PopoverStackLayout.hygieneHelpY),
            x: ci,
            width: cw
        )
        let floorRange = UserPreferences.brightnessFloorPercentRange
        floorPercentSlider = PopoverForm.slider(
            in: g3,
            sliderY: CGFloat(PopoverStackLayout.hygieneSliderY),
            minMaxY: CGFloat(PopoverStackLayout.hygieneMinMaxY),
            ci: ci,
            cw: cw,
            contentW: contentW,
            minValue: Double(floorRange.lowerBound),
            maxValue: Double(floorRange.upperBound),
            value: Double(UserPreferences.default.brightnessFloorPercent),
            minLabel: BrightnessFloorPercentChrome.minLabel,
            maxLabel: BrightnessFloorPercentChrome.maxLabel,
            target: self,
            action: #selector(floorPercentChanged(_:))
        )
        floorPercentSlider.setAccessibilityLabel(AgrypnosCopy.brightnessFloor)
        floorPercentSlider.setAccessibilityHelp(AgrypnosCopy.brightnessFloorHelp)

        let g4 = PopoverForm.card(in: document, slot: layout.battery, pad: pad, width: contentW)
        addBatteryCard(g4, contentW: contentW, ci: ci, cw: cw)

        let gSettle = PopoverForm.card(in: document, slot: layout.settle, pad: pad, width: contentW)
        addPrefTitle(
            AgrypnosCopy.settleGrace,
            in: gSettle,
            ci: ci,
            width: cw - PopoverForm.timeValueWidth - 8
        )
        settleValue = PopoverForm.valueLabel(
            in: gSettle,
            y: CGFloat(PopoverStackLayout.prefTitleY),
            contentW: contentW,
            ci: ci,
            text: AgentSettleGraceChrome.valueLabel(seconds: UserPreferences.default.agentSettleGrace),
            width: PopoverForm.timeValueWidth
        )
        _ = PopoverForm.help(
            AgrypnosCopy.settleGraceHelp,
            in: gSettle,
            y: CGFloat(PopoverStackLayout.prefHelpY),
            x: ci,
            width: cw
        )
        let settleRange = UserPreferences.agentSettleGraceRange
        settleSlider = PopoverForm.slider(
            in: gSettle,
            sliderY: CGFloat(PopoverStackLayout.prefControlY),
            minMaxY: CGFloat(PopoverStackLayout.prefMinMaxY),
            ci: ci,
            cw: cw,
            contentW: contentW,
            minValue: Double(settleRange.lowerBound),
            maxValue: Double(settleRange.upperBound),
            value: UserPreferences.default.agentSettleGrace,
            minLabel: AgentSettleGraceChrome.minLabel,
            maxLabel: AgentSettleGraceChrome.maxLabel,
            target: self,
            action: #selector(settleChanged(_:))
        )
        settleSlider.setAccessibilityLabel(AgrypnosCopy.settleGrace)
        settleSlider.setAccessibilityHelp(AgrypnosCopy.settleGraceHelp)

        let gRamp = PopoverForm.card(in: document, slot: layout.ramp, pad: pad, width: contentW)
        addPrefTitle(AgrypnosCopy.lidOpenRamp, in: gRamp, ci: ci, width: cw)
        _ = PopoverForm.help(
            AgrypnosCopy.lidOpenRampHelp,
            in: gRamp,
            y: CGFloat(PopoverStackLayout.prefHelpY),
            x: ci,
            width: cw
        )
        rampControl = NSSegmentedControl(
            labels: LidOpenRampChrome.titles,
            trackingMode: .selectOne,
            target: self,
            action: #selector(rampChanged(_:))
        )
        rampControl.segmentDistribution = .fillEqually
        rampControl.selectedSegment = LidOpenRampChrome.selectedSegment(
            seconds: UserPreferences.default.lidOpenRampSeconds
        )
        rampControl.frame = NSRect(
            x: ci,
            y: CGFloat(PopoverStackLayout.prefControlY),
            width: cw,
            height: 24
        )
        rampControl.setAccessibilityLabel(AgrypnosCopy.lidOpenRamp)
        rampControl.setAccessibilityHelp(AgrypnosCopy.lidOpenRampHelp)
        gRamp.addSubview(rampControl)

        let gLogin = PopoverForm.card(in: document, slot: layout.login, pad: pad, width: contentW)
        loginSwitch = PopoverForm.switchRow(
            in: gLogin,
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

        let shortcut = LabelFactory.make(AgrypnosCopy.shortcutLabel, font: .systemFont(ofSize: 13), color: .labelColor)
        shortcut.frame = NSRect(x: pad, y: CGFloat(layout.shortcutY), width: 90, height: 22)
        document.addSubview(shortcut)
        hotkeyButtonY = CGFloat(layout.shortcutY)
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
            y: CGFloat(layout.hotkeyHint.y),
            width: contentW,
            height: CGFloat(layout.hotkeyHint.height)
        )
        hotkeyHint.preferredMaxLayoutWidth = contentW
        document.addSubview(hotkeyHint)

        let quit = NSButton(title: AgrypnosCopy.quit, target: self, action: #selector(quitApp))
        quit.bezelStyle = .rounded
        quit.controlSize = .regular
        quit.sizeToFit()
        quit.frame = NSRect(
            x: W - pad - quit.frame.width,
            y: CGFloat(layout.quitY),
            width: quit.frame.width,
            height: quit.frame.height
        )
        document.addSubview(quit)

        let vc = NSViewController()
        vc.view = root
        return vc
    }

    private func addPrefTitle(_ text: String, in card: NSView, ci: CGFloat, width: CGFloat) {
        let label = LabelFactory.make(text, font: .systemFont(ofSize: 13), color: .labelColor)
        label.frame = NSRect(x: ci, y: CGFloat(PopoverStackLayout.prefTitleY), width: width, height: 18)
        card.addSubview(label)
    }

    private func addDurationCard(_ g2: CardView, contentW: CGFloat, ci: CGFloat, cw: CGFloat) {
        let durationLabel = LabelFactory.make(AgrypnosCopy.durationLabel, font: .systemFont(ofSize: 13), color: .labelColor)
        durationLabel.frame = NSRect(x: ci, y: 8, width: 86, height: 22)
        g2.addSubview(durationLabel)
        let fieldW = CGFloat(PopoverCopyLayout.minutesFieldWidthPoints)
        let minutesLabelW = CGFloat(PopoverCopyLayout.minutesLabelWidthPoints)
        let fieldGap: CGFloat = 8
        let minutesLabel = LabelFactory.make(AgrypnosCopy.minutesLabel, font: .systemFont(ofSize: 13), color: .labelColor)
        minutesLabel.alignment = .right
        minutesLabel.frame = NSRect(x: contentW - ci - minutesLabelW, y: 8, width: minutesLabelW, height: 22)
        g2.addSubview(minutesLabel)
        minutesField = NSTextField(string: "")
        minutesField.placeholderString = AgrypnosCopy.minutesPlaceholder
        minutesField.font = .systemFont(ofSize: 13)
        minutesField.alignment = .right
        minutesField.isBezeled = true
        minutesField.bezelStyle = .roundedBezel
        minutesField.isEditable = true
        minutesField.isSelectable = true
        minutesField.delegate = self
        minutesField.target = self
        minutesField.action = #selector(minutesCommitted(_:))
        minutesField.cell?.sendsActionOnEndEditing = true
        minutesField.setAccessibilityLabel(AgrypnosCopy.minutesLabel)
        minutesField.frame = NSRect(x: contentW - ci - fieldW, y: 36, width: fieldW, height: 24)
        g2.addSubview(minutesField)
        let chrome = DurationPickerChrome.make(duration: .indefinite)
        durationControl = NSSegmentedControl(
            labels: chrome.segmentTitles,
            trackingMode: .selectOne,
            target: self,
            action: #selector(durationChanged(_:))
        )
        durationControl.segmentDistribution = .fillEqually
        durationControl.selectedSegment = 0
        durationControl.frame = NSRect(x: ci, y: 36, width: cw - fieldW - fieldGap, height: 24)
        g2.addSubview(durationControl)
        durationHint = LabelFactory.wrapping(
            "",
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor,
            lines: PopoverCopyLayout.durationHintMaxLines
        )
        durationHint.frame = NSRect(x: ci, y: 68, width: cw, height: PopoverMetrics.durationHintHeight)
        durationHint.preferredMaxLayoutWidth = cw
        g2.addSubview(durationHint)
    }

    private func addBatteryCard(_ g4: CardView, contentW: CGFloat, ci: CGFloat, cw: CGFloat) {
        let batt = LabelFactory.make(AgrypnosCopy.batteryFloor, font: .systemFont(ofSize: 13), color: .labelColor)
        batt.frame = NSRect(x: ci, y: ci, width: cw - PopoverForm.percentValueWidth, height: 18)
        g4.addSubview(batt)
        let batteryRange = UserPreferences.batteryFloorRange
        batteryValue = PopoverForm.valueLabel(
            in: g4,
            y: ci,
            contentW: contentW,
            ci: ci,
            text: "\(UserPreferences.default.batteryFloorPercent)%"
        )
        batterySlider = PopoverForm.slider(
            in: g4,
            sliderY: ci + 26,
            minMaxY: ci + 50,
            ci: ci,
            cw: cw,
            contentW: contentW,
            minValue: Double(batteryRange.lowerBound),
            maxValue: Double(batteryRange.upperBound),
            value: Double(UserPreferences.default.batteryFloorPercent),
            minLabel: BatteryFloorChrome.minLabel,
            maxLabel: BatteryFloorChrome.maxLabel,
            target: self,
            action: #selector(batteryChanged(_:))
        )
        batterySlider.setAccessibilityLabel(AgrypnosCopy.batteryFloor)
    }
}
