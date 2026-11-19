import SwiftUI

/// Settings › Appearance: everything about how Dynotch looks (spec D-5).
struct AppearanceSettingsView: View {
    @ObservedObject var settings: AppSettings
    @AppStorage(AppleStyle.key) private var appleStyle = false

    var body: some View {
        Form {
            Section {
                Picker("Design", selection: $settings.design) {
                    ForEach(NotchDesign.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Look", selection: $settings.refinedDesign) {
                    Text("Refined").tag(true)
                    Text("Original").tag(false)
                }
                .pickerStyle(.segmented)
                // Temporary: to compare the Apple style with the current look (spec D-15).
                Picker("Style", selection: $appleStyle) {
                    Text("Apple").tag(true)
                    Text("Current").tag(false)
                }
                .pickerStyle(.segmented)
                .help("Apple: system type sizes, colours, label levels, corners, motion and buttons in the notch")
                LabeledContent("Open panel opacity") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.panelOpacity, in: AppSettings.panelOpacityRange, step: 0.05)
                            .frame(width: 160)
                        Text("\(Int((settings.panelOpacity * 100).rounded())) %")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                }
                Toggle("Resize modules from the bottom right corner", isOn: $settings.resizableModules)
                Picker("Displays without a notch", selection: $settings.externalStyle) {
                    ForEach(ExternalNotchStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(designNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                TopRowSettingsRows()
            } header: {
                Text("Buttons beside the notch")
            } footer: {
                Text("Drag to reorder, or ⌘-drag them in the notch. Settings always stays.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Picker("Open settings", selection: $settings.settingsPresentation) {
                    Text("In the notch").tag(SettingsPresentation.notch)
                    Text("In a window").tag(SettingsPresentation.window)
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle("Rounded notch, like the Dynamic Island", isOn: $settings.roundedNotch)
                Toggle("Round only the sides with something shown", isOn: $settings.roundOnlyWhereShown)
                    .disabled(!settings.roundedNotch)
                Toggle("Hide the notch over full-screen apps", isOn: $settings.hideInFullScreen)
            } footer: {
                Text("Rounded: the closed notch is a capsule that straightens out as it opens. Hidden: nothing shows "
                    + "beside the notch, not even notifications; move the pointer to the very top edge to open it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("DyNotch Wings", isOn: $settings.hoverPreview)
            } footer: {
                Text("Hovering spreads the notch into wings at both sides with the current module at a glance (and the "
                    + "module strip below, if on). A click on the notch or a two-finger swipe down opens it fully; the wings' "
                    + "buttons work on their own.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            stripSection
            smartSection
        }
        .formStyle(.grouped)
    }

    /// The modules under the notch (spec MS-1…MS-4).
    private var stripSection: some View {
        Section {
            Toggle("Show the modules when resting at the notch's bottom edge", isOn: $settings.moduleStrip)
            LabeledContent("Show after") {
                HStack {
                    Slider(value: $settings.moduleStripDelay, in: AppSettings.moduleStripDelayRange, step: 0.05)
                        .frame(width: 160)
                    Text("\(settings.moduleStripDelay, specifier: "%.2f") s")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }
            .disabled(!settings.moduleStrip)
            LabeledContent("Bottom edge") {
                HStack {
                    Slider(value: $settings.moduleStripBand, in: AppSettings.moduleStripBandRange)
                        .frame(width: 160)
                    Text("1/\(Int((1 / settings.moduleStripBand).rounded()))")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }
            .disabled(!settings.moduleStrip)
            StripModulesRows(settings: settings)
                .disabled(!settings.moduleStrip)
        } header: {
            Text("Module strip")
        } footer: {
            Text("Rest the pointer on the bottom part of the notch and the modules appear under it; click one to open it. "
                + "Moving higher opens the notch as before.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Which module opening by hover shows (spec SO-1…SO-4).
    private var smartSection: some View {
        Section {
            ForEach(SmartRule.allCases, id: \.self) { rule in
                Toggle(rule.title, isOn: Binding(get: { settings.isSmartRuleOn(rule) }, set: { settings.setSmartRule(rule, enabled: $0) }))
            }
        } header: {
            Text("Smart opening")
        } footer: {
            Text("Opening by hover shows the first module that fits, in this order; otherwise the last one used. "
                + "Each event does it once. Shortcuts and the module strip always open what you pick.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var designNote: String {
        var note = "For the open notch, notifications and the menu bar panels; the closed notch stays black like the "
            + "hardware notch. On external displays the notch can also float below the top edge as a pill."
        note += " Refined adds a soft rim light and shadow, a black that deepens towards the bottom, glass tinted to "
            + "the wallpaper, and an even black-to-glass fade."
        if #unavailable(macOS 26.0) { note += " Liquid glass needs macOS 26; here a dark blur is used instead." }
        return note
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
        dragged = nil
        return true
    }
}
