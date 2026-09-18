import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum PopoverMetrics {
    static var width: CGFloat { CGFloat(PopoverStackLayout.width) }
    static var pad: CGFloat { CGFloat(PopoverStackLayout.pad) }
    static var inset: CGFloat { CGFloat(PopoverStackLayout.inset) }
    static var captionHeight: CGFloat { CGFloat(PopoverCopyLayout.captionHeightPoints) }
    static var durationHintHeight: CGFloat { CGFloat(PopoverCopyLayout.durationHintHeightPoints) }
}

@MainActor
final class PopoverController: NSObject, NSTextFieldDelegate {
    let popover = NSPopover()
    weak var runtime: WatchRuntime?
    private var clickMonitor: Any?
    private var countdown: Timer?

    var watchSwitch: NSSwitch!
    var caption: NSTextField!
    var mainCard: CardView!
    var headerMark: NSImageView!
    var sectionControl: NSSegmentedControl!
    var durationControl: NSSegmentedControl!
    var applyingDurationChrome = false
    var minutesField: NSTextField!
    var durationHint: NSTextField!
    var keyboardSwitch: NSSwitch!
    var floorSwitch: NSSwitch!
    var floorPercentSlider: NSSlider!
    var floorPercentValue: NSTextField!
    var batterySlider: NSSlider!
    var batteryValue: NSTextField!
    var settleSlider: NSSlider!
    var settleValue: NSTextField!
    var rampControl: NSSegmentedControl!
    var thermalSwitch: NSSwitch!
    var notifSwitch: NSSwitch!
    var discordSecrets: SecretRevealRow!
    var discordStatus: NSTextField!
    var telegramTokenSecrets: SecretRevealRow!
    var telegramChatSecrets: SecretRevealRow!
    var discordInvalid = false
    var loginSwitch: NSSwitch!
    var hotkeyHint: NSTextField!
    let recorder = HotkeyRecorderControl()
    var hotkeyButtonY: CGFloat = 0
    var contentWidth: CGFloat = 0
    var popoverScroll: NSScrollView!
    var popoverRoot: NSView!
    var popoverDocument: NSView!
    var watchCard: CardView!
    var durationCard: CardView!
    var lastWatchEndCard: CardView!
    var lastWatchEndLabel: NSTextField!
    var hygieneCard: CardView!
    var batteryCard: CardView!
    var settleCard: CardView!
    var rampCard: CardView!
    var thermalCard: CardView!
    var notifEnableCard: CardView!
    var notifDiscordCard: CardView!
    var notifTelegramCard: CardView!
    var notifSetupCard: CardView!
    var notifClearCard: CardView!
    var notifClearButton: NSButton!
    var loginCard: CardView!
    var shortcutLabel: NSTextField!
    var quitButton: NSButton!
    var currentSection: PopoverSection = .default

    init(runtime: WatchRuntime) {
        self.runtime = runtime
        super.init()
        popover.behavior = .applicationDefined
        popover.animates = true
        let layout = PopoverStackLayout.make()
        popover.contentSize = NSSize(
            width: CGFloat(PopoverStackLayout.width),
            height: CGFloat(layout.popoverHeight)
        )
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
        lastWatchEndLabel?.stringValue = AgrypnosCopy.lastWatchEndCaption(
            event: runtime.preferences.lastWatchEnd, now: Date()
        )
        applyDuration(
            DurationPickerChrome.make(
                duration: runtime.preferences.duration,
                minutesDraft: minutesField?.currentEditor() != nil
                    ? (minutesField?.stringValue ?? "")
                    : nil
            )
        )
        durationHint?.stringValue = hintCopy(for: runtime)
        keyboardSwitch?.state = runtime.preferences.keyboardBacklightOff ? .on : .off
        floorSwitch?.state = runtime.preferences.applyBrightnessFloor ? .on : .off
        let floorRange = UserPreferences.brightnessFloorPercentRange
        floorPercentSlider?.minValue = Double(floorRange.lowerBound)
        floorPercentSlider?.maxValue = Double(floorRange.upperBound)
        floorPercentSlider?.doubleValue = Double(runtime.preferences.brightnessFloorPercent)
        floorPercentValue?.stringValue = "\(runtime.preferences.brightnessFloorPercent)%"
        let settleRange = UserPreferences.agentSettleGraceRange
        settleSlider?.minValue = Double(settleRange.lowerBound)
        settleSlider?.maxValue = Double(settleRange.upperBound)
        settleSlider?.doubleValue = runtime.preferences.agentSettleGrace
        settleValue?.stringValue = AgentSettleGraceChrome.valueLabel(
            seconds: runtime.preferences.agentSettleGrace
        )
        rampControl?.selectedSegment = LidOpenRampChrome.selectedSegment(
            seconds: runtime.preferences.lidOpenRampSeconds
        )
        thermalSwitch?.state = runtime.preferences.thermalAutoOff ? .on : .off
        refreshNotifChrome(runtime: runtime)
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
        applySection(.watch)
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        popoverScroll?.documentView?.scroll(.zero)
        startCountdown()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    func close() {
        commitMinutesIfChanged(onLeaveWatch: true)
        if currentSection == .notif {
            commitNotifFields()
        }
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

    func applyDuration(_ chrome: DurationPickerChrome) {
        guard let durationControl else { return }
        applyingDurationChrome = true
        defer { applyingDurationChrome = false }
        for (index, title) in chrome.segmentTitles.enumerated() where index < durationControl.segmentCount {
            durationControl.setLabel(title, forSegment: index)
        }
        let selected = DurationPickerChrome.segmentSelection(
            selectedSegment: chrome.selectedSegment,
            count: durationControl.segmentCount
        )
        for (index, on) in selected.enumerated() {
            durationControl.setSelected(on, forSegment: index)
        }
        if chrome.selectedSegment >= 0 || minutesField?.currentEditor() == nil {
            minutesField?.stringValue = chrome.minutesText
        }
    }

    func layoutHotkeyButton() {
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
            remainingSeconds: remaining,
            thermalAutoOff: runtime.preferences.thermalAutoOff
        )
    }

    private func startCountdown() {
        countdown?.invalidate()
        countdown = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopRecordingIfNeeded() {
        if recorder.isRecording {
            recorder.stop()
            runtime?.restoreSuspendedHotkey()
        }
    }

    private func commitMinutesIfChanged(onLeaveWatch: Bool = false) {
        guard let runtime else { return }
        guard let minutes = DurationPickerChrome.parseMinutes(minutesField?.stringValue ?? "") else { return }
        let should = onLeaveWatch
            ? DurationPickerChrome.shouldCommitOnLeaveWatch(
                minutes: minutes,
                current: runtime.preferences.duration
            )
            : DurationPickerChrome.shouldCommit(minutes: minutes, current: runtime.preferences.duration)
        guard should else { return }
        runtime.setCustomMinutes(minutes)
    }

    @objc func sectionChanged(_ sender: NSSegmentedControl) {
        guard let section = PopoverSection(rawValue: sender.selectedSegment) else {
            sender.selectedSegment = currentSection.rawValue
            return
        }
        if currentSection == .watch, section != .watch {
            commitMinutesIfChanged(onLeaveWatch: true)
        }
        if currentSection == .notif, section != .notif {
            commitNotifFields()
        }
        stopRecordingIfNeeded()
        applySection(section)
        if section == .notif {
            loadNotifSecretFields()
        }
        refresh()
    }

    @objc func watchToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        runtime?.setEngaged(sender.state == .on)
        refresh()
    }

    @objc func durationChanged(_ sender: NSSegmentedControl) {
        guard !applyingDurationChrome else { return }
        stopRecordingIfNeeded()
        let on = (0..<sender.segmentCount).filter { sender.isSelected(forSegment: $0) }
        let previous = DurationPickerChrome.make(
            duration: runtime?.preferences.duration ?? .indefinite
        ).selectedSegment
        guard let index = DurationPickerChrome.exclusiveSelectedIndex(nowOn: on, previous: previous),
              let option = DurationPickerChrome.duration(selectingSegment: index)
        else {
            refresh()
            return
        }
        minutesField?.window?.makeFirstResponder(nil)
        minutesField?.stringValue = ""
        runtime?.setDuration(option)
        refresh()
    }

    @objc func minutesCommitted(_ sender: NSTextField) {
        stopRecordingIfNeeded()
        commitMinutesIfChanged()
        refresh()
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        stopRecordingIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        (obj.object as? NSView)?.window?.makeKey()
        if let field = obj.object as? NSTextField, discordSecrets?.contains(field) == true {
            discordInvalid = false
            discordStatus?.stringValue = ""
        }
        if obj.object as? NSTextField === minutesField {
            refresh()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === minutesField {
            refresh()
            return
        }
        if discordSecrets?.contains(field) == true {
            discordInvalid = false
            discordStatus?.stringValue = ""
        }
    }

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if let field = control as? NSTextField {
            field.stringValue = fieldEditor.string
        }
        return true
    }

    @objc func keyboardToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        runtime?.setHygiene(keyboard: sender.state == .on)
    }

    @objc func floorToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        runtime?.setHygiene(floor: sender.state == .on)
    }

    @objc func batteryChanged(_ sender: NSSlider) {
        stopRecordingIfNeeded()
        runtime?.setBatteryFloor(Int(sender.doubleValue.rounded()))
        batteryValue?.stringValue = "\(Int(sender.doubleValue.rounded()))%"
    }

    @objc func floorPercentChanged(_ sender: NSSlider) {
        stopRecordingIfNeeded()
        let percent = Int(sender.doubleValue.rounded())
        runtime?.setBrightnessFloorPercent(percent)
        floorPercentValue?.stringValue = "\(percent)%"
    }

    @objc func settleChanged(_ sender: NSSlider) {
        stopRecordingIfNeeded()
        let seconds = AgentSettleGraceChrome.seconds(sliderValue: sender.doubleValue)
        runtime?.setAgentSettleGrace(seconds)
        settleValue?.stringValue = AgentSettleGraceChrome.valueLabel(seconds: seconds)
    }

    @objc func rampChanged(_ sender: NSSegmentedControl) {
        stopRecordingIfNeeded()
        guard let seconds = LidOpenRampChrome.seconds(selectingSegment: sender.selectedSegment) else {
            refresh()
            return
        }
        runtime?.setLidOpenRampSeconds(seconds)
        refresh()
    }

    @objc func thermalToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        runtime?.setThermalAutoOff(sender.state == .on)
        refresh()
    }

    @objc func loginToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        do {
            try LaunchAtLoginController.setEnabled(sender.state == .on)
        } catch {
            UserNotify.post("Couldn't update Launch at login.")
        }
        sender.state = LaunchAtLoginController.isEnabled ? .on : .off
    }

    @objc func quitApp() {
        if runtime?.engaged == true {
            runtime?.setEngaged(false)
        }
        NSApp.terminate(nil)
    }
}
