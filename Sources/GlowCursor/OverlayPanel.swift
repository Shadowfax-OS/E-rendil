import AppKit

final class OverlayPanel: NSPanel {
    var allowsKey = false
    override var canBecomeKey: Bool { allowsKey }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        sharingType = .readOnly          // zichtbaar in schermdeling/-opname
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true        // click-through; OverlayController zet dit uit in tekenmodus
        hidesOnDeactivate = false        // NSPanel-default is true; zou overlay laten verdwijnen
        isReleasedWhenClosed = false
    }
}
