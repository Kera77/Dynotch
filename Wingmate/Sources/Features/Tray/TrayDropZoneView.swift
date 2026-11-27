import AppKit
import SwiftUI

/// Dragging files over the notch (spec FT-1, FT-3): the tray on the left two thirds, AirDrop on
/// the right third, each a rounded section with its icon in the middle.
struct TrayDropZoneView: View {
    let notchHeight: CGFloat
    let keep: ([URL]) -> Void
    let airDrop: ([URL]) -> Void

    @State private var overKeep = false
    @State private var overAirDrop = false

    private static let airDropIcon = NSWorkspace.shared.icon(
        forFile: "/System/Library/CoreServices/Finder.app/Contents/Applications/AirDrop.app"
    )

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            GeometryReader { geometry in
                let spacing: CGFloat = 12
                let third = (geometry.size.width - spacing) / 3
                HStack(spacing: spacing) {
                    section(title: "Keep in Tray", isOver: overKeep) {
                        Image(systemName: "tray.and.arrow.down.fill").font(.notch(size: 34, weight: .semibold))
                    }
                    .frame(width: third * 2)
                    .dropDestination(for: URL.self) { urls, _ in
                        keep(urls)
                        return true
                    } isTargeted: { overKeep = $0 }
                    section(title: "AirDrop", isOver: overAirDrop) {
                        Image(nsImage: Self.airDropIcon).resizable().scaledToFit().frame(width: 44, height: 44)
                    }
                    .frame(width: third)
                    .dropDestination(for: URL.self) { urls, _ in
                        airDrop(urls)
                        return true
                    } isTargeted: { overAirDrop = $0 }
                }
            }
            .padding(14)
        }
    }

    private func section<Icon: View>(title: String, isOver: Bool, @ViewBuilder icon: () -> Icon) -> some View {
        VStack(spacing: 8) {
            icon()
            Text(title).font(.notch(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white.level(isOver ? 1 : 0.8))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: AppleStyle.corner(18), style: .continuous).fill(Color.white.level(isOver ? 0.2 : 0.08)))
        .overlay(
            RoundedRectangle(cornerRadius: AppleStyle.corner(18), style: .continuous)
                .strokeBorder(Color.white.level(isOver ? 0.7 : 0.22), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .scaleEffect(isOver ? 1.02 : 1)
        .animation(Motion.hover, value: isOver)
    }
}
