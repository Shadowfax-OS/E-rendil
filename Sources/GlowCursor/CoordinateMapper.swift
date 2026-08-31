import Foundation

typealias ScreenID = UInt32

enum CoordinateMapper {
    struct ScreenInfo: Equatable {
        let id: ScreenID
        let frame: CGRect
    }

    static func screen(containing point: CGPoint, screens: [ScreenInfo]) -> ScreenInfo? {
        if let hit = screens.first(where: { $0.frame.contains(point) }) { return hit }
        return screens.min { squaredDistance(from: point, to: $0.frame) < squaredDistance(from: point, to: $1.frame) }
    }

    static func toLocal(_ point: CGPoint, in screen: ScreenInfo) -> CGPoint {
        CGPoint(x: point.x - screen.frame.minX, y: point.y - screen.frame.minY)
    }

    private static func squaredDistance(from p: CGPoint, to r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return dx * dx + dy * dy
    }
}
