import Foundation
import Observation

/// The calculator notepad's text, shared by the notch and the menu bar panel and kept
/// across restarts (spec SZ-5).
@MainActor
@Observable
final class CalculatorStore {
    private static let key = "calculatorText"
    private let defaults: UserDefaults

    var text: String {
        didSet { defaults.set(text, forKey: Self.key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        text = defaults.string(forKey: Self.key) ?? ""
    }
}
