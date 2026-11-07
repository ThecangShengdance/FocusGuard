import Carbon.HIToolbox
import Foundation

/// 基于 Carbon 的全局快捷键，不需要辅助功能权限。
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private let id: UInt32

    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        let identifier = GlobalHotKey.nextID
        GlobalHotKey.nextID += 1
        id = identifier
        GlobalHotKey.actions[identifier] = action

        if !GlobalHotKey.handlerInstalled {
            GlobalHotKey.installHandler()
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x46475547), id: identifier)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            GlobalHotKey.actions[identifier] = nil
            return nil
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        GlobalHotKey.actions[id] = nil
    }

    private static func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                guard let event else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                if let action = GlobalHotKey.actions[hotKeyID.id] {
                    action()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        handlerInstalled = true
    }
}
