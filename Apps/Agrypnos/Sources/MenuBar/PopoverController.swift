import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

enum PopoverMetrics {
    static let width: CGFloat = 328
    static let height: CGFloat = 548
    static let pad: CGFloat = 16
    static let inset: CGFloat = 12
}

@MainActor
final class PopoverController: NSObject {
    let popover = NSPopover()
    private weak var runtime: WatchRuntime?
    private var clickMonitor: Any?
    private var countdown: Timer?

    private var watchSwitch: NSSwitch!
    private var caption: NSTextField!
    private var mainCard: CardView!
    private var headerMark: NSImageView!
    private var durationControl: NSSegmentedControl!
    private var durationHint: NSTextField!
    private var displaySwitch: NSSwitch!
    private var keyboardSwitch: NSSwitch!
    private var floorSwitch: NSSwitch!
    private var batterySlider: NSSlider!
    private var batteryValue: NSTextField!
    private var loginSwitch: NSSwitch!

    init(runtime: WatchRuntime) {
        self.runtime = runtime
        super.init()
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentSize = NSSize(width: PopoverMetrics.width, height: PopoverMetrics.height)
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
        caption?.stringValue = on
            ? AgrypnosCopy.captionOn(floor: runtime.preferences.batteryFloorPercent)
            : AgrypnosCopy.captionOff
        durationControl?.selectedSegment = segment(for: runtime.preferences.duration)
        durationHint?.stringValue = hint(for: runtime)
        displaySwitch?.state = runtime.preferences.forceDisplaySleep ? .on : .off
        keyboardSwitch?.state = runtime.preferences.keyboardBacklightOff ? .on : .off
        floorSwitch?.state = runtime.preferences.applyBrightnessFloor ? .on : .off
        batterySlider?.doubleValue = Double(runtime.preferences.batteryFloorPercent)
        batteryValue?.stringValue = "\(runtime.preferences.batteryFloorPercent)%"
        loginSwitch?.state = LaunchAtLoginController.isEnabled ? .on : .off
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

        let g1 = card(NSRect(x: pad, y: 42, width: contentW, height: 80))
        mainCard = g1
        let keep = LabelFactory.make(AgrypnosCopy.keepWatch, font: .systemFont(ofSize: 13), color: .labelColor)
        keep.frame = NSRect(x: ci, y: ci, width: cw - swW - 8, height: 22)
        g1.addSubview(keep)
        watchSwitch = NSSwitch()
        watchSwitch.target = self
        watchSwitch.action = #selector(watchToggled(_:))
        watchSwitch.frame = NSRect(x: contentW - ci - swW, y: ci + 1, width: swW, height: swH)
        g1.addSubview(watchSwitch)
        caption = LabelFactory.make("", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        caption.frame = NSRect(x: ci, y: ci + 28, width: cw, height: 36)
        caption.usesSingleLineMode = false
        caption.maximumNumberOfLines = 2
        caption.lineBreakMode = .byWordWrapping
        g1.addSubview(caption)

        let g2 = card(NSRect(x: pad, y: 132, width: contentW, height: 78))
        let durationLabel = LabelFactory.make(AgrypnosCopy.durationLabel, font: .systemFont(ofSize: 13), color: .labelColor)
        durationLabel.frame = NSRect(x: ci, y: ci + 2, width: 90, height: 22)
        g2.addSubview(durationLabel)
        let titles = DurationOption.allCases.map(\.segmentTitle)
        durationControl = NSSegmentedControl(labels: titles, trackingMode: .selectOne, target: self, action: #selector(durationChanged(_:)))
        durationControl.selectedSegment = 0
        durationControl.sizeToFit()
        let segW = min(max(durationControl.frame.width, 168), cw - 4)
        durationControl.frame = NSRect(x: contentW - ci - segW, y: ci, width: segW, height: 24)
        g2.addSubview(durationControl)
        durationHint = LabelFactory.make("", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        durationHint.frame = NSRect(x: ci, y: ci + 36, width: cw, height: 26)
        durationHint.usesSingleLineMode = false
        durationHint.maximumNumberOfLines = 2
        g2.addSubview(durationHint)

        let g3 = card(NSRect(x: pad, y: 220, width: contentW, height: 108))
        addHygieneRow(g3, y: 10, title: AgrypnosCopy.displaySleep, switchSlot: &displaySwitch, action: #selector(displayToggled(_:)), contentW: contentW, ci: ci, cw: cw, swW: swW, swH: swH)
        addHygieneRow(g3, y: 42, title: AgrypnosCopy.keyboardDark, switchSlot: &keyboardSwitch, action: #selector(keyboardToggled(_:)), contentW: contentW, ci: ci, cw: cw, swW: swW, swH: swH)
        addHygieneRow(g3, y: 74, title: AgrypnosCopy.brightnessFloor, switchSlot: &floorSwitch, action: #selector(floorToggled(_:)), contentW: contentW, ci: ci, cw: cw, swW: swW, swH: swH)

        let g4 = card(NSRect(x: pad, y: 338, width: contentW, height: 88))
        let batt = LabelFactory.make(AgrypnosCopy.batteryFloor, font: .systemFont(ofSize: 13), color: .labelColor)
        batt.frame = NSRect(x: ci, y: ci, width: cw - 54, height: 18)
        g4.addSubview(batt)
        batteryValue = LabelFactory.make("15%", font: .systemFont(ofSize: 13, weight: .semibold), color: .secondaryLabelColor)
        batteryValue.alignment = .right
        batteryValue.frame = NSRect(x: contentW - ci - 54, y: ci, width: 54, height: 18)
        g4.addSubview(batteryValue)
        batterySlider = NSSlider(value: 15, minValue: 5, maxValue: 50, target: self, action: #selector(batteryChanged(_:)))
        batterySlider.isContinuous = true
        batterySlider.frame = NSRect(x: ci, y: ci + 26, width: cw, height: 20)
        g4.addSubview(batterySlider)
        let minHint = LabelFactory.make("5%", font: .systemFont(ofSize: 10), color: .tertiaryLabelColor)
        minHint.frame = NSRect(x: ci, y: ci + 50, width: 34, height: 13)
        g4.addSubview(minHint)
        let maxHint = LabelFactory.make("50%", font: .systemFont(ofSize: 10), color: .tertiaryLabelColor)
        maxHint.alignment = .right
        maxHint.frame = NSRect(x: contentW - ci - 34, y: ci + 50, width: 34, height: 13)
        g4.addSubview(maxHint)

        let g5 = card(NSRect(x: pad, y: 436, width: contentW, height: 44))
        let login = LabelFactory.make(AgrypnosCopy.launchAtLogin, font: .systemFont(ofSize: 13), color: .labelColor)
        login.frame = NSRect(x: ci, y: 11, width: cw - swW - 8, height: 22)
        g5.addSubview(login)
        loginSwitch = NSSwitch()
        loginSwitch.target = self
        loginSwitch.action = #selector(loginToggled(_:))
        loginSwitch.frame = NSRect(x: contentW - ci - swW, y: 12, width: swW, height: swH)
        g5.addSubview(loginSwitch)

        let hotkey = LabelFactory.make(AgrypnosCopy.hotkeyHint(.defaultToggle), font: .systemFont(ofSize: 11), color: .tertiaryLabelColor)
        hotkey.frame = NSRect(x: pad, y: 490, width: contentW - 100, height: 16)
        root.addSubview(hotkey)

        let quit = NSButton(title: AgrypnosCopy.quit, target: self, action: #selector(quitApp))
        quit.bezelStyle = .rounded
        quit.controlSize = .regular
        quit.sizeToFit()
        quit.frame = NSRect(x: W - pad - quit.frame.width, y: 512, width: quit.frame.width, height: quit.frame.height)
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

    private func segment(for option: DurationOption) -> Int {
        DurationOption.allCases.firstIndex(of: option) ?? 0
    }

    private func hint(for runtime: WatchRuntime) -> String {
        switch runtime.preferences.duration {
        case .untilAgentsSettle:
            return AgrypnosCopy.agentsHint
        case .oneHour, .threeHours:
            if let end = runtime.engine.timerEnd, runtime.engaged {
                let remaining = max(0, Int(end.timeIntervalSinceNow.rounded()))
                let m = remaining / 60
                let s = remaining % 60
                return String(format: "Auto-off in %d:%02d", m, s)
            }
            return "Then the watch stands down."
        case .indefinite:
            return "Until you say otherwise — plus safety nets."
        }
    }

    private func startCountdown() {
        countdown?.invalidate()
        countdown = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    @objc private func watchToggled(_ sender: NSSwitch) {
        runtime?.setEngaged(sender.state == .on)
        refresh()
    }

    @objc private func durationChanged(_ sender: NSSegmentedControl) {
        let option = DurationOption.allCases[sender.selectedSegment]
        runtime?.setDuration(option)
        refresh()
    }

    @objc private func displayToggled(_ sender: NSSwitch) {
        runtime?.setHygiene(display: sender.state == .on)
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
