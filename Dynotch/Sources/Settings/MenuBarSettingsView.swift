import SwiftUI

/// Settings › Menu bar: the spaces among the menu bar icons (spec MB-5).
struct MenuBarSettingsView: View {
    @ObservedObject var spacers: MenuBarSpacerService

    var body: some View {
        Form {
            MenuBarTintSection(tint: MenuBarTintService.shared)

            Section {
                if spacers.spacers.isEmpty {
                    Text("No spaces yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(spacers.spacers.enumerated()), id: \.element.id) { index, spacer in
                    HStack(spacing: 10) {
                        Text("Space \(index + 1)")
                        Spacer()
                        Picker("Style", selection: Binding(get: { spacer.style }, set: { spacers.setStyle($0, of: spacer.id) })) {
                            ForEach(MenuBarSpacer.Style.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Picker("Width", selection: Binding(get: { spacer.width }, set: { spacers.setWidth($0, of: spacer.id) })) {
                            ForEach(MenuBarSpacer.Width.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button {
                            spacers.remove(spacer.id)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove this space")
                        .accessibilityLabel("Remove space \(index + 1)")
                    }
                }
                Button("Add Space") { spacers.add() }
            } header: {
                Text("Menu bar spaces")
            } footer: {
                Text("A new space appears at the left end of the menu bar icons. Hold ⌘ and drag it to where you want it; "
                    + "macOS keeps the place. Click a space for its style, width or to remove it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
