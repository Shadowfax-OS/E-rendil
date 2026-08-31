import AppKit

final class RingLayer: CAShapeLayer {
    override init() {
        super.init()
        fillColor = NSColor.clear.cgColor
        lineWidth = 4
        isHidden = true
    }

    override init(layer: Any) { super.init(layer: layer) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(center: CGPoint?, diameter: CGFloat, color: NSColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard let center else { isHidden = true; return }
        isHidden = false
        strokeColor = color.cgColor
        let r = diameter / 2
        path = CGPath(ellipseIn: CGRect(x: center.x - r, y: center.y - r,
                                        width: diameter, height: diameter), transform: nil)
    }
}
