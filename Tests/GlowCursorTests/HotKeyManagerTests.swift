import Testing
@testable import GlowCursor

/// Actions that are triggered by a chorded ⌃⌥ global hot key.
private let chordedActions = HotKeyAction.allCases.filter { $0 != .resetAll }

@Test func everyChordedActionHasExactlyOneBinding() {
    let actions = HotKeyManager.defaultBindings.map(\.action)
    #expect(Set(actions).count == chordedActions.count)
    #expect(actions.count == chordedActions.count)
}

@Test func resetAllHasNoChordedBinding() {
    #expect(!HotKeyManager.defaultBindings.map(\.action).contains(.resetAll))
}

@Test func allBindingsUseControlOption() {
    for b in HotKeyManager.defaultBindings {
        #expect(b.modifiers == 0x1800) // controlKey(0x1000) | optionKey(0x0800)
    }
}

@Test func keyCodesMatchSpec() {
    func code(_ a: HotKeyAction) -> UInt32? {
        HotKeyManager.defaultBindings.first { $0.action == a }?.keyCode
    }
    #expect(code(.toggleRing) == 0x04)      // H
    #expect(code(.toggleSpotlight) == 0x01) // S
    #expect(code(.toggleDrawMode) == 0x02)  // D
    #expect(code(.undoStroke) == 0x06)      // Z
    #expect(code(.clearStrokes) == 0x08)    // C
}

@Test func idMappingRoundTrips() {
    #expect(HotKeyManager.action(forID: 1) == .toggleRing)
    #expect(HotKeyManager.action(forID: 5) == .clearStrokes)
    #expect(HotKeyManager.action(forID: 0) == nil)
    #expect(HotKeyManager.action(forID: 99) == nil)
}

@Test func bindingsOrderMatchesChordedActionCases() {
    #expect(HotKeyManager.defaultBindings.map(\.action) == chordedActions)
}

@Test func escapeHotKeyMapsToResetAll() {
    #expect(HotKeyManager.escapeKeyCode == 0x35) // kVK_Escape
    #expect(HotKeyManager.action(forID: HotKeyManager.escapeHotKeyID) == .resetAll)
}

@Test func escapeHotKeyIDDoesNotCollideWithChordedBindings() {
    let chordedIDs = 1...UInt32(HotKeyManager.defaultBindings.count)
    #expect(!chordedIDs.contains(HotKeyManager.escapeHotKeyID))
}

@Test func setEscapeActiveTogglesAndIsIdempotent() {
    let m = HotKeyManager()
    #expect(m.isEscapeActive == false)

    m.setEscapeActive(true)
    #expect(m.isEscapeActive == true)
    m.setEscapeActive(true) // geen dubbele registratie
    #expect(m.isEscapeActive == true)

    m.setEscapeActive(false)
    #expect(m.isEscapeActive == false)
    m.setEscapeActive(false) // geen dubbele deregistratie
    #expect(m.isEscapeActive == false)
}
