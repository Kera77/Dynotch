import SwiftUI

/// Settings › Switcher: the window switcher (spec AS-1…AS-12).
struct SwitcherSettingsView: View {
    @ObservedObject var settings: SwitcherSettings
    @State private var previewsAllowed = SwitcherPreviews.isAllowed

    var body: some View {
        Form {
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
                        previewsAllowed = SwitcherPreviews.isAllowed
                    }
                if settings.showsPreviews, !previewsAllowed {
                    Text("Previews need Screen Recording (Settings › Permissions). Until then icons show.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    LabeledContent("Covered at least") {
                        HStack {
                            Slider(value: $settings.coverThreshold, in: SwitcherSettings.coverRange, step: 0.05)
                            Text("\(Int((settings.coverThreshold * 100).rounded()))%").monospacedDigit().frame(width: 40)
                        }
                    }
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
            moduleSection
            Section {
                Picker("Swipe", selection: $settings.swipeFingers) {
                    Text("Off").tag(0)
                    Text("3 fingers").tag(3)
                    Text("4 fingers").tag(4)
                }
                .pickerStyle(.segmented)
                // How far the fingers move for one window: shorter is faster (spec AS-11b).
                LabeledContent("Distance per window") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.swipeStep, in: SwitcherSettings.swipeStepRange, step: 0.01)
                            .frame(width: 160)
                        Text("\(Int((settings.swipeStep * 100).rounded())) % of the trackpad")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(noSwipe)
                // A swipe shorter than this only switches; longer drops the switcher down (spec AS-16).
                LabeledContent("Show switcher after") {
                    HStack(spacing: 8) {
                        Slider(value: $settings.showDelay, in: SwitcherSettings.showDelayRange, step: 0.05)
                            .frame(width: 160)
                        Text(String(format: "%.2f s", settings.showDelay))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
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
        }
        .formStyle(.grouped)
    }

    /// The distance and the delay serve the swipe up too (spec QS-5, QS-7).
    private var noSwipe: Bool { settings.swipeFingers == 0 && !settings.moduleSwitcherOn }

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
            Text("Swipe up to show the modules that have a shortcut, the last opened first; swipe sideways to pick one, "
                + "lift the fingers to open it, swipe back down to cancel. macOS opens Mission Control with a "
                + "three-finger swipe up: set that to four fingers or off in Trackpad › More Gestures.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
