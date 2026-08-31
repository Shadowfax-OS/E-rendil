import AppKit

/// Layer-hosting view die nooit muis-events opeist, zodat kliks in
/// tekenmodus bij de AnnotationView eronder/erboven terechtkomen.
final class PassthroughHostView: NSView {
    init(hosting layer: CALayer) {
        super.init(frame: .zero)
        self.layer = layer
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
