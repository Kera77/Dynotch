import SwiftUI
import UniformTypeIdentifiers

/// Which modules are on, their order, menu bar icons and shortcuts (spec M-3, M-7, SC-1, SC-2).
struct FeatureSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var shortcuts: ShortcutStore

    /// The row being dragged to a new place (spec M-3).
    @State private var dragged: FeatureID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(Array(settings.featureOrder.enumerated()), id: \.element) { index, feature in
                        row(feature)
                            .padding(.horizontal, 8)
                            .frame(height: 34)
                            .background(Color.primary.opacity(index.isMultiple(of: 2) ? 0.04 : 0))
                            .opacity(dragged == feature ? 0.4 : 1)
                            .onDrag {
                                dragged = feature
                                return NSItemProvider(object: feature.rawValue as NSString)
                            }
                            .onDrop(
                                of: [.text],
                                delegate: FeatureDropDelegate(target: feature, settings: settings, dragged: $dragged)
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack {
                Label("Pin the notch open / release it", systemImage: "lock.fill")
                Spacer()
                ShortcutRecorder(shortcut: shortcuts.pinShortcut) { shortcuts.setPinShortcut($0) }
            }
            Text("Drag a row to reorder. At least one module must stay on. \"Menu bar\" also adds an icon to the menu bar. "
                + "\"In System\" / \"In AI\" shows the module as a tab of that module. "
                + "A shortcut opens the module in the notch; pressing it again closes it. \"Pin\" keeps it open when opened that way.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }

    private func row(_ feature: FeatureID) -> some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .help("Drag to reorder")
                .accessibilityLabel("Drag to reorder")
            Toggle(isOn: binding(for: feature)) {
                Label {
                    Text(feature.title)
                } icon: {
                    Image(systemName: feature.symbolName)
                }
            }
            // A merged module is a tab of its host and is on while the host is (spec MG-1, MG-4).
            .disabled(settings.isMerged(feature))
            .padding(.leading, settings.isMerged(feature) ? 14 : 0)
            Spacer()
            if let host = feature.mergeHost {
                Toggle("In \(host.title)", isOn: Binding(get: { settings.isMerged(feature) }, set: { settings.setMerged(feature, $0) }))
                    .toggleStyle(.checkbox)
                    .help("Show \(feature.title) as a tab of \(host.title) instead of a module of its own")
            }
            if AppSettings.menuBarFeatures.contains(feature) {
                Toggle("Menu bar", isOn: menuBarBinding(for: feature))
                    .toggleStyle(.checkbox)
                    .disabled(!settings.isEnabled(feature))
                    .help("Also show \(feature.title) as a menu bar icon; off: only in the notch")
            }
            if feature == .music { musicOptions }
            ShortcutRecorder(shortcut: shortcuts.shortcuts[feature]) { shortcuts.set($0, for: feature) }
                .disabled(!settings.isEnabled(feature))
            // Without a shortcut there is nothing to pin: shown unticked (spec SC-2).
            Toggle("Pin", isOn: Binding(get: { shortcuts.pinsWhenOpened(feature) }, set: { shortcuts.setPins(feature, $0) }))
                .toggleStyle(.checkbox)
                .disabled(!settings.isEnabled(feature) || shortcuts.shortcuts[feature] == nil)
                .help("Opening \(feature.title) with its shortcut also pins the notch, so it stays open")
        }
    }

    /// The cover beside the notch, and Music among the modules (spec MU-8).
    @ViewBuilder private var musicOptions: some View {
        Toggle("Cover", isOn: $settings.showsNowPlaying)
            .toggleStyle(.checkbox)
            .disabled(!settings.isEnabled(.music))
            .help("Show what Spotify plays beside the closed notch; hovering it opens Music")
        Toggle("In list", isOn: Binding(
            get: { !settings.unlistedFeatures.contains(.music) },
            set: { if $0 { settings.unlistedFeatures.remove(.music) } else { settings.unlistedFeatures.insert(.music) } }
        ))
        .toggleStyle(.checkbox)
        .disabled(!settings.isEnabled(.music))
        .help("Show Music among the modules; off: it opens only from its cover or its shortcut")
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

/// Moves the dragged row over the one under the pointer, as it is dragged.
@MainActor
private struct FeatureDropDelegate: DropDelegate {
    let target: FeatureID
    let settings: AppSettings
    @Binding var dragged: FeatureID?

    func dropEntered(info: DropInfo) {
        guard let dragged, dragged != target,
              let from = settings.featureOrder.firstIndex(of: dragged),
              let targetIndex = settings.featureOrder.firstIndex(of: target)
        else { return }
        withAnimation(Motion.quick) {
            settings.moveFeatures(from: IndexSet(integer: from), to: targetIndex > from ? targetIndex + 1 : targetIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragged = nil
        return true
    }
}
