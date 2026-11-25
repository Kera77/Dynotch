import SwiftUI
import UniformTypeIdentifiers

/// Which modules are on, their order, menu bar icons and shortcuts, the module strip and the module
/// switcher (spec M-3, M-7, SC-1, SC-2, QS-13, QS-14).
struct FeatureSettingsView: View {
    @Bindable var settings: AppSettings
    var shortcuts: ShortcutStore
    /// The module switcher's settings (spec QS-13); nil before the switcher is set up.
    var switcher: SwitcherSettings?

    /// The row being dragged to a new place (spec M-3, SD-4).
    @State private var dragged: FeatureID?

    var body: some View {
        Form {
            Section {
                // Batteries and AI Usage are always tabs of System and AI: not listed (spec MG-9).
                ForEach(settings.featureOrder.filter { $0.mergeHost == nil }, id: \.self) { feature in
                    FeatureRow(feature: feature, settings: settings, shortcuts: shortcuts) { musicOptions }
                        .reorderable(feature, in: settings.featureOrder, dragged: $dragged, id: feature.rawValue) {
                            settings.moveFeatures(from: $0, to: $1)
                        }
                }
            } header: {
                Text("Modules")
            } footer: {
                Text("Drag a row to reorder. At least one module must stay on. › shows a module's shortcut and options: "
                    + "\"Menu bar\" also adds an icon to the menu bar. "
                    + "A module hidden from the modules still runs and opens with its shortcut or the swipe-up row. "
                    + "Batteries is a tab of System, AI Usage a tab of AI. "
                    + "A shortcut opens the module; pressing it again closes it. \"Pin\" keeps it open when opened that way.")
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
            if let switcher { ModuleSwitcherSections(settings: switcher, modules: settings) }
            ModuleStripSection(settings: settings)
        }
        .formStyle(.grouped)
    }

    /// The cover beside the notch (spec MU-8).
    @ViewBuilder private var musicOptions: some View {
        Toggle("Cover beside the notch", isOn: $settings.showsNowPlaying)
            .disabled(!settings.isEnabled(.music))
            .help("Show what Spotify plays beside the closed notch; hovering it opens Music")
    }

}

/// One module: on or off, its shortcut beside the name; › opens its options (spec SD-5).
private struct FeatureRow<Music: View>: View {
    let feature: FeatureID
    @Bindable var settings: AppSettings
    var shortcuts: ShortcutStore
    @ViewBuilder let musicOptions: () -> Music

    @State private var isOpen = false

    private var isOn: Bool { settings.isSwitchedOn(feature) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                DragHandle()
                Toggle(isOn: Binding(get: { isOn }, set: { settings.setEnabled(feature, $0) })) {
                    HStack(spacing: 8) {
                        SettingsRowLabel(title: feature.title, detail: shortcuts.shortcuts[feature]?.display) {
                            Image(systemName: feature.symbolName).foregroundStyle(.secondary)
                        }
                        // Left of the switch, so the switches stay in one column (spec M-19).
                        if !settings.isListed(feature) {
                            Spacer(minLength: 0)
                            Image(systemName: "eye.slash")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .help("Not among the modules: opens with its shortcut or the swipe-up row")
                                .accessibilityLabel("Hidden from the modules")
                        }
                    }
                }
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
            if isOpen { options }
        }
        .revealWhenOpened(isOpen)
    }

    private var options: some View {
        // A little more room between the option rows (spec M-19).
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Shortcut") {
                ShortcutRecorder(shortcut: shortcuts.shortcuts[feature]) { shortcuts.set($0, for: feature) }
            }
            .disabled(!isOn)
            // Without a shortcut there is nothing to pin: shown unticked (spec SC-2).
            Toggle("Pin when opened with the shortcut", isOn: Binding(
                get: { shortcuts.pinsWhenOpened(feature) }, set: { shortcuts.setPins(feature, $0) }
            ))
            .disabled(!isOn || shortcuts.shortcuts[feature] == nil)
            // Hidden: still runs, opens with its shortcut or the swipe-up row (spec M-18).
            Toggle("Among the modules", isOn: Binding(
                get: { settings.isListed(feature) }, set: { settings.setListed(feature, $0) }
            ))
            .disabled(!isOn)
            .help("Show \(feature.title) in the top row, the strip and the swipes; off: it opens with its shortcut or the swipe-up row")
            if AppSettings.menuBarFeatures.contains(feature) {
                Toggle("Menu bar icon", isOn: Binding(
                    get: { settings.showsInMenuBar(feature) }, set: { settings.setShowsInMenuBar(feature, $0) }
                ))
                .disabled(!isOn)
            }
            if feature == .music { musicOptions() }
        }
        .font(.callout)
        .padding(.leading, 34)
    }
}
