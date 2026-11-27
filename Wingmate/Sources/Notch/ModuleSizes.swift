import CoreGraphics
import Foundation

/// The sizes modules were resized to, per display and module (spec RS-3).
@MainActor
final class ModuleSizes {
    /// Every module can be resized (spec RS-1, RS-6); a new module is resizable from the start.
    static let resizable = Set(FeatureID.allCases)

    private static let key = "moduleSizes"
    private let defaults: UserDefaults
    private var sizes: [String: [Double]]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sizes = defaults.dictionary(forKey: Self.key) as? [String: [Double]] ?? [:]
    }

    func size(of feature: FeatureID, variant: String? = nil, on display: String) -> CGSize? {
        guard let pair = sizes[Self.entry(feature, variant, display)], pair.count == 2 else { return nil }
        return CGSize(width: pair[0], height: pair[1])
    }

    func set(_ size: CGSize?, of feature: FeatureID, variant: String? = nil, on display: String) {
        sizes[Self.entry(feature, variant, display)] = size.map { [Double($0.width.rounded()), Double($0.height.rounded())] }
        defaults.set(sizes, forKey: Self.key)
    }

    /// A module's views of different sizes (e.g. the full calendar) keep their own (spec RS-3).
    private static func entry(_ feature: FeatureID, _ variant: String?, _ display: String) -> String {
        "\(display)|\(feature.rawValue)" + (variant.map { "|" + $0 } ?? "")
    }

    /// Keeps a size between the module's normal size and the most the display allows.
    nonisolated static func clamped(_ size: CGSize, min lower: CGSize, max upper: CGSize) -> CGSize {
        CGSize(
            width: Swift.min(Swift.max(size.width, lower.width), Swift.max(upper.width, lower.width)),
            height: Swift.min(Swift.max(size.height, lower.height), Swift.max(upper.height, lower.height))
        )
    }
}
