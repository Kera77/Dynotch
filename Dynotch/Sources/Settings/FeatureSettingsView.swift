import SwiftUI

/// Which features are on, their order, menu bar icons and shortcuts (spec M-3, M-7, SC-1, SC-2).
struct FeatureSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var shortcuts: ShortcutStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            List {
                ForEach(settings.featureOrder) { feature in
                    HStack {
                        Toggle(isOn: binding(for: feature)) {
                            Label(feature.title, systemImage: feature.symbolName)
                        }
                        Spacer()
                        if AppSettings.menuBarFeatures.contains(feature) {
                            Toggle("Menu bar", isOn: menuBarBinding(for: feature))
                                .toggleStyle(.checkbox)
                                .disabled(!settings.isEnabled(feature))
                                .help("Also show \(feature.title) as a menu bar icon; off: only in the notch")
                        }
                        ShortcutRecorder(shortcut: shortcuts.shortcuts[feature]) { shortcuts.set($0, for: feature) }
                            .disabled(!settings.isEnabled(feature))
                    }
                }
                .onMove { settings.moveFeatures(from: $0, to: $1) }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Toggle("Keep the notch open (pinned) when opened with a shortcut", isOn: $shortcuts.pinsOnOpen)
            Text("Drag to reorder. At least one feature must stay on. \"Menu bar\" also adds an icon to the menu bar. "
                + "A shortcut opens the feature in the notch; pressing it again closes it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }

    private func menuBarBinding(for feature: FeatureID) -> Binding<Bool> {
        Binding(
            get: { settings.showsInMenuBar(feature) },
            set: { settings.setShowsInMenuBar(feature, $0) }
        )
    }

    private func binding(for feature: FeatureID) -> Binding<Bool> {
        Binding(
            get: { settings.isEnabled(feature) },
            set: { settings.setEnabled(feature, $0) }
        )
    }
}
