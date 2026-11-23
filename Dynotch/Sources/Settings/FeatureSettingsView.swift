import SwiftUI
import UniformTypeIdentifiers

/// Which modules are on, their order, menu bar icons and shortcuts (spec M-3, M-7, SC-1, SC-2).
struct FeatureSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var shortcuts: ShortcutStore

    /// The row being dragged to a new place (spec M-3, SD-4).
    @State private var dragged: FeatureID?

    var body: some View {
        Form {
            Section {
                ForEach(settings.featureOrder, id: \.self) { feature in
                    FeatureRow(feature: feature, settings: settings, shortcuts: shortcuts) { musicOptions }
                        .reorderable(feature, in: settings.featureOrder, dragged: $dragged, id: feature.rawValue) {
                            settings.moveFeatures(from: $0, to: $1)
                        }
                }
            } header: {
                Text("Modules")
            } footer: {
                Text("Drag a row to reorder. At least one module must stay on. › shows a module's shortcut and options: "
                    + "\"Menu bar\" also adds an icon to the menu bar, \"In System\" / \"In AI\" shows it as a tab of "
                    + "that module. A shortcut opens the module; pressing it again closes it. \"Pin\" keeps it open when opened that way.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent {
                    ShortcutRecorder(shortcut: shortcuts.pinShortcut) { shortcuts.setPinShortcut($0) }
                } label: {
                    SettingsRowLabel(title: "Pin the notch open / release it") {
                        Image(systemName: "lock.fill").foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Pin")
            }
        }
        .formStyle(.grouped)
    }

    /// The cover beside the notch, and Music among the modules (spec MU-8).
    @ViewBuilder private var musicOptions: some View {
        Toggle("Cover beside the notch", isOn: $settings.showsNowPlaying)
            .disabled(!settings.isEnabled(.music))
            .help("Show what Spotify plays beside the closed notch; hovering it opens Music")
        Toggle("Among the modules", isOn: Binding(
            get: { !settings.unlistedFeatures.contains(.music) },
            set: { if $0 { settings.unlistedFeatures.remove(.music) } else { settings.unlistedFeatures.insert(.music) } }
        ))
        .disabled(!settings.isEnabled(.music))
        .help("Show Music among the modules; off: it opens only from its cover or its shortcut")
    }

}

/// One module: on or off, its shortcut beside the name; › opens its options (spec SD-5).
private struct FeatureRow<Music: View>: View {
    let feature: FeatureID
    @ObservedObject var settings: AppSettings
    @ObservedObject var shortcuts: ShortcutStore
    @ViewBuilder let musicOptions: () -> Music

    @State private var isOpen = false

    private var isOn: Bool { settings.isEnabled(feature) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                DragHandle()
                Toggle(isOn: Binding(get: { isOn }, set: { settings.setEnabled(feature, $0) })) {
                    SettingsRowLabel(title: feature.title, detail: shortcuts.shortcuts[feature]?.display) {
                        Image(systemName: feature.symbolName).foregroundStyle(.secondary)
                    }
                }
                // A merged module is a tab of its host and is on while the host is (spec MG-1, MG-4).
                .disabled(settings.isMerged(feature))
                Button {
                    withAnimation(Motion.quick) { isOpen.toggle() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Shortcut and options for \(feature.title)")
                .accessibilityLabel("Shortcut and options for \(feature.title)")
            }
            .padding(.leading, settings.isMerged(feature) ? 14 : 0)
            if isOpen { options }
        }
        .revealWhenOpened(isOpen)
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Shortcut") {
                ShortcutRecorder(shortcut: shortcuts.shortcuts[feature]) { shortcuts.set($0, for: feature) }
            }
            .disabled(!isOn)
            // Without a shortcut there is nothing to pin: shown unticked (spec SC-2).
            Toggle("Pin when opened with the shortcut", isOn: Binding(
                get: { shortcuts.pinsWhenOpened(feature) }, set: { shortcuts.setPins(feature, $0) }
            ))
            .disabled(!isOn || shortcuts.shortcuts[feature] == nil)
            if AppSettings.menuBarFeatures.contains(feature) {
                Toggle("Menu bar icon", isOn: Binding(
                    get: { settings.showsInMenuBar(feature) }, set: { settings.setShowsInMenuBar(feature, $0) }
                ))
                .disabled(!isOn)
            }
            if let host = feature.mergeHost {
                Toggle("As a tab of \(host.title)", isOn: Binding(
                    get: { settings.isMerged(feature) }, set: { settings.setMerged(feature, $0) }
                ))
            }
            if feature == .music { musicOptions() }
        }
        .font(.callout)
        .padding(.leading, 34)
    }
}
