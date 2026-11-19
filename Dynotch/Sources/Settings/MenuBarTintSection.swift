import SwiftUI

/// Settings › Menu bar › Color (spec MB-7, MB-8, MB-11).
struct MenuBarTintSection: View {
    @ObservedObject var tint: MenuBarTintService

    var body: some View {
        Section {
            Picker("Color", selection: $tint.style.kind) {
                ForEach(MenuBarTintStyle.Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            if tint.style.kind != .off {
                preview
                if tint.style.kind == .gradient {
                    Picker("Direction", selection: $tint.style.direction) {
                        ForEach(MenuBarTintStyle.Direction.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    presets
                }
                Toggle("Same in Light and Dark", isOn: $tint.style.sameInBoth)
                colorRow(tint.style.sameInBoth ? "Colors" : "Light", pair: $tint.style.light)
                if !tint.style.sameInBoth { colorRow("Dark", pair: $tint.style.dark) }
                LabeledContent("Opacity") {
                    Slider(value: $tint.style.opacity, in: 0...1)
                        .frame(width: 180)
                    Text("\(Int((tint.style.opacity * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
        } header: {
            Text("Menu bar color")
        } footer: {
            Text("A colored strip behind the menu bar on every display; hidden in full screen and Mission Control. "
                + "macOS picks the menu bar's text color itself, so choose colors it stays readable on.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var preview: some View {
        MenuBarTintView(service: tint)
            .frame(height: 24)
            .overlay(alignment: .leading) {
                HStack(spacing: 14) {
                    Image(systemName: "apple.logo")
                    Text("Finder").bold()
                    Text("File")
                    Text("Edit")
                    Text("View")
                }
                .font(.system(size: 12))
                .padding(.leading, 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityLabel("Preview of the menu bar")
    }

    private var presets: some View {
        LabeledContent("Presets") {
            HStack(spacing: 6) {
                ForEach(MenuBarTintStyle.presets, id: \.name) { preset in
                    Button {
                        tint.style.light = preset.pair
                        if tint.style.sameInBoth { tint.style.dark = preset.pair }
                    } label: {
                        LinearGradient(
                            colors: [TintColor.color(preset.pair.start), TintColor.color(preset.pair.end)],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 34, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .help(preset.name)
                    .accessibilityLabel(preset.name)
                }
            }
        }
    }

    private func colorRow(_ title: String, pair: Binding<MenuBarTintStyle.Pair>) -> some View {
        LabeledContent(title) {
            ColorPicker("Start", selection: hexBinding(pair.start), supportsOpacity: false)
                .labelsHidden()
            if tint.style.kind == .gradient {
                ColorPicker("End", selection: hexBinding(pair.end), supportsOpacity: false)
                    .labelsHidden()
            }
        }
    }

    private func hexBinding(_ hex: Binding<String>) -> Binding<Color> {
        Binding(get: { TintColor.color(hex.wrappedValue) }, set: { hex.wrappedValue = TintColor.hex(of: $0) })
    }
}
