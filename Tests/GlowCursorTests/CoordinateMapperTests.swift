import Testing
import Foundation
@testable import GlowCursor

private let mainScreen = CoordinateMapper.ScreenInfo(id: 1, frame: CGRect(x: 0, y: 0, width: 1728, height: 1117))
private let leftScreen = CoordinateMapper.ScreenInfo(id: 2, frame: CGRect(x: -2560, y: 200, width: 2560, height: 1440))

@Test func findsScreenContainingPoint() {
    let hit = CoordinateMapper.screen(containing: CGPoint(x: -100, y: 500), screens: [mainScreen, leftScreen])
    #expect(hit?.id == 2)
}

@Test func pointOnTopEdgeSnapsToNearestScreen() {
    // y == maxY valt buiten frame.contains; moet naar hoofdscherm snappen
    let hit = CoordinateMapper.screen(containing: CGPoint(x: 800, y: 1117), screens: [mainScreen, leftScreen])
    #expect(hit?.id == 1)
}

@Test func emptyScreenListGivesNil() {
    #expect(CoordinateMapper.screen(containing: .zero, screens: []) == nil)
}

@Test func toLocalSubtractsScreenOrigin() {
    let local = CoordinateMapper.toLocal(CGPoint(x: -2000, y: 700), in: leftScreen)
    #expect(local == CGPoint(x: 560, y: 500))
}
