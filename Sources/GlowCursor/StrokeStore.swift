import Foundation

struct Stroke: Equatable {
    enum Kind: Equatable {
        case freehand([CGPoint])
        case markerRect(CGRect)
    }
    let kind: Kind
    let colorName: String
}

final class StrokeStore {
    private var entries: [(screen: ScreenID, stroke: Stroke)] = []

    var isEmpty: Bool { entries.isEmpty }

    func add(_ stroke: Stroke, on screen: ScreenID) {
        entries.append((screen, stroke))
    }

    @discardableResult
    func undoLast() -> Bool {
        guard !entries.isEmpty else { return false }
        entries.removeLast()
        return true
    }

    func clearAll() {
        entries.removeAll()
    }

    func strokes(on screen: ScreenID) -> [Stroke] {
        entries.filter { $0.screen == screen }.map(\.stroke)
    }
}
