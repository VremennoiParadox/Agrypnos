import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

extension PopoverController {
    func addPrefTitle(_ text: String, in card: NSView, ci: CGFloat, width: CGFloat) {
        let label = LabelFactory.make(text, font: .systemFont(ofSize: 13), color: .labelColor)
        label.frame = NSRect(x: ci, y: CGFloat(PopoverStackLayout.prefTitleY), width: width, height: 18)
        card.addSubview(label)
    }

    func addHygieneCard(
        _ card: CardView,
        contentW: CGFloat,
        ci: CGFloat,
        cw: CGFloat,
        swW: CGFloat,
        swH: CGFloat
    ) {
        keyboardSwitch = PopoverForm.switchRow(
            in: card,
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
            in: card,
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
            in: card,
            y: CGFloat(PopoverStackLayout.hygieneFloorY),
            contentW: contentW,
            ci: ci,
            text: "\(UserPreferences.default.brightnessFloorPercent)%",
            width: PopoverForm.percentValueWidth,
            besideSwitch: swW
        )
        _ = PopoverForm.help(
            AgrypnosCopy.brightnessFloorHelp,
            in: card,
            y: CGFloat(PopoverStackLayout.hygieneHelpY),
            x: ci,
            width: cw
        )
        let floorRange = UserPreferences.brightnessFloorPercentRange
        floorPercentSlider = PopoverForm.slider(
            in: card,
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
    }

    func addAgentIncludeCard(
        _ card: CardView,
        contentW: CGFloat,
        ci: CGFloat,
        cw: CGFloat,
        swW: CGFloat,
        swH: CGFloat
    ) {
        addPrefTitle(AgrypnosCopy.agentInclude, in: card, ci: ci, width: cw)
        _ = PopoverForm.help(
            AgrypnosCopy.agentIncludeHelp,
            in: card,
            y: CGFloat(PopoverStackLayout.prefHelpY),
            x: ci,
            width: cw
        )
        includeSwitches = AgentKind.allCases.enumerated().map { index, kind in
            let toggle = PopoverForm.switchRow(
                in: card,
                y: CGFloat(PopoverStackLayout.includeSwitchY(index: index)),
                title: kind.displayName,
                contentW: contentW,
                ci: ci,
                cw: cw,
                swW: swW,
                swH: swH,
                target: self,
                action: #selector(includeToggled(_:))
            )
            toggle.state = AgentIncludeChrome.defaultIncluded.contains(kind) ? .on : .off
            toggle.setAccessibilityLabel(kind.displayName)
            toggle.setAccessibilityHelp(AgrypnosCopy.agentIncludeHelp)
            return toggle
        }
    }

    func addSettleCard(_ card: CardView, contentW: CGFloat, ci: CGFloat, cw: CGFloat) {
        addPrefTitle(
            AgrypnosCopy.settleGrace,
            in: card,
            ci: ci,
            width: cw - PopoverForm.timeValueWidth - 8
        )
        settleValue = PopoverForm.valueLabel(
            in: card,
            y: CGFloat(PopoverStackLayout.prefTitleY),
            contentW: contentW,
            ci: ci,
            text: AgentSettleGraceChrome.valueLabel(seconds: UserPreferences.default.agentSettleGrace),
            width: PopoverForm.timeValueWidth
        )
        _ = PopoverForm.help(
            AgrypnosCopy.settleGraceHelp,
            in: card,
            y: CGFloat(PopoverStackLayout.prefHelpY),
            x: ci,
            width: cw,
            lines: PopoverCopyLayout.settleHelpMaxLines
        )
        let settleRange = UserPreferences.agentSettleGraceRange
        settleSlider = PopoverForm.slider(
            in: card,
            sliderY: CGFloat(PopoverStackLayout.settleControlY),
            minMaxY: CGFloat(PopoverStackLayout.settleMinMaxY),
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
    }

    func addRampCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        addPrefTitle(AgrypnosCopy.lidOpenRamp, in: card, ci: ci, width: cw)
        _ = PopoverForm.help(
            AgrypnosCopy.lidOpenRampHelp,
            in: card,
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
        card.addSubview(rampControl)
    }

    func addDurationCard(_ card: CardView, contentW: CGFloat, ci: CGFloat, cw: CGFloat) {
        let durationLabel = LabelFactory.make(AgrypnosCopy.durationLabel, font: .systemFont(ofSize: 13), color: .labelColor)
        durationLabel.frame = NSRect(x: ci, y: 8, width: 86, height: 22)
        card.addSubview(durationLabel)
        let fieldW = CGFloat(PopoverCopyLayout.minutesFieldWidthPoints)
        let minutesLabelW = CGFloat(PopoverCopyLayout.minutesLabelWidthPoints)
        let fieldGap: CGFloat = 8
        let minutesLabel = LabelFactory.make(AgrypnosCopy.minutesLabel, font: .systemFont(ofSize: 13), color: .labelColor)
        minutesLabel.alignment = .right
        minutesLabel.frame = NSRect(x: contentW - ci - minutesLabelW, y: 8, width: minutesLabelW, height: 22)
        card.addSubview(minutesLabel)
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
        minutesField.cell?.sendsActionOnEndEditing = false
        minutesField.setAccessibilityLabel(AgrypnosCopy.minutesLabel)
        minutesField.frame = NSRect(x: contentW - ci - fieldW, y: 36, width: fieldW, height: 24)
        card.addSubview(minutesField)
        let chrome = DurationPickerChrome.make(duration: .indefinite)
        durationControl = NSSegmentedControl(
            labels: chrome.segmentTitles,
            trackingMode: .selectAny,
            target: self,
            action: #selector(durationChanged(_:))
        )
        durationControl.segmentDistribution = .fillEqually
        durationControl.selectedSegment = 0
        durationControl.frame = NSRect(x: ci, y: 36, width: cw - fieldW - fieldGap, height: 24)
        card.addSubview(durationControl)
        durationHint = LabelFactory.wrapping(
            "",
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor,
            lines: PopoverCopyLayout.durationHintMaxLines
        )
        durationHint.frame = NSRect(x: ci, y: 68, width: cw, height: PopoverMetrics.durationHintHeight)
        durationHint.preferredMaxLayoutWidth = cw
        card.addSubview(durationHint)
    }

    func addLastWatchEndCard(_ card: CardView, ci: CGFloat, cw: CGFloat) {
        lastWatchEndLabel = LabelFactory.wrapping(
            "", font: .systemFont(ofSize: 12), color: .secondaryLabelColor,
            lines: PopoverCopyLayout.lastWatchEndMaxLines
        )
        lastWatchEndLabel.frame = NSRect(
            x: ci, y: CGFloat(PopoverStackLayout.inset), width: cw,
            height: CGFloat(PopoverCopyLayout.lastWatchEndHeightPoints)
        )
        lastWatchEndLabel.preferredMaxLayoutWidth = cw
        lastWatchEndLabel.setAccessibilityLabel("Last watch")
        card.addSubview(lastWatchEndLabel)
    }

    func addBatteryCard(_ card: CardView, contentW: CGFloat, ci: CGFloat, cw: CGFloat) {
        let batt = LabelFactory.make(AgrypnosCopy.batteryFloor, font: .systemFont(ofSize: 13), color: .labelColor)
        batt.frame = NSRect(x: ci, y: ci, width: cw - PopoverForm.percentValueWidth, height: 18)
        card.addSubview(batt)
        let batteryRange = UserPreferences.batteryFloorRange
        batteryValue = PopoverForm.valueLabel(
            in: card,
            y: ci,
            contentW: contentW,
            ci: ci,
            text: "\(UserPreferences.default.batteryFloorPercent)%"
        )
        batterySlider = PopoverForm.slider(
            in: card,
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

    func addThermalCard(
        _ card: CardView,
        contentW: CGFloat,
        ci: CGFloat,
        cw: CGFloat,
        swW: CGFloat,
        swH: CGFloat
    ) {
        addPrefTitle(AgrypnosCopy.thermalAutoOff, in: card, ci: ci, width: cw)
        _ = PopoverForm.help(
            AgrypnosCopy.thermalAutoOffHelp,
            in: card,
            y: CGFloat(PopoverStackLayout.prefHelpY),
            x: ci,
            width: cw
        )
        thermalSwitch = PopoverForm.switchControl(
            in: card,
            y: CGFloat(PopoverStackLayout.prefControlY),
            contentW: contentW,
            ci: ci,
            swW: swW,
            swH: swH,
            target: self,
            action: #selector(thermalToggled(_:))
        )
        thermalSwitch.setAccessibilityLabel(AgrypnosCopy.thermalAutoOff)
        thermalSwitch.setAccessibilityHelp(AgrypnosCopy.thermalAutoOffHelp)
    }
}
