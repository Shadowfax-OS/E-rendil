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

    /// True zodra minstens één effect (ring, spotlight of tekenmodus) actief is.
    /// Stuurt of de bare-ESC paniekknop wordt afgevangen.
    var anyEffectActive: Bool { ringEnabled || spotlightEnabled || drawModeEnabled }

    private func notify() { delegate?.effectsStateDidChange(self) }
}
