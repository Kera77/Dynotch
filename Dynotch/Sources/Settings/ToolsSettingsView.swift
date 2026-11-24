import SwiftUI

/// Settings › Tools (spec TM-2): Timer, Stopwatch, Pomodoro, Quick toggles and HUD announcements,
/// each with its own switch.
struct ToolsSettingsView: View {
    @Bindable var settings = ToolsSettings.shared
    @State private var shortcutNames: [String] = []

    var body: some View {
        Form {
            timerSection
            Section {
                Toggle("Show beside the notch until reset", isOn: $settings.stopwatchBesideNotch)
                    .disabled(!settings.stopwatchOn)
            } header: {
                sectionHeader("Stopwatch", isOn: $settings.stopwatchOn)
            }
            pomodoroSection
            QuickToggleSettingsSection(settings: settings, shortcutNames: shortcutNames)
            Section {
                ForEach(AnnouncementKind.allCases) { kind in
                    Toggle(kind.title, isOn: Binding(
                        get: { settings.announcements[kind] ?? false }, set: { settings.announcements[kind] = $0 }
                    ))
                }
                .disabled(!settings.announcementsOn)
            } header: {
                sectionHeader("HUD announcements", isOn: $settings.announcementsOn)
            } footer: {
                Text("A short note beside the notch, like the volume. Bluetooth and USB devices keep their own notices.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task {
            shortcutNames = await Task.detached { ShortcutsApp.names() }.value
        }
    }

    private var timerSection: some View {
        Section {
            LabeledContent("Presets") {
                TextField("", text: Binding(
                    get: { settings.presets.map(String.init).joined(separator: ", ") },
                    set: { text in
                        let values = text.split(whereSeparator: { $0 == "," || $0 == " " }).compactMap { Int($0) }
                            .filter { (1...1440).contains($0) }
                        if !values.isEmpty { settings.presets = Array(values.prefix(8)) }
                    }
                ))
                .multilineTextAlignment(.trailing)
                .frame(width: 200)
            }
            Picker("Sound", selection: $settings.sound) {
                Text("None").tag("")
                ForEach(ToolsAlarm.sounds, id: \.self) { Text($0).tag($0) }
            }
            .onChange(of: settings.sound) { _, name in if !name.isEmpty { NSSound(named: NSSound.Name(name))?.play() } }
        } header: {
            sectionHeader("Timer", isOn: $settings.timerOn)
        } footer: {
            Text("Minutes, separated by commas; at most 8. The sound also plays at the end of a pomodoro phase.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var pomodoroSection: some View {
        Section {
            Stepper("Focus: \(settings.focusMinutes) min", value: $settings.focusMinutes, in: 1...180)
            Stepper("Short break: \(settings.shortBreakMinutes) min", value: $settings.shortBreakMinutes, in: 1...60)
            Stepper("Long break: \(settings.longBreakMinutes) min", value: $settings.longBreakMinutes, in: 1...120)
            Stepper("Long break after \(settings.longBreakAfter) focus", value: $settings.longBreakAfter, in: 1...12)
            Toggle("Start breaks by themselves", isOn: $settings.autoStartBreaks)
            Toggle("Start the next focus by itself", isOn: $settings.autoStartFocus)
            ShortcutChoice(title: "Run at focus start", names: shortcutNames, selection: $settings.focusStartShortcut)
            ShortcutChoice(title: "Run at focus end", names: shortcutNames, selection: $settings.focusEndShortcut)
        } header: {
            sectionHeader("Pomodoro", isOn: $settings.pomodoroOn)
        } footer: {
            Text("Shortcuts can turn a macOS Focus on and off; apps can't do that directly.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .disabled(!settings.pomodoroOn)
    }
}

/// A section's title with its switch (spec TM-2).
@MainActor
func sectionHeader(_ title: String, isOn: Binding<Bool>) -> some View {
    HStack {
        Text(title)
        Spacer()
        Toggle("", isOn: isOn).toggleStyle(.switch).controlSize(.mini).labelsHidden()
    }
}

/// One of the user's Shortcuts, or none (spec TM-16, QT-2).
struct ShortcutChoice: View {
    let title: String
    let names: [String]
    @Binding var selection: String

    var body: some View {
        Picker(title, selection: $selection) {
            Text("None").tag("")
            if !selection.isEmpty, !names.contains(selection) { Text(selection).tag(selection) }
            ForEach(names, id: \.self) { Text($0).tag($0) }
        }
    }
}

/// Settings › Tools › Quick toggles (spec QT-2, QT-4, QT-5).
private struct QuickToggleSettingsSection: View {
    @Bindable var settings: ToolsSettings
    let shortcutNames: [String]
    @State private var dragged: QuickToggle?

    var body: some View {
        Section {
            ForEach(settings.toggleOrder.filter(\.isAvailable)) { toggle in
                HStack(spacing: 8) {
                    DragHandle()
                    Toggle(isOn: Binding(
                        get: { !settings.hiddenToggles.contains(toggle) },
                        set: { shown in
                            if shown { settings.hiddenToggles.remove(toggle) } else { settings.hiddenToggles.insert(toggle) }
                        }
                    )) {
                        Label(toggle.title, systemImage: toggle.symbol(isOn: false))
                    }
                    Spacer()
                    ShortcutRecorder(shortcut: settings.toggleShortcuts[toggle]) { settings.setShortcut($0, for: toggle) }
                }
                .reorderable(toggle, in: settings.toggleOrder, dragged: $dragged, id: toggle.rawValue) { source, destination in
                    settings.toggleOrder.move(fromOffsets: source, toOffset: destination)
                }
            }
            ShortcutChoice(title: "Do Not Disturb on", names: shortcutNames, selection: $settings.dndOnShortcut)
            ShortcutChoice(title: "Do Not Disturb off", names: shortcutNames, selection: $settings.dndOffShortcut)
            Toggle("Muted microphone beside the notch", isOn: $settings.micBesideNotch)
            Toggle("Keep Awake beside the notch", isOn: $settings.awakeBesideNotch)
        } header: {
            sectionHeader("Quick toggles", isOn: $settings.togglesOn)
        } footer: {
            Text("Drag to reorder. Right-click Keep Awake in the notch for how long. Dark Mode asks once to control System Events.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .disabled(!settings.togglesOn)
    }
}
