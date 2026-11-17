import AppKit
import SwiftUI

/// Settings › Clipboard: the clipboard's shortcuts and size, and the file tray (spec CB-7, FT-6).
struct ClipboardSettingsView: View {
    @ObservedObject var clipboard: ClipboardStore
    @ObservedObject var tray: TrayStore

    var body: some View {
        Form {
            Section {
                LabeledContent("Clipboard items") {
                    ShortcutRecorder(shortcut: clipboard.historyShortcut) { clipboard.historyShortcut = $0 }
                }
                LabeledContent("Saved items") {
                    ShortcutRecorder(shortcut: clipboard.savedShortcut) { clipboard.savedShortcut = $0 }
                }
                Stepper(value: $clipboard.limit, in: ClipboardStore.limitRange, step: 5) {
                    LabeledContent("Keep", value: "\(clipboard.limit) items")
                }
            } header: {
                Text("Clipboard")
            } footer: {
                Text("Press the shortcut once to paste the newest item. Keep holding its modifier to choose: the key again or "
                    + "← → move, ↑ ↓ switch between clipboard and saved, letting go pastes, Esc cancels. Copies from password "
                    + "managers are never kept. On a Hungarian keyboard ⌥V types „, which the shortcut takes over.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                ForEach(clipboard.excludedApps, id: \.self) { identifier in
                    HStack {
                        Text(Self.name(of: identifier))
                        Spacer()
                        Button("Remove") { clipboard.setExcluded(identifier, false) }
                            .buttonStyle(.link)
                    }
                }
                Button("Add App…", action: addExcludedApp)
            } header: {
                Text("Not kept from these apps")
            }
            Section {
                Picker("Files leave the tray", selection: $tray.retentionDays) {
                    ForEach(TrayStore.retentionChoices, id: \.self) { days in
                        Text(days == 0 ? "Never" : "After \(days) day\(days == 1 ? "" : "s")").tag(days)
                    }
                }
            } header: {
                Text("File tray")
            } footer: {
                Text("The tray keeps references to the files, not copies; files without a lasting place (e.g. dragged from a "
                    + "browser) are copied into Dynotch's tray folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private static func name(of identifier: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
            .map { FileManager.default.displayName(atPath: $0.path) } ?? identifier
    }

    private func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url, let identifier = Bundle(url: url)?.bundleIdentifier else { return }
        clipboard.setExcluded(identifier, true)
    }
}
