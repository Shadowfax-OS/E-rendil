import Carbon.HIToolbox
import Foundation
import os.log

enum HotKeyAction: CaseIterable, Hashable {
    case toggleRing, toggleSpotlight, toggleDrawMode, undoStroke, clearStrokes
}

final class HotKeyManager {
    static let defaultBindings: [(action: HotKeyAction, keyCode: UInt32, modifiers: UInt32)] = [
        (.toggleRing, UInt32(kVK_ANSI_H), UInt32(controlKey | optionKey)),
        (.toggleSpotlight, UInt32(kVK_ANSI_S), UInt32(controlKey | optionKey)),
        (.toggleDrawMode, UInt32(kVK_ANSI_D), UInt32(controlKey | optionKey)),
        (.undoStroke, UInt32(kVK_ANSI_Z), UInt32(controlKey | optionKey)),
        (.clearStrokes, UInt32(kVK_ANSI_C), UInt32(controlKey | optionKey)),
    ]

    static func action(forID id: UInt32) -> HotKeyAction? {
        let all = HotKeyAction.allCases
        guard id >= 1, id <= UInt32(all.count) else { return nil }
        return all[Int(id) - 1]
    }

    var handler: ((HotKeyAction) -> Void)?

    private let log = Logger(subsystem: "local.glowcursor", category: "hotkeys")
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?

    func registerAll() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            if let action = HotKeyManager.action(forID: hkID.id) {
                DispatchQueue.main.async { manager.handler?(action) }
            }
            return noErr
        }, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), &eventHandlerRef)

        for (index, binding) in Self.defaultBindings.enumerated() {
            var ref: EventHotKeyRef?
            let hkID = EventHotKeyID(signature: OSType(0x474C_4F57) /* 'GLOW' */, id: UInt32(index + 1))
            let status = RegisterEventHotKey(binding.keyCode, binding.modifiers, hkID,
                                             GetApplicationEventTarget(), 0, &ref)
            if status != noErr {
                log.error("Hotkey-registratie mislukt voor \(String(describing: binding.action)) (status \(status)); functie blijft via menu bereikbaar")
            }
            hotKeyRefs.append(ref)
        }
    }
}
