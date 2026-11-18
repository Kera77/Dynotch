import SwiftUI

/// Settings › Appearance: everything about how Dynotch looks (spec D-5).
struct AppearanceSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Design", selection: $settings.design) {
                    ForEach(NotchDesign.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
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
                Toggle("Show only a preview on hover", isOn: $settings.hoverPreview)
                LabeledContent("Open fully after") {
                    HStack {
                        Slider(value: $settings.previewDelay, in: AppSettings.previewDelayRange, step: 0.5)
                            .frame(width: 160)
                        Text(settings.previewDelay == 0 ? "Never" : "\(settings.previewDelay, specifier: "%.1f") s")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                }
                .disabled(!settings.hoverPreview)
                Toggle("Click the preview to open fully", isOn: $settings.previewOpensOnClick)
                    .disabled(!settings.hoverPreview)
            } footer: {
                Text("The preview shows one line about the current feature. Shortcuts always open the whole panel.")
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
            StripModulesRows(features: settings.activeFeatures)
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
        if #unavailable(macOS 26.0) { note += " Liquid glass needs macOS 26; here a dark blur is used instead." }
        return note
    }
}

/// Which modules the strip shows (spec MS-5).
private struct StripModulesRows: View {
    let features: [FeatureID]
    @State private var hidden = ModuleStripChoice.hidden

    var body: some View {
        DisclosureGroup("Modules in the strip") {
            ForEach(features) { feature in
                Toggle(isOn: Binding(get: { !hidden.contains(feature) }, set: { shown in
                    ModuleStripChoice.setShown(feature, shown)
                    hidden = ModuleStripChoice.hidden
                })) {
                    Label(feature.title, systemImage: feature.symbolName)
                }
            }
        }
    }
}
