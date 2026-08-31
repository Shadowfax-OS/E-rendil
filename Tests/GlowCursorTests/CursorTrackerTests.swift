import Testing
import AppKit
@testable import GlowCursor

@Test func startStopTogglesRunning() {
    guard NSScreen.main != nil else { return } // headless: skip
    let t = CursorTracker()
    #expect(t.isRunning == false)
    t.start()
    #expect(t.isRunning == true)
    t.start() // idempotent
    #expect(t.isRunning == true)
    t.stop()
    #expect(t.isRunning == false)
    t.stop() // idempotent
    #expect(t.isRunning == false)
}
