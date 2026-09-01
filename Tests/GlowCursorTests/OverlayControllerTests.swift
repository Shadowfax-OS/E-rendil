import Testing
import AppKit
import Foundation
@testable import GlowCursor

private func freshDefaults() -> UserDefaults {
    UserDefaults(suiteName: "GlowCursorTests.\(UUID().uuidString)")!
}

private func makeController() -> (EffectsState, StrokeStore, OverlayController) {
    let state = EffectsState(defaults: freshDefaults())
    let store = StrokeStore()
    let controller = OverlayController(state: state, store: store, tracker: CursorTracker())
    return (state, store, controller)
}

@Test @MainActor func resetAllTurnsOffEveryEffectAndClearsStrokes() {
    let (state, store, controller) = makeController()
    state.ringEnabled = true
    state.spotlightEnabled = true
    state.drawModeEnabled = true
    store.add(Stroke(kind: .freehand([.zero, CGPoint(x: 1, y: 1)]), colorName: "Oranje"), on: 1)

    controller.resetAll()

    #expect(state.ringEnabled == false)
    #expect(state.spotlightEnabled == false)
    #expect(state.drawModeEnabled == false)
    #expect(store.isEmpty)
}

@Test @MainActor func resetAllOnCleanStateIsANoOp() {
    let (state, store, controller) = makeController()
    controller.resetAll()
    #expect(state.anyEffectActive == false)
    #expect(store.isEmpty)
}

@Test @MainActor func activeEffectsCallbackTracksWhetherAnyEffectIsOn() {
    let (state, _, controller) = makeController()
    var last: Bool?
    controller.onActiveEffectsChanged = { last = $0 }

    state.ringEnabled = true
    #expect(last == true)

    state.spotlightEnabled = true
    #expect(last == true)

    state.ringEnabled = false
    state.spotlightEnabled = false
    #expect(last == false)
}

@Test @MainActor func annotationViewEscapeCallbackTriggersFullReset() {
    let (state, store, controller) = makeController()
    state.drawModeEnabled = true
    state.ringEnabled = true
    store.add(Stroke(kind: .freehand([.zero, CGPoint(x: 1, y: 1)]), colorName: "Oranje"), on: 1)
    let view = controller.makeAnnotationView(screenID: 1)

    view.onEscape?()

    #expect(state.drawModeEnabled == false)
    #expect(state.ringEnabled == false)
    #expect(store.isEmpty)
}

@Test func layerCenterIsNilWhenEffectDisabled() {
    // De regressie: na resetAll staat ringEnabled=false, maar de cursor zit nog
    // op het scherm. Zonder deze guard tekent applyCursorPosition de ring opnieuw.
    #expect(OverlayController.layerCenter(cursorLocal: CGPoint(x: 5, y: 7), effectEnabled: false) == nil)
}

@Test func layerCenterPassesCursorThroughWhenEffectEnabled() {
    #expect(OverlayController.layerCenter(cursorLocal: CGPoint(x: 5, y: 7), effectEnabled: true) == CGPoint(x: 5, y: 7))
    #expect(OverlayController.layerCenter(cursorLocal: nil, effectEnabled: true) == nil) // cursor op ander scherm
}

@Test @MainActor func activeEffectsCallbackFiresFalseAfterResetAll() {
    let (state, _, controller) = makeController()
    var last: Bool?
    state.drawModeEnabled = true
    controller.onActiveEffectsChanged = { last = $0 }

    controller.resetAll()

    #expect(last == false)
}
