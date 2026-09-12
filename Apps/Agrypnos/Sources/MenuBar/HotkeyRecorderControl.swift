import AppKit

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

/// Rounded shortcut button that captures the next chord. Esc cancels.
final class HotkeyRecorderControl: NSObject {
    let button: NSButton
    private var monitor: Any?
    private(set) var isRecording = false
    var onChord: ((HotkeyChord) -> Void)?
    var onSessionChanged: (() -> Void)?

    override init() {
        button = NSButton(title: HotkeyChord.defaultToggle.display, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.setButtonType(.momentaryPushIn)
        super.init()
        button.target = self
        button.action = #selector(clicked)
        button.setAccessibilityLabel(AgrypnosCopy.shortcutLabel)
    }

    func apply(title: String) {
        button.title = title
        button.sizeToFit()
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    @objc private func clicked() {
        if isRecording {
            stop()
            onSessionChanged?()
        } else {
            start()
        }
    }

    private func start() {
        guard !isRecording else { return }
        isRecording = true
        onSessionChanged?()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard isRecording else { return event }
        if event.isARepeat { return nil }
        let flags = event.modifierFlags
        let capture = HotkeyCapture.from(
            keyCode: UInt32(event.keyCode),
            option: flags.contains(.option),
            command: flags.contains(.command),
            shift: flags.contains(.shift),
            control: flags.contains(.control)
        )
        switch capture {
        case .ignore:
            return nil
        case .cancel:
            stop()
            onSessionChanged?()
            return nil
        case .chord(let chord):
            stop()
            onSessionChanged?()
            onChord?(chord)
            return nil
        }
    }
}
