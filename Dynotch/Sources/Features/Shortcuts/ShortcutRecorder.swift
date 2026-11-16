import AppKit
import SwiftUI

/// Shows a feature's shortcut; a click records a new one (spec SC-1). Esc cancels, Delete clears.
struct ShortcutRecorder: View {
    let shortcut: KeyShortcut?
    let onChange: (KeyShortcut?) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggleRecording) {
            Text(isRecording ? "Type shortcut…" : (shortcut?.display ?? "Add shortcut"))
                .font(.system(size: 11, weight: shortcut == nil ? .regular : .semibold))
                .monospacedDigit()
                .foregroundStyle(isRecording ? Color.accentColor : (shortcut == nil ? Color.secondary : Color.primary))
                .frame(minWidth: 86)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.08)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click, then press the keys (with ⌘, ⌥ or ⌃). Esc cancels, Delete removes the shortcut.")
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
            return
        }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { handle(event) }
            return nil
        }
    }

    private func handle(_ event: NSEvent) {
        switch Int(event.keyCode) {
        case 53: // Esc
            break
        case 51, 117: // Delete
            onChange(nil)
        default:
            guard let recorded = KeyShortcut.make(
                keyCode: event.keyCode, flags: event.modifierFlags, characters: event.charactersIgnoringModifiers
            ) else {
                NSSound.beep()
                return
            }
            onChange(recorded)
        }
        stopRecording()
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}
