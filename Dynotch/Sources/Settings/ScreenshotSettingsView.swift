import SwiftUI

/// Settings › Screenshots (spec SH-1…SH-12): the shortcut, the modes and their order, sound for
/// recordings, and the editor's tools.
struct ScreenshotSettingsView: View {
    @ObservedObject var settings: ScreenshotSettings
    @State private var dragged: CaptureMode?

    var body: some View {
        Form {
            AccessSection(permissions: [.screenRecording])
            Section {
                Toggle("Screenshots", isOn: $settings.isOn)
                LabeledContent("Shortcut") {
                    ShortcutRecorder(shortcut: settings.shortcut) { settings.shortcut = $0 }
                }
                // A quick press takes the first mode without the bar popping up (spec SH-14).
                SettingsSlider(
                    title: "Show modes after", value: $settings.chooserDelay, range: ScreenshotSettings.chooserDelayRange, step: 0.05
                ) { String(format: "%.2f s", $0) }
            } footer: {
                Text("Hold the modifiers and press the key again to step to the next mode; letting go takes the picture. "
                    + "Esc cancels. Pictures go to Pictures › Screenshots and onto the clipboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Modes, in the order of the key presses") {
                ForEach(settings.order) { mode in modeRow(mode) }
            }
            Section("Screen recording") {
                Toggle("Record the Mac's sound", isOn: $settings.recordsSystemAudio)
                Toggle("Record the microphone", isOn: $settings.recordsMicrophone)
            }
            Section("Editor tools") {
                ForEach(EditorTool.allCases) { tool in
                    Toggle(isOn: Binding(get: { settings.isOn(tool) }, set: { settings.setOn(tool, $0) })) {
                        Label(tool.title, systemImage: tool.symbol)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func modeRow(_ mode: CaptureMode) -> some View {
        // No order number: the order of the rows is the order (spec SD-13).
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal").foregroundStyle(.secondary).accessibilityLabel("Drag to reorder")
            Toggle(isOn: Binding(get: { settings.isOn(mode) }, set: { settings.setOn(mode, $0) })) {
                Label(mode.title, systemImage: mode.symbol)
            }
        }
        .opacity(dragged == mode ? 0.4 : 1)
        .onDrag {
            dragged = mode
            let binding = $dragged
            ReorderDragEnd.watch { binding.wrappedValue = nil }
            return NSItemProvider(object: mode.rawValue as NSString)
        }
        .onDrop(of: [.text], delegate: ModeDropDelegate(target: mode, settings: settings, dragged: $dragged))
    }
}

private struct ModeDropDelegate: DropDelegate {
    let target: CaptureMode
    let settings: ScreenshotSettings
    @Binding var dragged: CaptureMode?

    func dropEntered(info: DropInfo) {
        guard let dragged else { return }
        withAnimation(Motion.quick) { settings.move(dragged, to: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        ReorderDragEnd.finish { dragged = nil }
        return true
    }
}
