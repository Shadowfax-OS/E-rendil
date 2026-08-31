import Testing
import Foundation
@testable import GlowCursor

private func stroke(_ x: CGFloat) -> Stroke {
    Stroke(kind: .freehand([CGPoint(x: x, y: 0), CGPoint(x: x, y: 10)]), colorName: "Oranje")
}

@Test func strokesAreSeparatedPerScreen() {
    let store = StrokeStore()
    store.add(stroke(1), on: 1)
    store.add(stroke(2), on: 2)
    #expect(store.strokes(on: 1) == [stroke(1)])
    #expect(store.strokes(on: 2) == [stroke(2)])
}

@Test func undoRemovesGloballyLastStroke() {
    let store = StrokeStore()
    store.add(stroke(1), on: 1)
    store.add(stroke(2), on: 2)
    #expect(store.undoLast() == true)
    #expect(store.strokes(on: 2).isEmpty)
    #expect(store.strokes(on: 1) == [stroke(1)])
}

@Test func undoOnEmptyStoreReturnsFalse() {
    #expect(StrokeStore().undoLast() == false)
}

@Test func clearAllEmptiesEverything() {
    let store = StrokeStore()
    store.add(stroke(1), on: 1)
    store.add(stroke(2), on: 2)
    store.clearAll()
    #expect(store.isEmpty)
    #expect(store.strokes(on: 1).isEmpty)
}
