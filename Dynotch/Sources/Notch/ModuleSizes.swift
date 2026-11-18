import CoreGraphics
import Foundation

/// The sizes modules were resized to, per display and module (spec RS-3).
@MainActor
final class ModuleSizes {
    /// Modules that can be resized (spec RS-1); more follow as they learn to use the room.
    static let resizable: Set<FeatureID> = [.claudeChat]

    private static let key = "moduleSizes"
    private let defaults: UserDefaults
    private var sizes: [String: [Double]]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sizes = defaults.dictionary(forKey: Self.key) as? [String: [Double]] ?? [:]
    }

    func size(of feature: FeatureID, on display: String) -> CGSize? {
        guard let pair = sizes[Self.entry(feature, display)], pair.count == 2 else { return nil }
        return CGSize(width: pair[0], height: pair[1])
    }

    func set(_ size: CGSize?, of feature: FeatureID, on display: String) {
        sizes[Self.entry(feature, display)] = size.map { [Double($0.width.rounded()), Double($0.height.rounded())] }
        defaults.set(sizes, forKey: Self.key)
    }

    private static func entry(_ feature: FeatureID, _ display: String) -> String {
        "\(display)|\(feature.rawValue)"
    }

    /// Keeps a size between the module's normal size and the most the display allows.
    nonisolated static func clamped(_ size: CGSize, min lower: CGSize, max upper: CGSize) -> CGSize {
        CGSize(
            width: Swift.min(Swift.max(size.width, lower.width), Swift.max(upper.width, lower.width)),
            height: Swift.min(Swift.max(size.height, lower.height), Swift.max(upper.height, lower.height))
        )
    }
}
