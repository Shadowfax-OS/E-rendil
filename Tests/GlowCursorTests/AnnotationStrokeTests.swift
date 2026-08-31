import Testing
import Foundation
@testable import GlowCursor

private func rect(of stroke: Stroke?) -> CGRect? {
    guard case .markerRect(let r)? = stroke?.kind else { return nil }
    return r
}

private func points(of stroke: Stroke?) -> [CGPoint]? {
    guard case .freehand(let p)? = stroke?.kind else { return nil }
    return p
}

@Test func reversedDragProducesNonNegativeRectWithCorrectOrigin() {
    let stroke = AnnotationView.makeStroke(
        points: [CGPoint(x: 100, y: 80), CGPoint(x: 20, y: 10)],
        rectMode: true, colorName: "Oranje")
    let r = try! #require(rect(of: stroke))
    #expect(r.width >= 0)
    #expect(r.height >= 0)
    #expect(r.origin == CGPoint(x: 20, y: 10))
    #expect(r.width == 80)
    #expect(r.height == 70)
}

@Test func singlePointYieldsNil() {
    #expect(AnnotationView.makeStroke(points: [CGPoint(x: 5, y: 5)],
                                      rectMode: false, colorName: "Oranje") == nil)
}

@Test func twoPointsFreehandPreservesPoints() {
    let input = [CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)]
    let stroke = AnnotationView.makeStroke(points: input, rectMode: false, colorName: "Blauw")
    #expect(points(of: stroke) == input)
    #expect(stroke?.colorName == "Blauw")
}

@Test func rectModeUsesFirstAndLastPointNotBoundingBoxOfAll() {
    // Middle point is a large outlier; rect must span first→last only.
    let stroke = AnnotationView.makeStroke(
        points: [CGPoint(x: 0, y: 0), CGPoint(x: 500, y: 500), CGPoint(x: 10, y: 10)],
        rectMode: true, colorName: "Oranje")
    let r = try! #require(rect(of: stroke))
    #expect(r == CGRect(x: 0, y: 0, width: 10, height: 10))
}
