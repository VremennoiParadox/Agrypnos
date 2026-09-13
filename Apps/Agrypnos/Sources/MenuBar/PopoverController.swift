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
    private weak var runtime: WatchRuntime?
    private var clickMonitor: Any?
    private var countdown: Timer?

    var watchSwitch: NSSwitch!
    var caption: NSTextField!
    var mainCard: CardView!
    var headerMark: NSImageView!
    var durationControl: NSSegmentedControl!
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
    var loginSwitch: NSSwitch!
    var hotkeyHint: NSTextField!
    let recorder = HotkeyRecorderControl()
    var hotkeyButtonY: CGFloat = 0
    var contentWidth: CGFloat = 0

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
        applyDuration(DurationPickerChrome.make(duration: runtime.preferences.duration))
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

    func applyDuration(_ chrome: DurationPickerChrome) {
        guard let durationControl else { return }
        for (index, title) in chrome.segmentTitles.enumerated() where index < durationControl.segmentCount {
            durationControl.setLabel(title, forSegment: index)
        }
        durationControl.selectedSegment = chrome.selectedSegment
        if minutesField?.currentEditor() == nil {
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

    @objc func watchToggled(_ sender: NSSwitch) {
        stopRecordingIfNeeded()
        runtime?.setEngaged(sender.state == .on)
        refresh()
    }

    @objc func durationChanged(_ sender: NSSegmentedControl) {
        stopRecordingIfNeeded()
        guard let option = DurationPickerChrome.duration(selectingSegment: sender.selectedSegment) else {
            minutesField?.window?.makeFirstResponder(minutesField)
            refresh()
            return
        }
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
