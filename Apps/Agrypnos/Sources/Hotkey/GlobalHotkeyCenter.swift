import AppKit
import Carbon

#if canImport(AgrypnosCore)
import AgrypnosCore
#endif

final class GlobalHotkeyCenter {
    private var hotKeyRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onTrigger: (() -> Void)?

    deinit {
        unregister()
    }

    func register(_ chord: HotkeyChord) {
        unregister()
        var hotKeyID = EventHotKeyID(signature: 0x41475259, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            chord.keyCode,
            chord.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr else { return }
        hotKeyRef = ref

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                Unmanaged<GlobalHotkeyCenter>.fromOpaque(userData).takeUnretainedValue().onTrigger?()
                return noErr
            },
            1,
            &spec,
            userInfo,
            &handler
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handler {
            RemoveEventHandler(handler)
            self.handler = nil
        }
    }
}
