import Carbon.HIToolbox
import Foundation
import os.log

enum HotKeyAction: CaseIterable, Hashable, Equatable {
    case toggleRing, toggleSpotlight, toggleDrawMode, undoStroke, clearStrokes
    /// Paniekknop: alle effecten uit en annotaties wissen. Niet chorded — via bare ESC,
    /// en alleen afgevangen zolang er een effect actief is (zie `setEscapeActive`).
    case resetAll
}

/// Manages global hot keys via Carbon for the GlowCursor application.
///
/// **Lifetime Invariant:** The instance MUST be retained for the entire app lifetime.
/// The installed Carbon event handler holds an unretained pointer to `self` via `Unmanaged`,
/// so deallocating this instance while the app runs would dangle the handler and crash on key press.
/// The AppDelegate should hold a reference to this instance for the process lifetime.
/// No explicit `deinit` or teardown is needed.
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

    /// Virtuele keycode van de ESC-toets (kVK_Escape).
    static let escapeKeyCode = UInt32(kVK_Escape)

    /// Carbon-hotkey-id voor de bare-ESC paniekknop. Ligt bewust ná de chorded
    /// ids (1...defaultBindings.count) zodat `action(forID:)` 'm op `.resetAll` mapt.
    static var escapeHotKeyID: UInt32 {
        UInt32(HotKeyAction.allCases.firstIndex(of: .resetAll)! + 1)
    }

    var handler: ((HotKeyAction) -> Void)?

    private let log = Logger(subsystem: "local.glowcursor", category: "hotkeys")
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?

    private static let signature = OSType(0x474C_4F57) // 'GLOW'

    private var escapeHotKeyRef: EventHotKeyRef?

    /// True zolang de bare-ESC paniekknop wordt afgevangen. Buiten deze modus
    /// laten we ESC ongemoeid zodat andere apps 'm normaal krijgen.
    private(set) var isEscapeActive = false

    private func logEventParameterError(_ status: OSStatus) {
        log.error("GetEventParameter mislukt (status \(status)); hotkey-data onbereikbaar")
    }

    func registerAll() {
        guard eventHandlerRef == nil else { return }
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hkID = EventHotKeyID()
            let paramStatus = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if paramStatus != noErr {
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.logEventParameterError(paramStatus)
                return noErr
            }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            if let action = HotKeyManager.action(forID: hkID.id) {
                DispatchQueue.main.async { manager.handler?(action) }
            }
            return noErr
        }, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), &eventHandlerRef)

        if installStatus != noErr {
            log.error("Event-handler-installatie mislukt (status \(installStatus)); hotkeys zijn niet actief")
        }

        for (index, binding) in Self.defaultBindings.enumerated() {
            var ref: EventHotKeyRef?
            let hkID = EventHotKeyID(signature: Self.signature, id: UInt32(index + 1))
            let status = RegisterEventHotKey(binding.keyCode, binding.modifiers, hkID,
                                             GetApplicationEventTarget(), 0, &ref)
            if status != noErr {
                log.error("Hotkey-registratie mislukt voor \(String(describing: binding.action)) (status \(status)); functie blijft via menu bereikbaar")
            }
            hotKeyRefs.append(ref)
        }
    }

    /// Vang bare ESC wel/niet af. Idempotent: dubbel aan/uit is een no-op.
    /// Aangestuurd door OverlayController zodra er een effect aan/uit gaat, zodat
    /// ESC alleen "gestolen" wordt zolang GlowCursor daadwerkelijk iets toont.
    func setEscapeActive(_ active: Bool) {
        guard active != isEscapeActive else { return }
        isEscapeActive = active
        if active {
            var ref: EventHotKeyRef?
            let hkID = EventHotKeyID(signature: Self.signature, id: Self.escapeHotKeyID)
            let status = RegisterEventHotKey(Self.escapeKeyCode, 0, hkID,
                                             GetApplicationEventTarget(), 0, &ref)
            if status != noErr {
                log.error("ESC-hotkey-registratie mislukt (status \(status)); paniekknop blijft via menu bereikbaar")
            }
            escapeHotKeyRef = ref
        } else {
            if let ref = escapeHotKeyRef {
                UnregisterEventHotKey(ref)
            }
            escapeHotKeyRef = nil
        }
    }
}
