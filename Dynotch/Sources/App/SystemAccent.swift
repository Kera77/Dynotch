import AppKit
import Combine

/// The accent colour chosen in *System Settings › Appearance*, followed live (spec D-17b).
/// `controlAccentColor` alone gives the app's own blue accent and is read only once per drawing,
/// so a change in the settings did not reach the notch.
@MainActor
final class SystemAccent: ObservableObject {
    static let shared = SystemAccent()

    @Published private(set) var color: NSColor

    private var observers: [NSObjectProtocol] = []

    private init() {
        color = Self.read()
        let refresh: @Sendable (Notification) -> Void = { _ in
            Task { @MainActor in SystemAccent.shared.color = SystemAccent.read() }
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSColor.systemColorsDidChangeNotification, object: nil, queue: .main, using: refresh
        ))
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleColorPreferencesChangedNotification"), object: nil, queue: .main, using: refresh
        ))
    }

    /// The system's colour for an `AppleAccentColor` value; Multicolour (no value) is blue.
    nonisolated static func color(forSetting value: Int?) -> NSColor {
        switch value {
        case -1: .systemGray
        case 0: .systemRed
        case 1: .systemOrange
        case 2: .systemYellow
        case 3: .systemGreen
        case 5: .systemPurple
        case 6: .systemPink
        default: .systemBlue
        }
    }

    private static func read() -> NSColor {
        let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
        return color(forSetting: global?["AppleAccentColor"] as? Int)
    }
}
