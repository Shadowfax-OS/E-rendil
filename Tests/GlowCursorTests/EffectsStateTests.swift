import Testing
import AppKit
@testable import GlowCursor

private func freshDefaults() -> UserDefaults {
    let d = UserDefaults(suiteName: "GlowCursorTests")!
    d.removePersistentDomain(forName: "GlowCursorTests")
    d.synchronize()
    return d
}

private final class Spy: EffectsStateDelegate {
    var count = 0
    func effectsStateDidChange(_ state: EffectsState) { count += 1 }
}

@Test func defaultsStartCorrect() {
    let s = EffectsState(defaults: freshDefaults())
    #expect(s.ringEnabled == false)
    #expect(s.spotlightEnabled == false)
    #expect(s.drawModeEnabled == false)
    #expect(s.ringDiameter == 60)
    #expect(s.dimOpacity == 0.55)
    #expect(s.colorName == "Oranje")
}

@Test func settingsPersistAcrossInstances() {
    let d = freshDefaults()
    let s1 = EffectsState(defaults: d)
    s1.ringDiameter = 90
    s1.dimOpacity = 0.75
    s1.colorName = "Blauw"
    s1.ringEnabled = true // mag NIET persisten
    let s2 = EffectsState(defaults: d)
    #expect(s2.ringDiameter == 90)
    #expect(s2.dimOpacity == 0.75)
    #expect(s2.colorName == "Blauw")
    #expect(s2.ringEnabled == false)
}

@Test func delegateFiresOnEveryChange() {
    let s = EffectsState(defaults: freshDefaults())
    let spy = Spy()
    s.delegate = spy
    s.ringEnabled = true
    s.spotlightEnabled = true
    s.ringDiameter = 40
    #expect(spy.count == 3)
}

@Test func unknownColorNameFallsBackToOrange() {
    #expect(EffectsState.color(named: "Paars???") == EffectsState.color(named: "Oranje"))
}
