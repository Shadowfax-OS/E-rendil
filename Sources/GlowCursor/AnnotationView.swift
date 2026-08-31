import AppKit

final class AnnotationView: NSView {
    private let screenID: ScreenID
    private let store: StrokeStore
    private let state: EffectsState

    var onEscape: (() -> Void)?

    var isDrawModeActive = false {
        didSet {
            window?.invalidateCursorRects(for: self)
            if !isDrawModeActive {
                currentPoints = []
                isRectMode = false
                needsDisplay = true
            }
        }
    }

    private var currentPoints: [CGPoint] = []
    private var isRectMode = false

    init(screenID: ScreenID, store: StrokeStore, state: EffectsState) {
        self.screenID = screenID
        self.store = store
        self.state = state
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var acceptsFirstResponder: Bool { isDrawModeActive }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func cursorUpdate(with event: NSEvent) {
        if isDrawModeActive { NSCursor.crosshair.set() } else { super.cursorUpdate(with: event) }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isDrawModeActive ? super.hitTest(point) : nil
    }

    override func keyDown(with event: NSEvent) {
        guard isDrawModeActive else { super.keyDown(with: event); return }
        if event.keyCode == 53 { // ESC
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isDrawModeActive else { return }
        window?.makeFirstResponder(self)
        isRectMode = event.modifierFlags.contains(.shift)
        currentPoints = [convert(event.locationInWindow, from: nil)]
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDrawModeActive, !currentPoints.isEmpty else { return }
        currentPoints.append(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDrawModeActive, !currentPoints.isEmpty else { return }
        currentPoints.append(convert(event.locationInWindow, from: nil))
        if let stroke = buildStroke(from: currentPoints) {
            store.add(stroke, on: screenID)
        }
        currentPoints = []
        needsDisplay = true
    }

    /// Pure core, unit-testable in isolation.
    static func makeStroke(points: [CGPoint], rectMode: Bool, colorName: String) -> Stroke? {
        guard points.count > 1 else { return nil }
        if rectMode {
            return Stroke(kind: .markerRect(boundingRect(from: points.first!, to: points.last!)),
                          colorName: colorName)
        }
        return Stroke(kind: .freehand(points), colorName: colorName)
    }

    static func boundingRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    func buildStroke(from points: [CGPoint]) -> Stroke? {
        Self.makeStroke(points: points, rectMode: isRectMode, colorName: state.colorName)
    }

    func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        Self.boundingRect(from: a, to: b)
    }

    override func draw(_ dirtyRect: NSRect) {
        for stroke in store.strokes(on: screenID) {
            render(stroke)
        }
        if let inProgress = buildStroke(from: currentPoints) {
            render(inProgress)
        }
    }

    private func render(_ stroke: Stroke) {
        let color = EffectsState.color(named: stroke.colorName)
        switch stroke.kind {
        case .freehand(let points):
            guard points.count > 1 else { return }
            let path = NSBezierPath()
            path.lineWidth = 5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: points[0])
            for p in points.dropFirst() { path.line(to: p) }
            color.setStroke()
            path.stroke()
        case .markerRect(let r):
            color.withAlphaComponent(0.35).setFill()
            r.fill()
        }
    }
}
