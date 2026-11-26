import AppKit
import SwiftUI

/// A colour well that always opens (spec MB-12): a swatch button with a popover of ready-made
/// colours and "Custom…", which opens the system colour panel in front of Settings.
struct TintSwatchPicker: View {
    let title: String
    @Binding var hex: String
    @State private var isOpen = false

    static let swatches: [String] = [
        "#FFFFFF", "#D9D9D9", "#8E8E93", "#3A3A3C", "#000000", "#FF3B30",
        "#FF6A3D", "#FF9500", "#FFCC00", "#34C759", "#20BF9F", "#2CB1BC",
        "#1B6CA8", "#007AFF", "#5856D6", "#7F5AF0", "#AF52DE", "#C33764",
        "#FF2D55", "#A2845E", "#134E5E", "#71B280", "#3A1C71", "#232526"
    ]

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            RoundedRectangle(cornerRadius: 5)
                .fill(TintColor.color(hex))
                .frame(width: 38, height: 20)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.secondary.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel("\(title) color")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) { palette }
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 6), count: 6), spacing: 6) {
                ForEach(Self.swatches, id: \.self) { swatch in
                    Button {
                        hex = swatch
                        isOpen = false
                    } label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(TintColor.color(swatch))
                            .frame(width: 24, height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(swatch == hex.uppercased() ? Color.accentColor : .secondary.opacity(0.4),
                                                  lineWidth: swatch == hex.uppercased() ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(swatch)
                }
            }
            Button("Custom…") {
                isOpen = false
                ColorPanelBridge.shared.open(hex: hex) { hex = $0 }
            }
        }
        .padding(12)
    }
}

/// Drives the shared NSColorPanel for one colour at a time and brings it in front.
@MainActor
final class ColorPanelBridge: NSObject {
    static let shared = ColorPanelBridge()
    private var onChange: ((String) -> Void)?

    func open(hex: String, onChange: @escaping (String) -> Void) {
        self.onChange = nil
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        if let rgb = TintColor.rgb(hex) {
            panel.color = NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        }
        self.onChange = onChange
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.isContinuous = true
        // Over the notch and the menu bar's tint, which stand above floating windows (spec MB-16).
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 4)
        NSApp.activate()
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        guard let rgb = sender.color.usingColorSpace(.sRGB) else { return }
        onChange?(TintColor.hex(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent))
    }
}
