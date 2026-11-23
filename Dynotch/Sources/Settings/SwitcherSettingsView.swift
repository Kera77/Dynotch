import SwiftUI

/// Settings › Switcher: the window switcher (spec AS-1…AS-12).
struct SwitcherSettingsView: View {
    @ObservedObject var settings: SwitcherSettings
    /// The modules and whether they are on (spec QS-10).
    @ObservedObject var modules: AppSettings
    /// The module row being dragged to a new place (spec SD-4).
    @State private var draggedModule: FeatureID?

    var body: some View {
        Form {
            AccessSection(
                permissions: settings.showsPreviews ? [.accessibility, .screenRecording] : [.accessibility],
                footer: "Accessibility lists and switches the windows; Screen Recording shows their previews."
            )
            Section {
                Toggle("Window switcher", isOn: $settings.isOn)
            } footer: {
                Text("Switch between windows from the notch, with a shortcut or a swipe.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Look") {
                Picker("View", selection: $settings.style) {
                    ForEach(SwitcherStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Size", selection: $settings.size) {
                    ForEach(SwitcherSize.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Window previews", isOn: $settings.showsPreviews)
                    .onChange(of: settings.showsPreviews) { _, enabled in
                        if enabled, !SwitcherPreviews.isAllowed { SwitcherPreviews.requestAccess() }
                    }
            }
            Section("Windows") {
                Picker("Show", selection: $settings.scope) {
                    ForEach(SwitcherScope.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Group windows by app", isOn: $settings.groupsByApp)
                Toggle("Minimized windows", isOn: $settings.showsMinimized)
                Toggle("Hidden apps", isOn: $settings.showsHidden)
                Toggle("Only the display under the pointer", isOn: $settings.currentDisplayOnly)
                Toggle("Only covered windows", isOn: $settings.onlyCovered)
                    .help("Leaves out the windows you can see; minimized, hidden and other Spaces' windows stay")
                if settings.onlyCovered {
                    SettingsSlider(
                        title: "Covered at least", value: $settings.coverThreshold, range: SwitcherSettings.coverRange, step: 0.05
                    ) { "\(Int(($0 * 100).rounded())) %" }
                }
            }
            Section {
                LabeledContent("Shortcut") {
                    ShortcutRecorder(shortcut: settings.shortcut) { settings.shortcut = $0 }
                }
                Picker("After the keys are released", selection: $settings.holdsAfterRelease) {
                    Text("Switch").tag(false)
                    Text("Stay open").tag(true)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Keyboard")
            } footer: {
                Text("Hold the modifier: the key again or → moves on, ⇧ or ← goes back; W closes the window, M minimizes, "
                    + "Q quits the app, H hides it; Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker("Swipe", selection: $settings.swipeFingers) {
                    Text("Off").tag(0)
                    Text("3 fingers").tag(3)
                    Text("4 fingers").tag(4)
                }
                .pickerStyle(.segmented)
                // How far the fingers move for one window: shorter is faster (spec AS-11b).
                SettingsSlider(
                    title: "Distance per window", value: $settings.swipeStep, range: SwitcherSettings.swipeStepRange, step: 0.01
                ) { "\(Int(($0 * 100).rounded())) %" }
                .disabled(noSwipe)
                // A swipe shorter than this only switches; longer drops the switcher down (spec AS-16).
                SettingsSlider(
                    title: "Show switcher after", value: $settings.showDelay, range: SwitcherSettings.showDelayRange, step: 0.05
                ) { String(format: "%.2f s", $0) }
                .disabled(noSwipe)
                Toggle("Short swipe switches to the previous app", isOn: $settings.quickSwipeToPreviousApp)
                    .disabled(settings.swipeFingers == 0)
                Button("Open Trackpad Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } header: {
                Text("Trackpad")
            } footer: {
                Text("Swipe sideways to step through the windows; lifting the fingers switches, swiping up cancels. "
                    + "macOS also swipes between Spaces with three fingers: set that to four fingers in Trackpad › More "
                    + "Gestures, or the two happen together.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // The swipe up after the sideways swipe: both are trackpad settings (spec SD-9).
            moduleSection
            moduleRowSection
            CollapsibleListSection(title: "Add a module", count: addableModules.count, prompt: "Search modules") { search in
                ForEach(addableModules.filter { settingsSearchMatches(search, $0.title) }) { feature in
                    HStack(spacing: 8) {
                        moduleLabel(feature)
                        Spacer()
                        Button("Add") { settings.addToModuleRow(feature) }
                            .controlSize(.small)
                    }
                }
            }
            .disabled(!settings.moduleSwitcherOn)
        }
        .formStyle(.grouped)
    }

    /// The distance and the delay serve the swipe up too (spec QS-5, QS-7).
    private var noSwipe: Bool { settings.swipeFingers == 0 && !settings.moduleSwitcherOn }

    /// The modules in the swipe-up row, dragged to reorder (spec QS-10, SD-4).
    private var moduleRowSection: some View {
        Section {
            if settings.moduleRow.isEmpty {
                Text("No modules yet. Add one from the list below.")
                    .foregroundStyle(.secondary)
            }
            ForEach(settings.moduleRow, id: \.self) { feature in
                HStack(spacing: 8) {
                    DragHandle()
                    moduleLabel(feature)
                    Spacer()
                    Button {
                        settings.removeFromModuleRow(feature)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove")
                    .accessibilityLabel("Remove \(feature.title)")
                }
                .reorderable(feature, in: settings.moduleRow, dragged: $draggedModule, id: feature.rawValue) {
                    settings.moveInModuleRow(from: $0, to: $1)
                }
            }
        } header: {
            Text("In the swipe row")
        } footer: {
            Text("Shown in this order, always in one row. A module that is off stays here but is left out of the row.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(!settings.moduleSwitcherOn)
    }

    /// Every module not yet in the row, in the modules' order.
    private var addableModules: [FeatureID] {
        modules.featureOrder.filter { !settings.moduleRow.contains($0) }
    }

    private func moduleLabel(_ feature: FeatureID) -> some View {
        SettingsRowLabel(title: feature.title, detail: modules.isEnabled(feature) ? nil : "Off") {
            Image(systemName: feature.symbolName)
                .foregroundStyle(.secondary)
        }
    }

    /// The module switcher on a swipe up (spec QS-1, QS-9).
    private var moduleSection: some View {
        Section {
            Toggle("Module switcher", isOn: $settings.moduleSwitcherOn)
            Picker("Swipe up", selection: $settings.moduleFingers) {
                Text("3 fingers").tag(3)
                Text("4 fingers").tag(4)
            }
            .pickerStyle(.segmented)
            .disabled(!settings.moduleSwitcherOn)
        } header: {
            Text("Modules")
        } footer: {
            Text("Swipe up to show the modules chosen below, the last opened one picked; swipe sideways to pick another, "
                + "lift the fingers to open it, swipe back down to cancel. macOS opens Mission Control with a "
                + "three-finger swipe up: set that to four fingers or off in Trackpad › More Gestures.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
