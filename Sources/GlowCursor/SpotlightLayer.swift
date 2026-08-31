import AppKit

final class SpotlightLayer: CALayer {
    static let holeRadius: CGFloat = 110

    private let maskShape = CAShapeLayer()

    var dimOpacity: CGFloat = 0.55 {
        didSet { updateOpacity() }
    }

    // maskShape is een sublaag en erft contentsScale niet; propageer expliciet (Retina).
    override var contentsScale: CGFloat {
        didSet { maskShape.contentsScale = contentsScale }
    }

    override init() {
        super.init()
        backgroundColor = NSColor.black.cgColor
        maskShape.fillRule = .evenOdd
        maskShape.contentsScale = contentsScale
        mask = maskShape
        updateOpacity()
    }

    override init(layer: Any) { super.init(layer: layer) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

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
