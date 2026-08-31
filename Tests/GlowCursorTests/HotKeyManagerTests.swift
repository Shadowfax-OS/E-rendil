import Testing
@testable import GlowCursor

@Test func everyActionHasExactlyOneBinding() {
    let actions = HotKeyManager.defaultBindings.map(\.action)
    #expect(Set(actions).count == HotKeyAction.allCases.count)
    #expect(actions.count == HotKeyAction.allCases.count)
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
    #expect(HotKeyManager.action(forID: 6) == nil)
}
