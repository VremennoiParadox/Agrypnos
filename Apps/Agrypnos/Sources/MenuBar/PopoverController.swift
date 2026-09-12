import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum PopoverMetrics {
    static let width: CGFloat = 328
    static let height: CGFloat = 636
    static let pad: CGFloat = 16
    static let inset: CGFloat = 12
    static let captionHeight = CGFloat(PopoverCopyLayout.captionHeightPoints)
    static let durationHintHeight = CGFloat(PopoverCopyLayout.durationHintHeightPoints)
}

@MainActor
final class PopoverController: NSObject, NSTextFieldDelegate {
    let popover = NSPopover()
    private weak var runtime: WatchRuntime?
    private var clickMonitor: Any?
    private var countdown: Timer?

    private var watchSwitch: NSSwitch!
    private var caption: NSTextField!
    private var mainCard: CardView!
    private var headerMark: NSImageView!
    private var durationControl: NSSegmentedControl!
    private var minutesField: NSTextField!
    private var durationHint: NSTextField!
    private var keyboardSwitch: NSSwitch!
    private var floorSwitch: NSSwitch!
    private var batterySlider: NSSlider!
    private var batteryValue: NSTextField!
    private var loginSwitch: NSSwitch!
    private var hotkeyHint: NSTextField!
    private let recorder = HotkeyRecorderControl()
    private var hotkeyButtonY: CGFloat = 0
    private var contentWidth: CGFloat = 0

    init(runtime: WatchRuntime) {
        self.runtime = runtime
        super.init()
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentSize = NSSize(width: PopoverMetrics.width, height: PopoverMetrics.height)
        recorder.onChord = { [weak self] chord in
            self?.runtime?.setHotkey(chord)
            self?.refresh()
        }
        recorder.onSessionChanged = { [weak self] in
            guard let self else { return }
            if self.recorder.isRecording {
                self.minutesField?.window?.makeFirstResponder(nil)
                self.runtime?.prepareHotkeyRemap()
            } else {
                self.runtime?.restoreSuspendedHotkey()
            }
            self.refresh()
        }
        popover.contentViewController = makeController()
    }

    func toggle(relativeTo button: NSView) {
        if popover.isShown {
            close()
        } else {
            open(relativeTo: button)
        }
    }

    func refresh() {
        guard let runtime else { return }
        let on = runtime.engaged
        watchSwitch?.state = on ? .on : .off
        mainCard?.active = on
        headerMark?.contentTintColor = on ? AgrypnosPalette.gold : .labelColor
        caption?.stringValue = AgrypnosCopy.watchCaption(
            engaged: on,
            leftover: runtime.adoptedLeftover,
            floor: runtime.preferences.batteryFloorPercent,
            lidClosed: runtime.engine.lidClosed
        )
        applyDuration(DurationPickerChrome.make(duration: runtime.preferences.duration))
        durationHint?.stringValue = hintCopy(for: runtime)
        keyboardSwitch?.state = runtime.preferences.keyboardBacklightOff ? .on : .off
        floorSwitch?.state = runtime.preferences.applyBrightnessFloor ? .on : .off
        let batteryRange = UserPreferences.batteryFloorRange
        batterySlider?.minValue = Double(batteryRange.lowerBound)
        batterySlider?.maxValue = Double(batteryRange.upperBound)
        batterySlider?.doubleValue = Double(runtime.preferences.batteryFloorPercent)
        batteryValue?.stringValue = "\(runtime.preferences.batteryFloorPercent)%"
        loginSwitch?.state = LaunchAtLoginController.isEnabled ? .on : .off
        let hotkey = HotkeyRecorderChrome.make(
            liveChord: runtime.preferences.hotkey,
            registered: runtime.hotkeyRegistered,
            isRecording: recorder.isRecording,
            failedAttempt: runtime.lastFailedHotkey
        )
        recorder.apply(title: hotkey.buttonTitle)
        layoutHotkeyButton()
        hotkeyHint?.stringValue = hotkey.hint
        let bindFailed = !hotkey.isRecording && (runtime.lastFailedHotkey != nil || !runtime.hotkeyRegistered)
        hotkeyHint?.textColor = bindFailed ? .labelColor : .tertiaryLabelColor
    }

    func open(relativeTo button: NSView) {
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        startCountdown()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    func close() {
        commitMinutesIfChanged()
        recorder.stop()
        runtime?.restoreSuspendedHotkey()
        popover.performClose(nil)
        countdown?.invalidate()
        countdown = nil
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }

    private func makeController() -> NSViewController {
        let W = PopoverMetrics.width
        let pad = PopoverMetrics.pad
        let ci = PopoverMetrics.inset
        let contentW = W - pad * 2
        contentWidth = contentW
        let cw = contentW - ci * 2
        let root = GlassView(frame: NSRect(x: 0, y: 0, width: W, height: PopoverMetrics.height))
        root.material = .popover
        root.blendingMode = .behindWindow
        root.state = .followsWindowActiveState

        let mark = NSImageView(frame: NSRect(x: pad, y: 14, width: 18, height: 18))
        mark.image = GlyphFactory.image(.on)
        mark.contentTintColor = .labelColor
        root.addSubview(mark)
        headerMark = mark
        let title = LabelFactory.make("Agrypnos", font: .systemFont(ofSize: 14, weight: .semibold), color: .labelColor)
        title.frame = NSRect(x: pad + 24, y: 13, width: contentW - 24, height: 20)
        root.addSubview(title)

        func card(_ rect: NSRect) -> CardView {
            let view = CardView(frame: rect)
            view.wantsLayer = true
            root.addSubview(view)
            return view
        }

        let sw = NSSwitch().intrinsicContentSize
        let swW = sw.width > 0 ? sw.width : 38
        let swH = sw.height > 0 ? sw.height : 21

        let g1 = card(NSRect(x: pad, y: 42, width: contentW, height: 96))
        mainCard = g1
        let keep = LabelFactory.make(AgrypnosCopy.keepWatch, font: .systemFont(ofSize: 13), color: .labelColor)
        keep.frame = NSRect(x: ci, y: ci, width: cw - swW - 8, height: 22)
        g1.addSubview(keep)
        watchSwitch = NSSwitch()
        watchSwitch.target = self
        watchSwitch.action = #selector(watchToggled(_:))
        watchSwitch.frame = NSRect(x: contentW - ci - swW, y: ci + 1, width: swW, height: swH)
        g1.addSubview(watchSwitch)
        caption = LabelFactory.wrapping(
            "",
            font: .systemFont(ofSize: 12),
            color: .secondaryLabelColor,
            lines: PopoverCopyLayout.captionMaxLines
        )
        caption.frame = NSRect(x: ci, y: ci + 28, width: cw, height: PopoverMetrics.captionHeight)
        caption.preferredMaxLayoutWidth = cw
        g1.addSubview(caption)

        let g2 = card(NSRect(x: pad, y: 148, width: contentW, height: 136))
        let durationLabel = LabelFactory.make(AgrypnosCopy.durationLabel, font: .systemFont(ofSize: 13), color: .labelColor)
        durationLabel.frame = NSRect(x: ci, y: 8, width: 86, height: 22)
        g2.addSubview(durationLabel)
        let fieldW: CGFloat = 56
        let fieldGap: CGFloat = 8
        let minutesLabel = LabelFactory.make(AgrypnosCopy.minutesLabel, font: .systemFont(ofSize: 13), color: .labelColor)
        minutesLabel.alignment = .right
        minutesLabel.frame = NSRect(x: contentW - ci - fieldW, y: 8, width: fieldW, height: 22)
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

        let g3 = card(NSRect(x: pad, y: 294, width: contentW, height: 76))
        addHygieneRow(g3, y: 10, title: AgrypnosCopy.keyboardDark, switchSlot: &keyboardSwitch, action: #selector(keyboardToggled(_:)), contentW: contentW, ci: ci, cw: cw, swW: swW, swH: swH)
        addHygieneRow(g3, y: 42, title: AgrypnosCopy.brightnessFloor, switchSlot: &floorSwitch, action: #selector(floorToggled(_:)), contentW: contentW, ci: ci, cw: cw, swW: swW, swH: swH)

        let g4 = card(NSRect(x: pad, y: 380, width: contentW, height: 88))
        let batt = LabelFactory.make(AgrypnosCopy.batteryFloor, font: .systemFont(ofSize: 13), color: .labelColor)
        batt.frame = NSRect(x: ci, y: ci, width: cw - 54, height: 18)
        g4.addSubview(batt)
        let batteryRange = UserPreferences.batteryFloorRange
        batteryValue = LabelFactory.make(
            "\(UserPreferences.default.batteryFloorPercent)%",
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .secondaryLabelColor
        )
        batteryValue.alignment = .right
        batteryValue.frame = NSRect(x: contentW - ci - 54, y: ci, width: 54, height: 18)
        g4.addSubview(batteryValue)
        batterySlider = NSSlider(
            value: Double(UserPreferences.default.batteryFloorPercent),
            minValue: Double(batteryRange.lowerBound),
            maxValue: Double(batteryRange.upperBound),
            target: self,
            action: #selector(batteryChanged(_:))
        )
        batterySlider.isContinuous = true
        batterySlider.frame = NSRect(x: ci, y: ci + 26, width: cw, height: 20)
        g4.addSubview(batterySlider)
        let minHint = LabelFactory.make("\(batteryRange.lowerBound)%", font: .systemFont(ofSize: 10), color: .tertiaryLabelColor)
        minHint.frame = NSRect(x: ci, y: ci + 50, width: 34, height: 13)
        g4.addSubview(minHint)
        let maxHint = LabelFactory.make("\(batteryRange.upperBound)%", font: .systemFont(ofSize: 10), color: .tertiaryLabelColor)
        maxHint.alignment = .right
        maxHint.frame = NSRect(x: contentW - ci - 40, y: ci + 50, width: 40, height: 13)
        g4.addSubview(maxHint)

        let g5 = card(NSRect(x: pad, y: 478, width: contentW, height: 44))
        let login = LabelFactory.make(AgrypnosCopy.launchAtLogin, font: .systemFont(ofSize: 13), color: .labelColor)
        login.frame = NSRect(x: ci, y: 11, width: cw - swW - 8, height: 22)
        g5.addSubview(login)
        loginSwitch = NSSwitch()
        loginSwitch.target = self
        loginSwitch.action = #selector(loginToggled(_:))
        loginSwitch.frame = NSRect(x: contentW - ci - swW, y: 12, width: swW, height: swH)
        g5.addSubview(loginSwitch)

        let shortcut = LabelFactory.make(AgrypnosCopy.shortcutLabel, font: .systemFont(ofSize: 13), color: .labelColor)
        shortcut.frame = NSRect(x: pad, y: 532, width: 90, height: 22)
        root.addSubview(shortcut)
        hotkeyButtonY = 530
        root.addSubview(recorder.button)
        layoutHotkeyButton()

        hotkeyHint = LabelFactory.wrapping("", font: .systemFont(ofSize: 11), color: .tertiaryLabelColor, lines: 2)
        hotkeyHint.frame = NSRect(x: pad, y: 558, width: contentW, height: 32)
        hotkeyHint.preferredMaxLayoutWidth = contentW
        root.addSubview(hotkeyHint)

        let quit = NSButton(title: AgrypnosCopy.quit, target: self, action: #selector(quitApp))
        quit.bezelStyle = .rounded
        quit.controlSize = .regular
        quit.sizeToFit()
        quit.frame = NSRect(x: W - pad - quit.frame.width, y: 600, width: quit.frame.width, height: quit.frame.height)
        root.addSubview(quit)

        let vc = NSViewController()
        vc.view = root
        return vc
    }

    private func addHygieneRow(
        _ card: CardView,
        y: CGFloat,
        title: String,
        switchSlot: inout NSSwitch!,
        action: Selector,
        contentW: CGFloat,
        ci: CGFloat,
        cw: CGFloat,
        swW: CGFloat,
        swH: CGFloat
    ) {
        let label = LabelFactory.make(title, font: .systemFont(ofSize: 13), color: .labelColor)
        label.frame = NSRect(x: ci, y: y, width: cw - swW - 8, height: 22)
        card.addSubview(label)
        let toggle = NSSwitch()
        toggle.target = self
        toggle.action = action
        toggle.frame = NSRect(x: contentW - ci - swW, y: y + 1, width: swW, height: swH)
        card.addSubview(toggle)
        switchSlot = toggle
    }

    private func applyDuration(_ chrome: DurationPickerChrome) {
        guard let durationControl else { return }
        for (index, title) in chrome.segmentTitles.enumerated() where index < durationControl.segmentCount {
            durationControl.setLabel(title, forSegment: index)
        }
        durationControl.selectedSegment = chrome.selectedSegment
        if minutesField?.currentEditor() == nil {
            minutesField?.stringValue = chrome.minutesText
        }
    }

    private func layoutHotkeyButton() {
        let pad = PopoverMetrics.pad
        recorder.button.sizeToFit()
        let width = min(max(recorder.button.frame.width + 12, 96), contentWidth - 100)
        recorder.button.frame = NSRect(
            x: pad + contentWidth - width,
            y: hotkeyButtonY,
            width: width,
            height: 24
        )
    }

    private func hintCopy(for runtime: WatchRuntime) -> String {
        var remaining: Int?
        if let end = runtime.engine.timerEnd, runtime.engaged {
            remaining = max(0, Int(end.timeIntervalSinceNow.rounded()))
        }
        return AgrypnosCopy.durationHint(
            option: runtime.preferences.duration,
            engaged: runtime.engaged,
            remainingSeconds: remaining
        )
    }

    private func startCountdown() {
        countdown?.invalidate()
        countdown = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func stopRecordingIfNeeded() {
        if recorder.isRecording {
            recorder.stop()
            runtime?.restoreSuspendedHotkey()
        }
    }

    private func commitMinutesIfChanged() {
        guard let runtime else { return }
        guard let minutes = DurationPickerChrome.parseMinutes(minutesField?.stringValue ?? "") else { return }
        guard DurationPickerChrome.shouldCommit(minutes: minutes, current: runtime.preferences.duration) else {
            return
        }
        runtime.setCustomMinutes(minutes)
    }

    @objc private func watchToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        runtime?.setEngaged(sender.state == .on)
        refresh()
    }

    @objc private func durationChanged(_ sender: NSSegmentedControl) {
        stopRecordingIfNeeded()
        let typed = minutesField?.stringValue ?? ""
        guard let option = DurationPickerChrome.duration(
            selectingSegment: sender.selectedSegment,
            minutesText: typed
        ) else {
            minutesField?.window?.makeFirstResponder(minutesField)
            refresh()
            return
        }
        runtime?.setDuration(option)
        refresh()
    }

    @objc private func minutesCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        commitMinutesIfChanged()
        refresh()
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        stopRecordingIfNeeded()
    }

    @objc private func keyboardToggled(_ sender: NSSwitch) {
        runtime?.setHygiene(keyboard: sender.state == .on)
    }

    @objc private func floorToggled(_ sender: NSSwitch) {
        runtime?.setHygiene(floor: sender.state == .on)
    }

    @objc private func batteryChanged(_ sender: NSSlider) {
        runtime?.setBatteryFloor(Int(sender.doubleValue.rounded()))
        batteryValue?.stringValue = "\(Int(sender.doubleValue.rounded()))%"
    }

    @objc private func loginToggled(_ sender: NSSwitch) {
        do {
            try LaunchAtLoginController.setEnabled(sender.state == .on)
        } catch {
            UserNotify.post("Couldn't update Launch at login.")
        }
        sender.state = LaunchAtLoginController.isEnabled ? .on : .off
    }

    @objc private func quitApp() {
        if runtime?.engaged == true {
            runtime?.setEngaged(false)
        }
        NSApp.terminate(nil)
    }
}
