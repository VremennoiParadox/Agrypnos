// Run Scripts/check-popover-anchor-macos.sh.
// Real animated status/popover UI; kernel, hygiene and network actions are mocked.
import AppKit

@MainActor
final class MotionDelegate: NSObject, WatchRuntimeDelegate, NSApplicationDelegate {
    let status: StatusItemController
    init(_ status: StatusItemController) { self.status = status }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { .terminateCancel }
    func watchRuntimeDidChange(_ runtime: WatchRuntime) { status.refresh() }
}

@main
struct PopoverAnchorCheck {
    @MainActor static func main() {
        setbuf(stdout, nil)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        // Drive AppKit's normal event/update cycle while tasks exercise controls.
        let events = Timer(timeInterval: 0.02, repeats: true) { _ in
            let event = NSEvent.otherEvent(with: .applicationDefined, location: .zero,
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0)!
            NSApp.postEvent(event, atStart: false)
        }
        RunLoop.main.add(events, forMode: .common)
        Task { @MainActor in
            do {
                try await checkMotion()
                exit(0)
            } catch {
                print(error)
                exit(1)
            }
        }
        // AppKit can stop the async-main CFRunLoop during popover activation.
        // Use the real application event loop, as the shipped app does.
        app.run()
        exit(1)
    }

    @MainActor static func checkMotion() async throws {
        var kernelHeld = false
        let defaults = UserDefaults(suiteName: "agrypnos-anchor-check-" + UUID().uuidString)!
        let runtime = WatchRuntime(store: PreferencesStore(defaults: defaults),
            readLid: { false }, readKernel: { kernelHeld ? .held : .clear },
            setKernel: { kernelHeld = $0; return .ok },
            runCommand: { _, _ in (0, "", "") }, postIdle: { _, _ in }, notify: { _ in })
        runtime.hygieneDevices = HygieneDevices(canSetBrightness: { false }, brightness: { nil },
            setBrightness: { _ in }, keyboard: { nil }, setKeyboard: { _ in }, wakeDisplay: {})
        runtime.engine.preferences.duration = .oneHour
        let controller = PopoverController(runtime: runtime)
        let status = StatusItemController(runtime: runtime, popover: controller)
        let delegate = MotionDelegate(status)
        runtime.delegate = delegate
        NSApp.delegate = delegate
        defer { withExtendedLifetime(delegate) {} }
        func findButton(_ view: NSView) -> NSStatusBarButton? {
            if let button = view as? NSStatusBarButton, button.target === status { return button }
            return view.subviews.compactMap(findButton).first
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        let button = NSApp.windows.compactMap { $0.contentView.flatMap(findButton) }.first!
        defer { controller.close() }
        var failures: [String] = []
        func waitForClose() async throws {
            for _ in 0..<100 where controller.popover.isShown {
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            if controller.popover.isShown { failures.append("Popover did not close") }
        }
        func openAndCheckMotion() async throws {
            button.performClick(nil)
            for _ in 0..<100 where !controller.popover.isShown {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            guard controller.popover.isShown else {
                throw NSError(domain: "PopoverAnchorCheck", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Popover did not open"])
            }
            let initial = controller.popoverRoot.window!.frame
            for _ in 0..<40 {
                if controller.popoverRoot.window!.frame != initial {
                    failures.append("Popover moved/resized during opening")
                    break
                }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }
        try await openAndCheckMotion()
        for section in [PopoverSection.watch, .general] {
            controller.applySection(section)
            try await Task.sleep(nanoseconds: 400_000_000)
            let initial = controller.popoverRoot.window!.frame
            let content = controller.popover.contentSize
            let initialEye = button.window!.convertToScreen(
                button.convert(button.cell!.imageRect(forBounds: button.bounds), to: nil))
            var worst = 0.0
            for duration in [DurationOption.indefinite, .oneHour, .threeHours,
                             .customMinutes(33), .untilAgentsSettle] {
                runtime.setDuration(duration)
                for on in [true, false] {
                    controller.watchSwitch.state = on ? .on : .off
                    controller.watchToggled(controller.watchSwitch)
                    if !button.title.isEmpty { failures.append("Status item shows text") }
                    if button.imagePosition != .imageOnly || button.bounds.width > NSStatusBar.system.thickness + 2 {
                        failures.append("Status item expanded")
                    }
                    let expected: NSColor
                    if !on { expected = .secondaryLabelColor }
                    else if duration == .indefinite { expected = .systemBlue }
                    else if duration == .untilAgentsSettle { expected = .systemPurple }
                    else { expected = AgrypnosPalette.gold }
                    if button.contentTintColor != expected { failures.append("Wrong mode color") }
                    for _ in 0..<30 {
                        let frame = controller.popoverRoot.window!.frame
                        let eye = button.window!.convertToScreen(
                            button.convert(button.cell!.imageRect(forBounds: button.bounds), to: nil))
                        if abs(eye.midX - initialEye.midX) > 1 || abs(eye.midY - initialEye.midY) > 1 {
                            failures.append("\(section) toggle moved the eye")
                            break
                        }
                        worst = max(worst, abs(frame.minX - initial.minX), abs(frame.minY - initial.minY))
                        if frame.size != initial.size || controller.popover.contentSize != content {
                            failures.append("\(section) toggle changed popover height/size")
                            break
                        }
                        try await Task.sleep(nanoseconds: 10_000_000)
                    }
                    if !controller.popover.isShown { failures.append("Toggle closed the popover: \(section) \(duration.segmentTitle) \(on)") }
                }
            }
            print("\(section): maximum window travel \(worst) pt; height \(initial.height)")
            if worst > 1 { failures.append("\(section) toggle moved window \(worst) pt") }
        }
        runtime.setEngaged(true)
        controller.close()
        try await waitForClose()
        if !button.title.isEmpty || button.bounds.width > NSStatusBar.system.thickness + 2 {
            failures.append("Closing armed watch expanded the status item")
        }
        try await openAndCheckMotion()
        runtime.setEngaged(false)
        controller.close()
        try await waitForClose()
        if !button.title.isEmpty { failures.append("Closing off watch shows text") }
        if !failures.isEmpty {
            print(failures.joined(separator: "\n"))
            throw NSError(domain: "PopoverAnchorCheck", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "\(failures.count) motion checks failed"])
        }
        print("Animated popover window checks passed")
    }
}
