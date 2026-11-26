import SwiftUI

/// Settings › Appearance: everything about how Dynotch looks (spec D-5).
struct AppearanceSettingsView: View {
    @Bindable var settings: AppSettings
    @AppStorage(AppleStyle.crispKey) private var crispLook = true
    @AppStorage(SmartOpening.noticeMinutesKey) private var noticeMinutes = 5

    var body: some View {
        Form {
            Section {
                Picker("Design", selection: $settings.design) {
                    ForEach(NotchDesign.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                // The old black look for notifications under the notch (spec D-28).
                Toggle("Black notifications under the notch", isOn: Bindable(NotificationLook.shared).black)
                SettingsSlider(
                    title: "Open panel opacity", value: $settings.panelOpacity, range: AppSettings.panelOpacityRange, step: 0.05
                ) { "\(Int(($0 * 100).rounded())) %" }
                // Black has no glass: shown off and inactive, the choice kept for the glass designs (spec D-17c).
                Toggle("Accent colour in the glass", isOn: Binding(
                    get: { settings.glassAccent && settings.design != .black }, set: { settings.glassAccent = $0 }
                ))
                .disabled(settings.design == .black)
                // How much of the accent goes into the glass (spec D-17f).
                SettingsSlider(
                    title: "Accent strength", value: $settings.glassAccentStrength,
                    range: AppSettings.glassAccentStrengthRange, step: 0.05
                ) { "\(Int(($0 * 100).rounded())) %" }
                .disabled(settings.design == .black || !settings.glassAccent)
                // Trial (spec D-18): deeper clear glass over a full blur, lighter fills, stronger text.
                Toggle("Crisp look", isOn: $crispLook)
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
                // Under the notch or in its line, with or without Wings (spec PV-66, PV-73).
                Toggle("Small notices beside the notch", isOn: Binding(
                    get: { settings.noticesBeside },
                    set: { settings.noticePlacement = $0 ? .beside : .dropDown }
                ))
            } footer: {
                Text("Hovering spreads the notch into wings at both sides with the current module at a glance (and the "
                    + "module strip below, if on). A click on the notch or a two-finger swipe down opens it fully; the wings' "
                    + "buttons work on their own. Small notices beside the notch: notifications and other pop-ups stand "
                    + "in the notch's line like in Wings, without turning the rest of Wings on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            smartSection
        }
        .formStyle(.grouped)
    }

    /// Which module opening by hover shows (spec SO-1…SO-4).
    private var smartSection: some View {
        Section {
            ForEach(SmartRule.allCases, id: \.self) { rule in
                Toggle(rule.title, isOn: Binding(get: { settings.isSmartRuleOn(rule) }, set: { settings.setSmartRule(rule, enabled: $0) }))
            }
            // How long the latest notification leads the hover (spec SO-10).
            Stepper(value: $noticeMinutes, in: SmartOpening.noticeMinutesRange) {
                Text("Latest notification for \(noticeMinutes) min")
            }
            .disabled(!settings.isSmartRuleOn(.notice))
        } header: {
            Text("Smart opening")
        } footer: {
            Text("Opening by hover shows the first module that fits, in this order; otherwise the last one used. "
                + "Each event does it once, except the latest notification, which leads every opening for a while. "
                + "Shortcuts and the module strip always open what you pick.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var designNote: String {
        var note = "For the open notch, notifications and the menu bar panels; the closed notch stays black like the "
            + "hardware notch. On external displays the notch can also float below the top edge as a pill."
        note += " The open panel has a soft rim light and shadow, a black that deepens towards the bottom, glass tinted "
            + "to the wallpaper, and an even black-to-glass fade."
        note += " Liquid glass is the glass of Black to glass all over; Black over glass parts the black top row "
            + "from the glass with a sharp line. Notifications under the notch keep a black top in every design, "
            + "or stay all black with Black notifications under the notch."
        note += " Crisp look (trial): a stronger blur, lighter grey fills, brighter text."
        if #unavailable(macOS 26.0) { note += " Liquid glass needs macOS 26; here a dark blur is used instead." }
        return note
    }
}
