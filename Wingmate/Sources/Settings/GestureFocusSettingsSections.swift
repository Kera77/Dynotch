import SwiftUI

/// Settings › General: notifications on a swipe and the trackpad's edge sliders (spec DS-1, DS-4, ES-1…ES-3).
struct GestureFocusSettingsSections: View {
    @Bindable var gestures = GestureSettings.shared

    var body: some View {
        Section {
            Toggle("Open notifications with a swipe down", isOn: $gestures.dropdownsOnSwipe)
        } footer: {
            footer("A new notification, Beeper message or screenshot under the notch stays small on hover; "
                + "swipe down with two fingers (or flick down on a Magic Mouse) over it to open it. "
                + "The tasks, badges, AI ring and the other items beside the notch still open on hover.")
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
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
