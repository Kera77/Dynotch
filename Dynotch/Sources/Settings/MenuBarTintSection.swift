import SwiftUI

/// Settings › Menu bar › Color (spec MB-7, MB-8, MB-11, MB-12, MB-15).
struct MenuBarTintSection: View {
    @Bindable var tint: MenuBarTintService

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
                SettingsSlider(title: "Opacity", value: $tint.style.opacity, range: MenuBarTintStyle.opacityRange) {
                    "\(Int(($0 * 100).rounded())) %"
                }
            }
        } header: {
            Text("Menu bar color")
        } footer: {
            Text("Tints the whole menu bar on every display, see-through so its titles and icons stay visible and "
                + "clickable; the notch stays black. Hidden in full screen and Mission Control.")
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
                        var pair = preset.pair
                        pair.middle = tint.style.light.middle
                        tint.style.light = pair
                        if tint.style.sameInBoth { tint.style.dark = pair }
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
            HStack(spacing: 8) {
                TintSwatchPicker(title: tint.style.kind == .gradient ? "Start" : "Color", hex: pair.start)
                if tint.style.kind == .gradient {
                    if tint.style.direction == .center {
                        TintSwatchPicker(title: "Middle", hex: Binding(
                            get: { pair.wrappedValue.middle ?? MenuBarTintStyle.defaultMiddle },
                            set: { pair.wrappedValue.middle = $0 }
                        ))
                    }
                    TintSwatchPicker(title: "End", hex: pair.end)
                }
            }
        }
    }
}
