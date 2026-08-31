import AppKit

final class SpotlightLayer: CALayer {
    static let holeRadius: CGFloat = 110

    private let maskShape = CAShapeLayer()

    var dimOpacity: CGFloat = 0.55 {
        didSet { updateOpacity() }
    }

    override init() {
        super.init()
        backgroundColor = NSColor.black.cgColor
        maskShape.fillRule = .evenOdd
        mask = maskShape
        updateOpacity()
    }

    override init(layer: Any) { super.init(layer: layer) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func updateOpacity() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        opacity = Float(dimOpacity)
        CATransaction.commit()
    }

    /// nil = volledig dimmen (cursor op ander scherm); anders gat rond center.
    func update(holeCenter: CGPoint?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        maskShape.frame = bounds
        let path = CGMutablePath()
        path.addRect(bounds)
        if let c = holeCenter {
            let r = Self.holeRadius
            path.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
        maskShape.path = path
    }
}
