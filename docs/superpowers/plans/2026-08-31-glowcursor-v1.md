# GlowCursor v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Een macOS menubar-app die systeembreed een cursor-highlight-ring, spotlight-dimming en live schermannotaties (freehand + marker-rechthoek) levert, bediend via globale sneltoetsen.

**Architecture:** Eén borderless non-activating `NSPanel` per scherm met drie gestapelde subviews (spotlight-dim, annotaties, ring). Cursor wordt frame-synchroon gepolld via `CADisplayLink` + `NSEvent.mouseLocation` (nul permissies). Globale sneltoetsen via Carbon `RegisterEventHotKey`. Puur AppKit, geen dependencies.

**Tech Stack:** Swift 6.3 toolchain (taalmodus Swift 5), Swift Package Manager, AppKit, Core Animation, Carbon.HIToolbox, Swift Testing (`import Testing`). Geen Xcode — alleen Command Line Tools.

**Spec:** `docs/superpowers/specs/2026-08-31-glowcursor-design.md`

## Global Constraints

- Werkdirectory voor alle commando's: `~/Projects/GlowCursor`.
- Platform-minimum: macOS 14 (`platforms: [.macOS(.v14)]`); ontwikkelmachine draait macOS 26, Apple Silicon.
- Geen Xcode: alles via `swift build` / `swift test` / `swift run`; geen `.xcodeproj` aanmaken.
- Geen externe dependencies in `Package.swift`.
- Geen SwiftUI; puur AppKit.
- Nul TCC-permissies: geen `CGEventTap`, geen `NSEvent.addGlobalMonitorForEvents`, geen screen capture API's.
- Alle targets in taalmodus Swift 5: `swiftSettings: [.swiftLanguageMode(.v5)]` (voorkomt Swift 6 strict-concurrency-fouten met AppKit/Carbon-callbacks).
- Per-frame CALayer-updates altijd binnen `CATransaction.begin()` + `CATransaction.setDisableActions(true)` + `CATransaction.commit()`.
- Effecten starten altijd uit bij app-start; alleen kleur/diameter/dim-opacity worden gepersisteerd.
- Commit na elke taak met het aangegeven bericht.

---

### Task 1: Projectscaffold

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/GlowCursor/main.swift`
- Test: `Tests/GlowCursorTests/SmokeTests.swift`

**Interfaces:**
- Consumes: —
- Produces: buildbaar SPM-project; `swift test` draait Swift Testing-tests. Latere taken voegen bestanden toe aan `Sources/GlowCursor/`.

- [ ] **Step 1: Schrijf Package.swift**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "GlowCursor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GlowCursor",
            path: "Sources/GlowCursor",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "GlowCursorTests",
            dependencies: ["GlowCursor"],
            path: "Tests/GlowCursorTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
```

- [ ] **Step 2: Schrijf .gitignore**

```
.build/
build/
.DS_Store
```

- [ ] **Step 3: Schrijf main.swift (minimale app-entry)**

```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
// AppDelegate wordt in Task 8 aangesloten.
app.run()
```

- [ ] **Step 4: Schrijf smoke test**

```swift
import Testing

@Test func toolchainWorks() {
    #expect(1 + 1 == 2)
}
```

- [ ] **Step 5: Verifieer build en test**

Run: `swift build && swift test`
Expected: build slaagt; 1 test PASS.
**Fallback A:** faalt `import Testing` (niet aanwezig in deze toolchain), herschrijf de test naar XCTest (`import XCTest`, `final class SmokeTests: XCTestCase { func testToolchainWorks() { XCTAssertEqual(1+1, 2) } }`) en gebruik XCTest in álle volgende taken (zelfde asserts, XCTest-syntax). Faalt ook dat, stop en rapporteer.
**Fallback B:** faalt `@testable import GlowCursor` in latere taken omdat het een executable-target is (zeldzaam op SwiftPM 6.x, maar mogelijk), splits dan in `Package.swift`: een `.target(name: "GlowCursorKit", ...)` met alle componenten en een dunne `.executableTarget(name: "GlowCursor", dependencies: ["GlowCursorKit"], ...)` met alleen `main.swift`. Testtarget hangt dan aan `GlowCursorKit`. Verplaats bestaande bestanden mee en pas `import` aan.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "chore: SPM-scaffold met testtarget"
```

---

### Task 2: CoordinateMapper

**Files:**
- Create: `Sources/GlowCursor/CoordinateMapper.swift`
- Test: `Tests/GlowCursorTests/CoordinateMapperTests.swift`

**Interfaces:**
- Consumes: —
- Produces:
  - `typealias ScreenID = UInt32`
  - `CoordinateMapper.ScreenInfo` — `struct { let id: ScreenID; let frame: CGRect }` (frame in globale AppKit-coördinaten, origin linksonder hoofdscherm)
  - `CoordinateMapper.screen(containing: CGPoint, screens: [ScreenInfo]) -> ScreenInfo?` — bevat-check, anders dichtstbijzijnde; nil alleen bij lege lijst
  - `CoordinateMapper.toLocal(_ point: CGPoint, in screen: ScreenInfo) -> CGPoint`

- [ ] **Step 1: Schrijf failing tests**

```swift
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
```

- [ ] **Step 2: Run test, verwacht FAIL**

Run: `swift test`
Expected: compile-fout "cannot find 'CoordinateMapper'".

- [ ] **Step 3: Implementeer**

```swift
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
```

- [ ] **Step 4: Run test, verwacht PASS**

Run: `swift test`

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: CoordinateMapper voor globaal->lokaal en schermdetectie"
```

---

### Task 3: StrokeStore

**Files:**
- Create: `Sources/GlowCursor/StrokeStore.swift`
- Test: `Tests/GlowCursorTests/StrokeStoreTests.swift`

**Interfaces:**
- Consumes: `ScreenID` (Task 2)
- Produces:
  - `Stroke` — `struct Equatable { enum Kind: Equatable { case freehand([CGPoint]); case markerRect(CGRect) }; let kind: Kind; let colorName: String }`
  - `StrokeStore` (class): `add(_ stroke: Stroke, on screen: ScreenID)`, `undoLast() -> Bool` (verwijdert de globaal láátst toegevoegde stroke, over schermen heen), `clearAll()`, `strokes(on screen: ScreenID) -> [Stroke]`, `var isEmpty: Bool`

- [ ] **Step 1: Schrijf failing tests**

```swift
import Testing
import Foundation
@testable import GlowCursor

private func stroke(_ x: CGFloat) -> Stroke {
    Stroke(kind: .freehand([CGPoint(x: x, y: 0), CGPoint(x: x, y: 10)]), colorName: "Oranje")
}

@Test func strokesAreSeparatedPerScreen() {
    let store = StrokeStore()
    store.add(stroke(1), on: 1)
    store.add(stroke(2), on: 2)
    #expect(store.strokes(on: 1) == [stroke(1)])
    #expect(store.strokes(on: 2) == [stroke(2)])
}

@Test func undoRemovesGloballyLastStroke() {
    let store = StrokeStore()
    store.add(stroke(1), on: 1)
    store.add(stroke(2), on: 2)
    #expect(store.undoLast() == true)
    #expect(store.strokes(on: 2).isEmpty)
    #expect(store.strokes(on: 1) == [stroke(1)])
}

@Test func undoOnEmptyStoreReturnsFalse() {
    #expect(StrokeStore().undoLast() == false)
}

@Test func clearAllEmptiesEverything() {
    let store = StrokeStore()
    store.add(stroke(1), on: 1)
    store.add(stroke(2), on: 2)
    store.clearAll()
    #expect(store.isEmpty)
    #expect(store.strokes(on: 1).isEmpty)
}
```

- [ ] **Step 2: Run test, verwacht FAIL** (`swift test` — "cannot find 'Stroke'")

- [ ] **Step 3: Implementeer**

```swift
import Foundation

struct Stroke: Equatable {
    enum Kind: Equatable {
        case freehand([CGPoint])
        case markerRect(CGRect)
    }
    let kind: Kind
    let colorName: String
}

final class StrokeStore {
    private var entries: [(screen: ScreenID, stroke: Stroke)] = []

    var isEmpty: Bool { entries.isEmpty }

    func add(_ stroke: Stroke, on screen: ScreenID) {
        entries.append((screen, stroke))
    }

    @discardableResult
    func undoLast() -> Bool {
        guard !entries.isEmpty else { return false }
        entries.removeLast()
        return true
    }

    func clearAll() {
        entries.removeAll()
    }

    func strokes(on screen: ScreenID) -> [Stroke] {
        entries.filter { $0.screen == screen }.map(\.stroke)
    }
}
```

- [ ] **Step 4: Run test, verwacht PASS** (`swift test`)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: StrokeStore met per-scherm strokes en globale undo"
```

---

### Task 4: EffectsState

**Files:**
- Create: `Sources/GlowCursor/EffectsState.swift`
- Test: `Tests/GlowCursorTests/EffectsStateTests.swift`

**Interfaces:**
- Consumes: —
- Produces:
  - `protocol EffectsStateDelegate: AnyObject { func effectsStateDidChange(_ state: EffectsState) }`
  - `EffectsState` (class): `init(defaults: UserDefaults = .standard)`; `weak var delegate`; vars `ringEnabled/spotlightEnabled/drawModeEnabled: Bool` (niet gepersisteerd, starten false), `ringDiameter: CGFloat` (persisted, default 60), `dimOpacity: CGFloat` (persisted, default 0.55), `colorName: String` (persisted, default "Oranje"); computed `color: NSColor`
  - `EffectsState.palette: [(name: String, color: NSColor)]` — Oranje, Rood, Geel, Groen, Blauw, Roze
  - `EffectsState.color(named: String) -> NSColor` — onbekende naam ⇒ `.systemOrange`
  - Elke setter roept `delegate?.effectsStateDidChange(self)` aan; gepersisteerde setters schrijven direct naar `UserDefaults`.

- [ ] **Step 1: Schrijf failing tests**

```swift
import Testing
import AppKit
@testable import GlowCursor

private func freshDefaults() -> UserDefaults {
    let d = UserDefaults(suiteName: "GlowCursorTests")!
    d.removePersistentDomain(forName: "GlowCursorTests")
    return d
}

private final class Spy: EffectsStateDelegate {
    var count = 0
    func effectsStateDidChange(_ state: EffectsState) { count += 1 }
}

@Test func defaultsStartCorrect() {
    let s = EffectsState(defaults: freshDefaults())
    #expect(s.ringEnabled == false)
    #expect(s.spotlightEnabled == false)
    #expect(s.drawModeEnabled == false)
    #expect(s.ringDiameter == 60)
    #expect(s.dimOpacity == 0.55)
    #expect(s.colorName == "Oranje")
}

@Test func settingsPersistAcrossInstances() {
    let d = freshDefaults()
    let s1 = EffectsState(defaults: d)
    s1.ringDiameter = 90
    s1.dimOpacity = 0.75
    s1.colorName = "Blauw"
    s1.ringEnabled = true // mag NIET persisten
    let s2 = EffectsState(defaults: d)
    #expect(s2.ringDiameter == 90)
    #expect(s2.dimOpacity == 0.75)
    #expect(s2.colorName == "Blauw")
    #expect(s2.ringEnabled == false)
}

@Test func delegateFiresOnEveryChange() {
    let s = EffectsState(defaults: freshDefaults())
    let spy = Spy()
    s.delegate = spy
    s.ringEnabled = true
    s.spotlightEnabled = true
    s.ringDiameter = 40
    #expect(spy.count == 3)
}

@Test func unknownColorNameFallsBackToOrange() {
    #expect(EffectsState.color(named: "Paars???") == EffectsState.color(named: "Oranje"))
}
```

- [ ] **Step 2: Run test, verwacht FAIL** (`swift test`)

- [ ] **Step 3: Implementeer**

```swift
import AppKit

protocol EffectsStateDelegate: AnyObject {
    func effectsStateDidChange(_ state: EffectsState)
}

final class EffectsState {
    static let palette: [(name: String, color: NSColor)] = [
        ("Oranje", .systemOrange), ("Rood", .systemRed), ("Geel", .systemYellow),
        ("Groen", .systemGreen), ("Blauw", .systemBlue), ("Roze", .systemPink),
    ]

    static func color(named name: String) -> NSColor {
        palette.first(where: { $0.name == name })?.color ?? .systemOrange
    }

    weak var delegate: EffectsStateDelegate?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ringDiameter = CGFloat(defaults.object(forKey: "ringDiameter") as? Double ?? 60)
        dimOpacity = CGFloat(defaults.object(forKey: "dimOpacity") as? Double ?? 0.55)
        colorName = defaults.string(forKey: "colorName") ?? "Oranje"
    }

    var ringEnabled = false { didSet { notify() } }
    var spotlightEnabled = false { didSet { notify() } }
    var drawModeEnabled = false { didSet { notify() } }

    var ringDiameter: CGFloat {
        didSet { defaults.set(Double(ringDiameter), forKey: "ringDiameter"); notify() }
    }
    var dimOpacity: CGFloat {
        didSet { defaults.set(Double(dimOpacity), forKey: "dimOpacity"); notify() }
    }
    var colorName: String {
        didSet { defaults.set(colorName, forKey: "colorName"); notify() }
    }

    var color: NSColor { Self.color(named: colorName) }

    private func notify() { delegate?.effectsStateDidChange(self) }
}
```

Let op: de gepersisteerde properties zijn in `init` vóór `super`-loos gebruik direct toegewezen; hun `didSet` vuurt niet tijdens `init` (Swift-gedrag), dus geen delegate-calls bij start.

- [ ] **Step 4: Run test, verwacht PASS** (`swift test`)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: EffectsState met persistentie en delegate"
```

---

### Task 5: HotKeyManager

**Files:**
- Create: `Sources/GlowCursor/HotKeyManager.swift`
- Test: `Tests/GlowCursorTests/HotKeyManagerTests.swift`

**Interfaces:**
- Consumes: —
- Produces:
  - `enum HotKeyAction: CaseIterable { case toggleRing, toggleSpotlight, toggleDrawMode, undoStroke, clearStrokes }`
  - `HotKeyManager` (class): `var handler: ((HotKeyAction) -> Void)?`, `func registerAll()`, `static func action(forID id: UInt32) -> HotKeyAction?` (id 1...5 in CaseIterable-volgorde), `static let defaultBindings: [(action: HotKeyAction, keyCode: UInt32, modifiers: UInt32)]`
  - Bindings (Carbon-codes): ⌃⌥ = `controlKey|optionKey` = `0x1000|0x0800`; H=0x04, S=0x01, D=0x02, Z=0x06, C=0x08

- [ ] **Step 1: Schrijf failing tests**

```swift
import Testing
@testable import GlowCursor

@Test func everyActionHasExactlyOneBinding() {
    let actions = HotKeyManager.defaultBindings.map(\.action)
    #expect(Set(actions).count == HotKeyAction.allCases.count)
    #expect(actions.count == HotKeyAction.allCases.count)
}

@Test func allBindingsUseControlOption() {
    for b in HotKeyManager.defaultBindings {
        #expect(b.modifiers == 0x1800) // controlKey(0x1000) | optionKey(0x0800)
    }
}

@Test func keyCodesMatchSpec() {
    func code(_ a: HotKeyAction) -> UInt32? {
        HotKeyManager.defaultBindings.first { $0.action == a }?.keyCode
    }
    #expect(code(.toggleRing) == 0x04)      // H
    #expect(code(.toggleSpotlight) == 0x01) // S
    #expect(code(.toggleDrawMode) == 0x02)  // D
    #expect(code(.undoStroke) == 0x06)      // Z
    #expect(code(.clearStrokes) == 0x08)    // C
}

@Test func idMappingRoundTrips() {
    #expect(HotKeyManager.action(forID: 1) == .toggleRing)
    #expect(HotKeyManager.action(forID: 5) == .clearStrokes)
    #expect(HotKeyManager.action(forID: 0) == nil)
    #expect(HotKeyManager.action(forID: 6) == nil)
}
```

- [ ] **Step 2: Run test, verwacht FAIL** (`swift test`)

- [ ] **Step 3: Implementeer**

```swift
import Carbon.HIToolbox
import Foundation
import os.log

enum HotKeyAction: CaseIterable, Hashable {
    case toggleRing, toggleSpotlight, toggleDrawMode, undoStroke, clearStrokes
}

final class HotKeyManager {
    static let defaultBindings: [(action: HotKeyAction, keyCode: UInt32, modifiers: UInt32)] = [
        (.toggleRing, UInt32(kVK_ANSI_H), UInt32(controlKey | optionKey)),
        (.toggleSpotlight, UInt32(kVK_ANSI_S), UInt32(controlKey | optionKey)),
        (.toggleDrawMode, UInt32(kVK_ANSI_D), UInt32(controlKey | optionKey)),
        (.undoStroke, UInt32(kVK_ANSI_Z), UInt32(controlKey | optionKey)),
        (.clearStrokes, UInt32(kVK_ANSI_C), UInt32(controlKey | optionKey)),
    ]

    static func action(forID id: UInt32) -> HotKeyAction? {
        let all = HotKeyAction.allCases
        guard id >= 1, id <= UInt32(all.count) else { return nil }
        return all[Int(id) - 1]
    }

    var handler: ((HotKeyAction) -> Void)?

    private let log = Logger(subsystem: "local.glowcursor", category: "hotkeys")
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?

    func registerAll() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            if let action = HotKeyManager.action(forID: hkID.id) {
                DispatchQueue.main.async { manager.handler?(action) }
            }
            return noErr
        }, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), &eventHandlerRef)

        for (index, binding) in Self.defaultBindings.enumerated() {
            var ref: EventHotKeyRef?
            let hkID = EventHotKeyID(signature: OSType(0x474C_4F57) /* 'GLOW' */, id: UInt32(index + 1))
            let status = RegisterEventHotKey(binding.keyCode, binding.modifiers, hkID,
                                             GetApplicationEventTarget(), 0, &ref)
            if status != noErr {
                log.error("Hotkey-registratie mislukt voor \(String(describing: binding.action)) (status \(status)); functie blijft via menu bereikbaar")
            }
            hotKeyRefs.append(ref)
        }
    }
}
```

- [ ] **Step 4: Run test, verwacht PASS** (`swift test`)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: HotKeyManager met Carbon-hotkeys en geteste mapping"
```

---

### Task 6: CursorTracker

**Files:**
- Create: `Sources/GlowCursor/CursorTracker.swift`
- Test: `Tests/GlowCursorTests/CursorTrackerTests.swift`

**Interfaces:**
- Consumes: —
- Produces:
  - `protocol CursorTrackerDelegate: AnyObject { func cursorTracker(_ tracker: CursorTracker, didMoveTo globalPoint: CGPoint) }`
  - `CursorTracker` (class): `weak var delegate`, `var isRunning: Bool`, `func start()`, `func stop()`. `start()` is idempotent; delegate krijgt per frame `NSEvent.mouseLocation`.

- [ ] **Step 1: Schrijf failing test**

```swift
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
```

- [ ] **Step 2: Run test, verwacht FAIL** (`swift test`)

- [ ] **Step 3: Implementeer**

```swift
import AppKit
import QuartzCore

protocol CursorTrackerDelegate: AnyObject {
    func cursorTracker(_ tracker: CursorTracker, didMoveTo globalPoint: CGPoint)
}

final class CursorTracker {
    weak var delegate: CursorTrackerDelegate?
    private var displayLink: CADisplayLink?

    var isRunning: Bool { displayLink != nil }

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
```

- [ ] **Step 4: Run test, verwacht PASS** (`swift test`)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: CursorTracker met CADisplayLink-polling"
```

---

### Task 7: Overlay-vensters en renderlagen

**Files:**
- Create: `Sources/GlowCursor/OverlayPanel.swift`
- Create: `Sources/GlowCursor/PassthroughHostView.swift`
- Create: `Sources/GlowCursor/RingLayer.swift`
- Create: `Sources/GlowCursor/SpotlightLayer.swift`

**Interfaces:**
- Consumes: —
- Produces:
  - `OverlayPanel` (NSPanel-subclass): `init(screen: NSScreen)`, `var allowsKey: Bool` (default false; `canBecomeKey` volgt dit)
  - `PassthroughHostView` (NSView): `init(hosting layer: CALayer)` — layer-hosting view waarvan `hitTest` altijd nil retourneert
  - `RingLayer` (CAShapeLayer): `func update(center: CGPoint?, diameter: CGFloat, color: NSColor)` — nil center verbergt de ring
  - `SpotlightLayer` (CALayer): `var dimOpacity: CGFloat`, `func update(holeCenter: CGPoint?)` — nil = volledig gedimd zonder gat; `static let holeRadius: CGFloat = 110`

Geen unit tests (puur visueel; verifieerbaar in Task 8). Buildcheck volstaat hier.

- [ ] **Step 1: Schrijf OverlayPanel.swift**

```swift
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
```

- [ ] **Step 2: Schrijf PassthroughHostView.swift**

```swift
import AppKit

/// Layer-hosting view die nooit muis-events opeist, zodat kliks in
/// tekenmodus bij de AnnotationView eronder/erboven terechtkomen.
final class PassthroughHostView: NSView {
    init(hosting layer: CALayer) {
        super.init(frame: .zero)
        self.layer = layer
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
```

- [ ] **Step 3: Schrijf RingLayer.swift**

```swift
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
```

- [ ] **Step 4: Schrijf SpotlightLayer.swift**

```swift
import AppKit

final class SpotlightLayer: CALayer {
    static let holeRadius: CGFloat = 110

    private let maskShape = CAShapeLayer()

    var dimOpacity: CGFloat = 0.55 {
        didSet { updateOpacity() }
    }

    override init() {
        super.init()
        backgroundColor = NSColor.black.cgColor
        maskShape.fillRule = .evenOdd
        mask = maskShape
        updateOpacity()
    }

    override init(layer: Any) { super.init(layer: layer) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func updateOpacity() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        opacity = Float(dimOpacity)
        CATransaction.commit()
    }

    /// nil = volledig dimmen (cursor op ander scherm); anders gat rond center.
    func update(holeCenter: CGPoint?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        maskShape.frame = bounds
        let path = CGMutablePath()
        path.addRect(bounds)
        if let c = holeCenter {
            let r = Self.holeRadius
            path.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
        maskShape.path = path
    }
}
```

- [ ] **Step 5: Verifieer build en bestaande tests**

Run: `swift build && swift test`
Expected: build slaagt, alle tests PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: OverlayPanel, PassthroughHostView, RingLayer, SpotlightLayer"
```

---

### Task 8: OverlayController + AppDelegate — ring en spotlight werkend

**Files:**
- Create: `Sources/GlowCursor/OverlayController.swift`
- Create: `Sources/GlowCursor/AppDelegate.swift`
- Modify: `Sources/GlowCursor/main.swift`

**Interfaces:**
- Consumes: alles uit Tasks 2–7 (exacte signaturen: zie Produces-blokken daar)
- Produces:
  - `OverlayController` (class, conformeert aan `EffectsStateDelegate` + `CursorTrackerDelegate`): `init(state: EffectsState, store: StrokeStore, tracker: CursorTracker)`, `func rebuildPanels()`, `func redrawAnnotations()`. Intern per scherm een `PanelBundle` (panel + lagen). In deze taak is de AnnotationView-slot nog leeg; Task 9 vult hem in via de hier al gedefinieerde `makeAnnotationView(screenID:)`-hook die nu `nil` retourneert.
  - `AppDelegate` (NSObject, NSApplicationDelegate): bouwt state/store/tracker/controller/hotkeys op, koppelt hotkey-handler, observeert `NSApplication.didChangeScreenParametersNotification` → `rebuildPanels()`.

- [ ] **Step 1: Schrijf OverlayController.swift**

```swift
import AppKit

final class OverlayController: NSObject {
    private struct PanelBundle {
        let screenID: ScreenID
        let panel: OverlayPanel
        let spotlightLayer: SpotlightLayer
        let spotlightHost: PassthroughHostView
        let ringLayer: RingLayer
        let ringHost: PassthroughHostView
        let annotationView: NSView? // Task 9 maakt hier een AnnotationView van
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

    // Task 9 vervangt de nil-return door een echte AnnotationView.
    func makeAnnotationView(screenID: ScreenID) -> NSView? { nil }

    func rebuildPanels() {
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
            let spotlightHost = PassthroughHostView(hosting: spotlightLayer)
            spotlightHost.frame = container.bounds
            spotlightHost.autoresizingMask = [.width, .height]
            container.addSubview(spotlightHost)

            let annotationView = makeAnnotationView(screenID: screenID)
            if let annotationView {
                annotationView.frame = container.bounds
                annotationView.autoresizingMask = [.width, .height]
                container.addSubview(annotationView)
            }

            let ringLayer = RingLayer()
            ringLayer.frame = container.bounds
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
        bundles.forEach { $0.annotationView?.needsDisplay = true }
    }

    private func syncFromState() {
        let needsTracking = state.ringEnabled || state.spotlightEnabled
        if needsTracking { tracker.start() } else { tracker.stop() }

        for b in bundles {
            b.panel.ignoresMouseEvents = !state.drawModeEnabled
            b.panel.allowsKey = state.drawModeEnabled
            b.spotlightHost.isHidden = !state.spotlightEnabled
            b.ringHost.isHidden = !state.ringEnabled
            b.spotlightLayer.dimOpacity = state.dimOpacity
        }
        applyCursorPosition(NSEvent.mouseLocation)
        if state.drawModeEnabled { makeKeyPanelUnderCursor() }
        redrawAnnotations()
    }

    private func makeKeyPanelUnderCursor() {
        let infos = bundles.map { CoordinateMapper.ScreenInfo(id: $0.screenID, frame: $0.panel.frame) }
        guard let target = CoordinateMapper.screen(containing: NSEvent.mouseLocation, screens: infos),
              let bundle = bundles.first(where: { $0.screenID == target.id })
        else { return }
        bundle.panel.makeKey()
        if let view = bundle.annotationView {
            bundle.panel.makeFirstResponder(view)
        }
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
```

- [ ] **Step 2: Schrijf AppDelegate.swift**

```swift
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
```

- [ ] **Step 3: Vervang main.swift**

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 4: Build + tests**

Run: `swift build && swift test`
Expected: build slaagt, alle tests PASS.

- [ ] **Step 5: Handmatige verificatie (eerste visuele mijlpaal)**

Run: `swift run` (laat draaien; stop met Ctrl-C in de terminal)
Check, met een andere app als frontmost:
1. ⌃⌥H → oranje ring volgt de cursor vloeiend, geen smeer-effect.
2. ⌃⌥S → scherm dimt, helder gat volgt de cursor; ring blijft zichtbaar in het gat.
3. Klikken/typen in onderliggende apps werkt gewoon door (click-through).
4. Nogmaals ⌃⌥H en ⌃⌥S → effecten uit; CPU van GlowCursor in Activiteitenweergave ~0%.
Expected: alle vier gedragingen kloppen. Zo niet: stoppen en debuggen vóór commit.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: OverlayController + AppDelegate; ring en spotlight werkend via hotkeys"
```

---

### Task 9: AnnotationView + tekenmodus

**Files:**
- Create: `Sources/GlowCursor/AnnotationView.swift`
- Modify: `Sources/GlowCursor/OverlayController.swift` (de `makeAnnotationView(screenID:)`-hook)

**Interfaces:**
- Consumes: `Stroke`/`StrokeStore` (Task 3), `EffectsState` (Task 4), `OverlayController.makeAnnotationView(screenID:)` + `PanelBundle.annotationView` (Task 8)
- Produces:
  - `AnnotationView` (NSView): `init(screenID: ScreenID, store: StrokeStore, state: EffectsState)`, `var isDrawModeActive: Bool` (default false), `var onEscape: (() -> Void)?`
  - Gedrag: in tekenmodus is slepen freehand (lineWidth 5, ronde caps), ⇧+slepen een marker-rechthoek (vulkleur alpha 0.35); ESC roept `onEscape` aan; cursor is crosshair; buiten tekenmodus reageert de view nergens op.

- [ ] **Step 1: Schrijf AnnotationView.swift**

```swift
import AppKit

final class AnnotationView: NSView {
    private let screenID: ScreenID
    private let store: StrokeStore
    private let state: EffectsState

    var onEscape: (() -> Void)?

    var isDrawModeActive = false {
        didSet {
            window?.invalidateCursorRects(for: self)
        }
    }

    private var currentPoints: [CGPoint] = []
    private var isRectMode = false

    init(screenID: ScreenID, store: StrokeStore, state: EffectsState) {
        self.screenID = screenID
        self.store = store
        self.state = state
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { isDrawModeActive }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        if isDrawModeActive {
            addCursorRect(bounds, cursor: .crosshair)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isDrawModeActive ? super.hitTest(point) : nil
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isDrawModeActive else { return }
        isRectMode = event.modifierFlags.contains(.shift)
        currentPoints = [convert(event.locationInWindow, from: nil)]
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDrawModeActive, !currentPoints.isEmpty else { return }
        currentPoints.append(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDrawModeActive, !currentPoints.isEmpty else { return }
        currentPoints.append(convert(event.locationInWindow, from: nil))
        if let stroke = finishedStroke() {
            store.add(stroke, on: screenID)
        }
        currentPoints = []
        needsDisplay = true
    }

    private func finishedStroke() -> Stroke? {
        guard currentPoints.count > 1 else { return nil }
        if isRectMode {
            return Stroke(kind: .markerRect(rect(from: currentPoints.first!, to: currentPoints.last!)),
                          colorName: state.colorName)
        }
        return Stroke(kind: .freehand(currentPoints), colorName: state.colorName)
    }

    private func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    override func draw(_ dirtyRect: NSRect) {
        for stroke in store.strokes(on: screenID) {
            render(stroke)
        }
        if let inProgress = inProgressStroke() {
            render(inProgress)
        }
    }

    private func inProgressStroke() -> Stroke? {
        guard currentPoints.count > 1 else { return nil }
        if isRectMode {
            return Stroke(kind: .markerRect(rect(from: currentPoints.first!, to: currentPoints.last!)),
                          colorName: state.colorName)
        }
        return Stroke(kind: .freehand(currentPoints), colorName: state.colorName)
    }

    private func render(_ stroke: Stroke) {
        let color = EffectsState.color(named: stroke.colorName)
        switch stroke.kind {
        case .freehand(let points):
            guard points.count > 1 else { return }
            let path = NSBezierPath()
            path.lineWidth = 5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: points[0])
            for p in points.dropFirst() { path.line(to: p) }
            color.setStroke()
            path.stroke()
        case .markerRect(let r):
            color.withAlphaComponent(0.35).setFill()
            r.fill()
        }
    }
}
```

- [ ] **Step 2: Sluit AnnotationView aan in OverlayController**

Vervang in `OverlayController.swift`:

```swift
    // Task 9 vervangt de nil-return door een echte AnnotationView.
    func makeAnnotationView(screenID: ScreenID) -> NSView? { nil }
```

door:

```swift
    func makeAnnotationView(screenID: ScreenID) -> NSView? {
        let view = AnnotationView(screenID: screenID, store: store, state: state)
        view.onEscape = { [weak self] in
            self?.state.drawModeEnabled = false
        }
        return view
    }
```

En vervang in `syncFromState()` de regel `b.spotlightHost.isHidden = ...`-blok zodat de tekenmodus ook op de views landt — voeg binnen de `for b in bundles`-lus deze regel toe direct na `b.panel.allowsKey = state.drawModeEnabled`:

```swift
            (b.annotationView as? AnnotationView)?.isDrawModeActive = state.drawModeEnabled
```

- [ ] **Step 3: Build + tests**

Run: `swift build && swift test`
Expected: build slaagt, alle tests PASS.

- [ ] **Step 4: Handmatige verificatie**

Run: `swift run`
Check, met bijv. een browser als frontmost app:
1. ⌃⌥D → cursor wordt crosshair; de frontmost app verliest **geen** focus (menubalk blijft van die app).
2. Slepen tekent een oranje lijn; ⇧+slepen tekent een translucente rechthoek.
3. ⌃⌥Z verwijdert de laatste streek; ⌃⌥C wist alles.
4. ESC verlaat de tekenmodus (cursor weer normaal, klikken gaat weer door de overlay heen).
5. Annotaties blijven zichtbaar ná het verlaten van de tekenmodus.
Expected: alle vijf gedragingen kloppen.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: AnnotationView met freehand, marker-rechthoek, undo/clear en ESC"
```

---

### Task 10: MenuBarController

**Files:**
- Create: `Sources/GlowCursor/MenuBarController.swift`
- Modify: `Sources/GlowCursor/AppDelegate.swift`

**Interfaces:**
- Consumes: `EffectsState` incl. `palette` (Task 4), `StrokeStore` (Task 3), `OverlayController.redrawAnnotations()` (Task 8), `HotKeyManager` niet nodig hier
- Produces:
  - `MenuBarController` (class): `init(state: EffectsState, store: StrokeStore, controller: OverlayController)` — plaatst `NSStatusItem` met menu; menu wordt bij elke opening opnieuw opgebouwd zodat vinkjes altijd kloppen.

- [ ] **Step 1: Schrijf MenuBarController.swift**

```swift
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

    @objc private func clearStrokes() {
        store.clearAll()
        controller.redrawAnnotations()
    }
}
```

- [ ] **Step 2: Sluit aan in AppDelegate**

Voeg in `AppDelegate` een property toe en instantieer in `applicationDidFinishLaunching` (na het aanmaken van `controller`):

```swift
    private var menuBar: MenuBarController!
```

```swift
        menuBar = MenuBarController(state: state, store: store, controller: controller)
```

- [ ] **Step 3: Build + tests**

Run: `swift build && swift test`
Expected: build slaagt, alle tests PASS.

- [ ] **Step 4: Handmatige verificatie**

Run: `swift run`
1. Menubar-icoon (cursor-met-stralen) zichtbaar rechtsboven; geen dock-icoon.
2. Menu: toggles tonen vinkje conform actuele staat (zet ring aan via ⌃⌥H, open menu → vinkje staat aan).
3. Kleur wijzigen → ring krijgt direct de nieuwe kleur.
4. Dim-sterkte wijzigen met actieve spotlight → dimming past direct aan.
5. "Stop GlowCursor" beëindigt de app.
Expected: alle vijf kloppen.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: menubar-menu met toggles, kleur, groottes en wissen"
```

---

### Task 11: App-bundel, README en eindcheck

**Files:**
- Create: `Resources/Info.plist`
- Create: `Scripts/bundle.sh`
- Create: `README.md`

**Interfaces:**
- Consumes: release-binary uit `swift build -c release`
- Produces: `build/GlowCursor.app` (ad-hoc gesigneerd), gebruikersdocumentatie.

- [ ] **Step 1: Schrijf Resources/Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>GlowCursor</string>
    <key>CFBundleIdentifier</key><string>local.glowcursor</string>
    <key>CFBundleName</key><string>GlowCursor</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 2: Schrijf Scripts/bundle.sh**

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/GlowCursor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/GlowCursor "$APP/Contents/MacOS/GlowCursor"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force -s - "$APP"

echo "Klaar: $APP"
echo "Sleep naar /Applications en voeg desgewenst toe aan Inlogonderdelen."
```

Run daarna: `chmod +x Scripts/bundle.sh`

- [ ] **Step 3: Schrijf README.md**

```markdown
# GlowCursor

Gratis cursor-highlighter voor macOS — voor live presentaties en screensharing.
Systeembreed: highlight-ring, spotlight-dimming en live schermannotaties.
Nul permissies nodig (geen Accessibility, geen Screen Recording).

## Sneltoetsen

| Toets | Actie |
|---|---|
| ⌃⌥H | Highlight-ring aan/uit |
| ⌃⌥S | Spotlight aan/uit |
| ⌃⌥D | Tekenmodus aan/uit (slepen = tekenen, ⇧+slepen = marker-rechthoek, ESC = stoppen) |
| ⌃⌥Z | Laatste streek ongedaan maken |
| ⌃⌥C | Alle annotaties wissen |

Kleur, ringgrootte en dim-sterkte stel je in via het menubar-icoon.

## Belangrijk: schermdeling

De effecten zijn zichtbaar wanneer je je **volledige scherm** deelt (Teams,
Zoom, Meet). Deel je slechts één **venster**, dan ziet je publiek de effecten
niet — de overlay is technisch een apart venster. Dit geldt voor alle tools
van dit type.

## Bouwen (geen Xcode nodig, wel Command Line Tools)

    Scripts/bundle.sh

Resultaat: `build/GlowCursor.app`. Sleep naar /Applications.
Ontwikkelen: `swift run` · Tests: `swift test`
```

- [ ] **Step 4: Bouw de bundel en verifieer**

Run: `Scripts/bundle.sh && open build/GlowCursor.app`
Expected: script eindigt met "Klaar"; app start (menubar-icoon verschijnt, geen dock-icoon). Stop de `swift run`-instantie eerst als die nog draait (anders twee menubar-iconen).

- [ ] **Step 5: Draai de volledige handmatige testchecklist uit het spec (§9)**

Alle 10 punten uit `docs/superpowers/specs/2026-08-31-glowcursor-design.md` §9 langslopen met de gebundelde app. Punt 7 (tweede monitor) en 8 (Teams/Zoom) alleen als de hardware/software voorhanden is — zo niet, expliciet als "niet getest" rapporteren aan de gebruiker, niet stilzwijgend overslaan.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: app-bundel, bundle-script en README"
```
