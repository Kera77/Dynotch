import SwiftUI

/// The badge icon of an app in the settings: a framed button with the icon and a small arrow,
/// opening a panel with the app's icon, the presets and an own image (spec SD-11).
struct BadgeIconPicker: View {
    let icon: BadgeIcon
    let bundleID: String
    let choose: (BadgeIcon) -> Void
    let chooseImage: () -> Void

    @State private var isOpen = false

    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 6), count: 5)

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 3) {
                BadgeIconView(icon: icon, bundleID: bundleID, size: 16, tint: .primary, monochrome: false)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 5)
            .frame(height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Icon shown next to the notch")
        .accessibilityLabel("Icon shown next to the notch")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) { panel }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                pick(.app)
            } label: {
                HStack(spacing: 6) {
                    BadgeIconView(icon: .app, bundleID: bundleID, size: 18, tint: .primary, monochrome: false)
                    Text("App icon")
                    Spacer()
                    if icon == .app { Image(systemName: "checkmark").foregroundStyle(.secondary) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(BadgePreset.all) { preset in
                    cell(preset)
                }
            }
            Divider()
            Button("Choose image…") {
                isOpen = false
                chooseImage()
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(width: 192)
    }

    private func cell(_ preset: BadgePreset) -> some View {
        let value = BadgeIcon.symbol(preset.symbol)
        return Button {
            pick(value)
        } label: {
            BadgeIconView(icon: value, bundleID: bundleID, size: 16, tint: .primary, monochrome: false)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(icon == value ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.06))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(preset.title)
        .accessibilityLabel(preset.title)
    }

    private func pick(_ value: BadgeIcon) {
        choose(value)
        isOpen = false
    }
}
