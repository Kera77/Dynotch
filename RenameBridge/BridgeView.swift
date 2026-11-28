import AppKit
import SwiftUI

/// The bridge's only window (spec RN-10).
struct BridgeView: View {
    let model: BridgeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dynotch is now Wingmate").font(.headline)
            switch model.phase {
            case .working:
                Text("Same app, new name. Installing Wingmate \(AppInfo.version); your settings come along, and it opens by itself.")
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView().progressViewStyle(.linear)
            case .failed(let message):
                Text("Wingmate could not be installed: \(message)")
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Try Again") { model.start() }
                        .keyboardShortcut(.defaultAction)
                    Button("Download Wingmate") {
                        if let url = AppInfo.repositoryURL?.appendingPathComponent("releases/latest") { NSWorkspace.shared.open(url) }
                    }
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                }
            }
        }
        .padding(20)
        .frame(width: 400, alignment: .leading)
    }
}
