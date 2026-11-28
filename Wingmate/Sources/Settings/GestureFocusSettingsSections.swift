import SwiftUI

/// Settings › General: swipe drop-downs, the trackpad's edge sliders and the Focus Shortcuts
/// (spec DS-1, ES-1…ES-3, FC-3).
struct GestureFocusSettingsSections: View {
    @Bindable var gestures = GestureSettings.shared
    @Bindable var focus = FocusModeService.shared
    @State private var shortcutNames: [String] = []

    var body: some View {
        Section {
            Toggle("Open drop-downs with a swipe down", isOn: $gestures.dropdownsOnSwipe)
        } footer: {
            footer("The tasks, badges, AI ring and the other items beside the closed notch stay closed on hover; "
                + "swipe down with two fingers (or flick down on a Magic Mouse) over one to open it, up to close it.")
        }
        Section {
            Toggle("Trackpad edge sliders", isOn: $gestures.edgeSliders)
            Toggle("Left edge: volume", isOn: $gestures.edgeVolume)
                .disabled(!gestures.edgeSliders)
            Toggle("Right edge: display brightness", isOn: $gestures.edgeBrightness)
                .disabled(!gestures.edgeSliders || !EdgeSliderService.canSet(.right))
            Toggle("Top edge: keyboard backlight", isOn: $gestures.edgeKeyboard)
                .disabled(!gestures.edgeSliders || !EdgeSliderService.canSet(.top))
            Picker("Steps", selection: $gestures.edgeSteps) {
                ForEach(EdgeSliderSteps.allCases) { Text($0.title).tag($0) }
            }
            .disabled(!gestures.edgeSliders)
        } header: {
            Text("Trackpad")
        } footer: {
            footer("Slide one finger up the left or right edge, or along the top edge to the right. "
                + (EdgeSliderService.canSet(.top) ? "" : "This Mac has no keyboard backlight to set. ")
                + "macOS steps tap the trackpad on every step; 1% steps set an exact level.")
        }
        Section {
            ForEach(focus.modes) { mode in
                ShortcutChoice(title: mode.name, names: shortcutNames, selection: Binding(
                    get: { focus.onShortcuts[mode.id] ?? "" },
                    set: { focus.onShortcuts[mode.id] = $0.isEmpty ? nil : $0 }
                ))
            }
            ShortcutChoice(title: "Turn Focus off", names: shortcutNames, selection: $focus.offShortcut)
        } header: {
            Text("Focus")
        } footer: {
            footer("macOS lets no app switch a Focus, so the moon in the notch's top row runs your Shortcuts: for each "
                + "Focus one with Set Focus › On, and one that turns it off. Wingmate turns it off at the end of the "
                + "hour, two hours or at 7:00 the next morning. Listing the Focuses needs Full Disk Access.")
        }
        .task {
            focus.refresh()
            shortcutNames = await Task.detached { ShortcutsApp.names() }.value
        }
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
