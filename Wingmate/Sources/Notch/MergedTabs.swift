import SwiftUI

/// The tabs of a merged module (spec MG-2), handed to a module whose own header shows them.
struct MergedTabs {
    let tabs: [FeatureID]
    let selected: FeatureID
    let select: @MainActor (FeatureID) -> Void
}

private struct MergedTabsKey: EnvironmentKey {
    static let defaultValue: MergedTabs? = nil
}

extension EnvironmentValues {
    /// Set while the module is a tab of a merged module whose header holds the picker (spec MG-2).
    var mergedTabs: MergedTabs? {
        get { self[MergedTabsKey.self] }
        set { self[MergedTabsKey.self] = newValue }
    }
}

/// The Chat | Usage picker in the AI module's header row (spec MG-2).
struct MergedTabsPicker: View {
    @Environment(\.mergedTabs) private var mergedTabs

    var body: some View {
        if let mergedTabs {
            CapsulePicker(
                items: mergedTabs.tabs,
                selection: Binding(get: { mergedTabs.selected }, set: { mergedTabs.select($0) }),
                title: \.tabTitle
            )
        }
    }
}
