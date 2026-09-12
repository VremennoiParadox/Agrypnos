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

    @discardableResult
    func register(_ chord: HotkeyChord) -> Bool {
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
        guard status == noErr, let ref else {
            NSLog("Agrypnos: RegisterEventHotKey failed (%d). Global hotkey is not active.", status)
            return false
        }
        hotKeyRef = ref

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let center = Unmanaged<GlobalHotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    center.onTrigger?()
                }
                return noErr
            },
            1,
            &spec,
            userInfo,
            &handler
        )
        guard handlerStatus == noErr else {
            NSLog("Agrypnos: InstallEventHandler failed (%d). Global hotkey is not active.", handlerStatus)
            unregister()
            return false
        }
        return true
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
