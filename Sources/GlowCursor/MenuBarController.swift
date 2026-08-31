import AppKit

final class MenuBarController: NSObject, NSMenuDelegate {
    private let state: EffectsState
    private let store: StrokeStore
    private let controller: OverlayController
    private let statusItem: NSStatusItem

    init(state: EffectsState, store: StrokeStore, controller: OverlayController) {
        self.state = state
        self.store = store
        self.controller = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "cursorarrow.rays",
                                           accessibilityDescription: "GlowCursor")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // Geen keyEquivalents op menu-items: de Carbon-hotkeys (HotKeyManager) zijn
        // app-globaal en zouden anders dubbel vuren wanneer de app toevallig actief is.
        // De sneltoets staat als hint in de titel.
        menu.addItem(toggleItem("Highlight-ring  (⌃⌥H)", on: state.ringEnabled, action: #selector(toggleRing)))
        menu.addItem(toggleItem("Spotlight  (⌃⌥S)", on: state.spotlightEnabled, action: #selector(toggleSpotlight)))
        menu.addItem(toggleItem("Tekenmodus  (⌃⌥D)", on: state.drawModeEnabled, action: #selector(toggleDraw)))
        menu.addItem(.separator())

        let colorMenu = NSMenu()
        for (name, _) in EffectsState.palette {
            let item = NSMenuItem(title: name, action: #selector(pickColor(_:)), keyEquivalent: "")
            item.target = self
            item.state = (name == state.colorName) ? .on : .off
            colorMenu.addItem(item)
        }
        let colorItem = NSMenuItem(title: "Kleur", action: nil, keyEquivalent: "")
        colorItem.submenu = colorMenu
        menu.addItem(colorItem)

        let sizeMenu = NSMenu()
        for diameter in [40.0, 60.0, 90.0] {
            let item = NSMenuItem(title: "\(Int(diameter)) pt", action: #selector(pickDiameter(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: diameter)
            item.state = (CGFloat(diameter) == state.ringDiameter) ? .on : .off
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "Ringdiameter", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let dimMenu = NSMenu()
        for (label, value) in [("Licht", 0.35), ("Middel", 0.55), ("Sterk", 0.75)] {
            let item = NSMenuItem(title: label, action: #selector(pickDim(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: value)
            item.state = (CGFloat(value) == state.dimOpacity) ? .on : .off
            dimMenu.addItem(item)
        }
        let dimItem = NSMenuItem(title: "Dim-sterkte", action: nil, keyEquivalent: "")
        dimItem.submenu = dimMenu
        menu.addItem(dimItem)

        menu.addItem(.separator())
        let undo = NSMenuItem(title: "Ongedaan maken  (⌃⌥Z)", action: #selector(undoStroke), keyEquivalent: "")
        undo.target = self
        menu.addItem(undo)
        let clear = NSMenuItem(title: "Wis annotaties  (⌃⌥C)", action: #selector(clearStrokes), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Stop GlowCursor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func toggleItem(_ title: String, on: Bool, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        return item
    }

    @objc private func toggleRing() { state.ringEnabled.toggle() }
    @objc private func toggleSpotlight() { state.spotlightEnabled.toggle() }
    @objc private func toggleDraw() { state.drawModeEnabled.toggle() }

    @objc private func pickColor(_ sender: NSMenuItem) { state.colorName = sender.title }

    @objc private func pickDiameter(_ sender: NSMenuItem) {
        if let n = sender.representedObject as? NSNumber { state.ringDiameter = CGFloat(n.doubleValue) }
    }

    @objc private func pickDim(_ sender: NSMenuItem) {
        if let n = sender.representedObject as? NSNumber { state.dimOpacity = CGFloat(n.doubleValue) }
    }

    @objc private func undoStroke() {
        if store.undoLast() {
            controller.redrawAnnotations()
        }
    }

    @objc private func clearStrokes() {
        store.clearAll()
        controller.redrawAnnotations()
    }
}
