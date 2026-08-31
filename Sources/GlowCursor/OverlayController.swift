import AppKit

final class OverlayController: NSObject {
    private struct PanelBundle {
        let screenID: ScreenID
        let panel: OverlayPanel
        let spotlightLayer: SpotlightLayer
        let spotlightHost: PassthroughHostView
        let ringLayer: RingLayer
        let ringHost: PassthroughHostView
        let annotationView: AnnotationView
    }

    private let state: EffectsState
    private let store: StrokeStore
    private let tracker: CursorTracker
    private var bundles: [PanelBundle] = []

    init(state: EffectsState, store: StrokeStore, tracker: CursorTracker) {
        self.state = state
        self.store = store
        self.tracker = tracker
        super.init()
        state.delegate = self
        tracker.delegate = self
    }

    func makeAnnotationView(screenID: ScreenID) -> AnnotationView {
        let view = AnnotationView(screenID: screenID, store: store, state: state)
        view.onEscape = { [weak self] in
            self?.state.drawModeEnabled = false
        }
        return view
    }

    func rebuildPanels() {
        tracker.stop() // dwing herbinding van de display-link aan het huidige NSScreen.main af (schermwijziging/slaap)
        bundles.forEach { $0.panel.close() }
        bundles = []
        store.clearAll()

        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else { continue }
            let screenID = ScreenID(truncating: number)
            let panel = OverlayPanel(screen: screen)
            let container = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            container.wantsLayer = true

            let spotlightLayer = SpotlightLayer()
            spotlightLayer.frame = container.bounds
            spotlightLayer.contentsScale = screen.backingScaleFactor
            let spotlightHost = PassthroughHostView(hosting: spotlightLayer)
            spotlightHost.frame = container.bounds
            spotlightHost.autoresizingMask = [.width, .height]
            container.addSubview(spotlightHost)

            let annotationView = makeAnnotationView(screenID: screenID)
            annotationView.frame = container.bounds
            annotationView.autoresizingMask = [.width, .height]
            container.addSubview(annotationView)

            let ringLayer = RingLayer()
            ringLayer.frame = container.bounds
            ringLayer.contentsScale = screen.backingScaleFactor
            let ringHost = PassthroughHostView(hosting: ringLayer)
            ringHost.frame = container.bounds
            ringHost.autoresizingMask = [.width, .height]
            container.addSubview(ringHost)

            panel.contentView = container
            panel.orderFrontRegardless()

            bundles.append(PanelBundle(screenID: screenID, panel: panel,
                                       spotlightLayer: spotlightLayer, spotlightHost: spotlightHost,
                                       ringLayer: ringLayer, ringHost: ringHost,
                                       annotationView: annotationView))
        }
        syncFromState()
    }

    func redrawAnnotations() {
        bundles.forEach { $0.annotationView.needsDisplay = true }
    }

    private func syncFromState() {
        let needsTracking = state.ringEnabled || state.spotlightEnabled
        if needsTracking { tracker.start() } else { tracker.stop() }

        for b in bundles {
            b.panel.ignoresMouseEvents = !state.drawModeEnabled
            b.panel.allowsKey = state.drawModeEnabled
            b.panel.acceptsMouseMovedEvents = state.drawModeEnabled
            b.annotationView.isDrawModeActive = state.drawModeEnabled
            b.spotlightHost.isHidden = !state.spotlightEnabled
            b.ringHost.isHidden = !state.ringEnabled
            b.spotlightLayer.dimOpacity = state.dimOpacity
        }
        applyCursorPosition(NSEvent.mouseLocation)
        if state.drawModeEnabled { makeKeyPanelOnMainScreen() }
        redrawAnnotations()
    }

    private func makeKeyPanelOnMainScreen() {
        let mainNumber = (NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
            .map { ScreenID(truncating: $0) }
        let bundle = bundles.first(where: { $0.screenID == mainNumber }) ?? bundles.first
        guard let bundle else { return }
        bundle.panel.makeKey()
        bundle.panel.makeFirstResponder(bundle.annotationView)
    }

    private func applyCursorPosition(_ global: CGPoint) {
        let infos = bundles.map { CoordinateMapper.ScreenInfo(id: $0.screenID, frame: $0.panel.frame) }
        let target = CoordinateMapper.screen(containing: global, screens: infos)
        for b in bundles {
            if let target, b.screenID == target.id {
                let local = CoordinateMapper.toLocal(global, in: target)
                b.ringLayer.update(center: local, diameter: state.ringDiameter, color: state.color)
                b.spotlightLayer.update(holeCenter: local)
            } else {
                b.ringLayer.update(center: nil, diameter: state.ringDiameter, color: state.color)
                b.spotlightLayer.update(holeCenter: nil)
            }
        }
    }
}

extension OverlayController: EffectsStateDelegate {
    func effectsStateDidChange(_ state: EffectsState) { syncFromState() }
}

extension OverlayController: CursorTrackerDelegate {
    func cursorTracker(_ tracker: CursorTracker, didMoveTo globalPoint: CGPoint) {
        applyCursorPosition(globalPoint)
    }
}
