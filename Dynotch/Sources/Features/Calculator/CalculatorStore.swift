import Combine
import Foundation

/// The calculator notepad's text, shared by the notch and the menu bar panel and kept
/// across restarts (spec SZ-5).
@MainActor
final class CalculatorStore: ObservableObject {
    private static let key = "calculatorText"
    private let defaults: UserDefaults

    @Published var text: String {
        didSet { defaults.set(text, forKey: Self.key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        text = defaults.string(forKey: Self.key) ?? ""
    }
}

/// "Keep open" switch of a panel (spec SZ-8).
@MainActor
final class PinState: ObservableObject {
    @Published var isPinned = false
}
