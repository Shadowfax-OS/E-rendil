import AppKit
import QuartzCore

protocol CursorTrackerDelegate: AnyObject {
    func cursorTracker(_ tracker: CursorTracker, didMoveTo globalPoint: CGPoint)
}

final class CursorTracker {
    weak var delegate: CursorTrackerDelegate?
    private var displayLink: CADisplayLink?

    var isRunning: Bool { displayLink != nil }

    deinit { stop() }

    func start() {
        guard displayLink == nil, let screen = NSScreen.main else { return }
        let link = screen.displayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        delegate?.cursorTracker(self, didMoveTo: NSEvent.mouseLocation)
    }
}
