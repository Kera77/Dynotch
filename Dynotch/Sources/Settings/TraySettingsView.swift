import AppKit
import SwiftUI

/// Settings › Tray: how long files stay, and Dynotch's tray folder (spec FT-6, FT-14).
struct TraySettingsView: View {
    @ObservedObject var tray: TrayStore

    var body: some View {
        Form {
            Section {
                Picker("Files leave the tray", selection: $tray.retentionDays) {
                    ForEach(TrayStore.retentionChoices, id: \.self) { days in
                        Text(days == 0 ? "Never" : "After \(days) day\(days == 1 ? "" : "s")").tag(days)
                    }
                }
                LabeledContent("Tray folder") {
                    Button("Show in Finder", action: openFolder)
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

    private func openFolder() {
        try? FileManager.default.createDirectory(at: tray.folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(tray.folder)
    }
}
