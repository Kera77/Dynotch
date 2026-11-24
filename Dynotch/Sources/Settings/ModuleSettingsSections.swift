import SwiftUI

/// The module switcher on a swipe up and its modules, on the Modules page (spec QS-1, QS-9,
/// QS-10, QS-13).
struct ModuleSwitcherSections: View {
    @ObservedObject var settings: SwitcherSettings
    /// The modules and whether they are on (spec QS-10).
    @ObservedObject var modules: AppSettings

    var body: some View {
        Section {
            Toggle("Module switcher", isOn: $settings.moduleSwitcherOn)
            Picker("Swipe up", selection: $settings.moduleFingers) {
                Text("3 fingers").tag(3)
                Text("4 fingers").tag(4)
            }
            .pickerStyle(.segmented)
            .disabled(!settings.moduleSwitcherOn)
        } header: {
            Text("Module switcher")
        } footer: {
            Text("Swipe up to show the modules chosen below, the last opened one picked; swipe sideways to pick another, "
                + "lift the fingers to open it, swipe back down to cancel. macOS opens Mission Control with a "
                + "three-finger swipe up: set that to four fingers or off in Trackpad › More Gestures.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section {
            SwipeModulesRows(settings: settings, modules: modules)
        } footer: {
            Text("Shown in this order, always in one row. A module that is off shows and opens here too.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(!settings.moduleSwitcherOn)
    }
}

/// Which modules the swipe-up row shows, laid out like the strip's list (spec QS-10, QS-18):
/// the chosen ones first in their order, then the rest; a toggle adds or removes, dragging reorders.
private struct SwipeModulesRows: View {
    @ObservedObject var settings: SwitcherSettings
    @ObservedObject var modules: AppSettings
    @State private var isOpen = false
    /// The row being dragged to a new place (spec SD-4).
    @State private var dragged: FeatureID?

    /// The chosen modules, then every other one in the modules' order.
    private var rows: [FeatureID] {
        settings.moduleRow + modules.featureOrder.filter { !settings.moduleRow.contains($0) }
    }

    var body: some View {
        DisclosureGroup("Swipe-up modules", isExpanded: $isOpen) {
            ForEach(rows, id: \.self) { feature in
                HStack {
                    DragHandle()
                    Toggle(isOn: Binding(get: { settings.moduleRow.contains(feature) }, set: { shown in
                        withAnimation(Motion.quick) {
                            if shown { settings.addToModuleRow(feature) } else { settings.removeFromModuleRow(feature) }
                        }
                    })) {
                        Label(modules.isSwitchedOn(feature) ? feature.title : "\(feature.title) (Off)", systemImage: feature.symbolName)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .reorderable(feature, in: rows, dragged: $dragged, id: feature.rawValue) { from, destination in
                    var moved = rows
                    moved.move(fromOffsets: from, toOffset: destination)
                    let chosen = Set(settings.moduleRow)
                    settings.moduleRow = moved.filter(chosen.contains)
                }
            }
        }
        .revealWhenOpened(isOpen)
    }
}

/// The modules under the notch, on the Modules page (spec MS-1…MS-4, QS-14).
struct ModuleStripSection: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Section {
            Toggle("Show the modules when resting at the notch's bottom edge", isOn: $settings.moduleStrip)
            SettingsSlider(
                title: "Show after", value: $settings.moduleStripDelay, range: AppSettings.moduleStripDelayRange, step: 0.05
            ) { String(format: "%.2f s", $0) }
            .disabled(!settings.moduleStrip)
            SettingsSlider(title: "Bottom edge", value: $settings.moduleStripBand, range: AppSettings.moduleStripBandRange) {
                "1/\(Int((1 / $0).rounded()))"
            }
            .disabled(!settings.moduleStrip)
            Toggle("Open a module when resting on its icon", isOn: $settings.moduleStripHover)
                .disabled(!settings.moduleStrip)
            SettingsSlider(
                title: "Open after", value: $settings.moduleStripHoverDelay, range: AppSettings.moduleStripHoverDelayRange, step: 0.05
            ) { String(format: "%.2f s", $0) }
            // Under the Wings the same wait comes before switching them (spec MS-9).
            .disabled(!settings.moduleStrip || !(settings.moduleStripHover || settings.hoverPreview))
            StripModulesRows(settings: settings)
                .disabled(!settings.moduleStrip)
        } header: {
            Text("Module strip")
        } footer: {
            Text("Rest the pointer on the bottom part of the notch and the modules appear under it; click one to open it "
                + "(or rest on it, when turned on). Moving higher opens the notch as before.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Which modules the strip shows (spec MS-5).
private struct StripModulesRows: View {
    @ObservedObject var settings: AppSettings
    @State private var hidden = ModuleStripChoice.hidden
    @State private var isOpen = false
    /// The row being dragged to a new place (spec MS-6b).
    @State private var dragged: FeatureID?

    var body: some View {
        DisclosureGroup("Modules in the strip", isExpanded: $isOpen) {
            ForEach(settings.listedFeatures) { feature in
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .help("Drag to reorder")
                        .accessibilityLabel("Drag to reorder")
                    Toggle(isOn: Binding(get: { !hidden.contains(feature) }, set: { shown in
                        ModuleStripChoice.setShown(feature, shown)
                        hidden = ModuleStripChoice.hidden
                    })) {
                        Label(feature.title, systemImage: feature.symbolName)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .opacity(dragged == feature ? 0.4 : 1)
                .onDrag {
                    dragged = feature
                    let binding = $dragged
                    ReorderDragEnd.watch { binding.wrappedValue = nil }
                    return NSItemProvider(object: feature.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: StripDropDelegate(target: feature, settings: settings, dragged: $dragged))
            }
        }
        .revealWhenOpened(isOpen)
    }
}

/// Dragging a strip row over another moves it there; the module order follows (spec MS-6b).
private struct StripDropDelegate: DropDelegate {
    let target: FeatureID
    let settings: AppSettings
    @Binding var dragged: FeatureID?

    func dropEntered(info: DropInfo) {
        let listed = settings.listedFeatures
        guard let dragged, dragged != target, let index = listed.firstIndex(of: target) else { return }
        withAnimation(Motion.quick) { settings.moveFeature(dragged, to: index, among: listed) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        ReorderDragEnd.finish { dragged = nil }
        return true
    }
}
