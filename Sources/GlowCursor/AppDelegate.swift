import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = EffectsState()
    let store = StrokeStore()
    let tracker = CursorTracker()
    private(set) var controller: OverlayController!
    private let hotKeys = HotKeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = OverlayController(state: state, store: store, tracker: tracker)
        controller.rebuildPanels()

        hotKeys.handler = { [weak self] action in
            guard let self else { return }
            switch action {
            case .toggleRing: state.ringEnabled.toggle()
            case .toggleSpotlight: state.spotlightEnabled.toggle()
            case .toggleDrawMode: state.drawModeEnabled.toggle()
            case .undoStroke:
                if store.undoLast() { controller.redrawAnnotations() }
            case .clearStrokes:
                store.clearAll()
                controller.redrawAnnotations()
            }
        }
        hotKeys.registerAll()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    @objc private func screensChanged() {
        controller.rebuildPanels()
    }
}
