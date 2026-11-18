import AppKit
import SwiftUI

/// Sizes of the switcher's three views (spec AS-5), so the notch opens exactly as far as needed.
enum SwitcherLayout {
    static let spacing: CGFloat = 10
    static let padding: CGFloat = 16

    nonisolated static func tile(_ style: SwitcherStyle, scale: CGFloat) -> CGSize {
        switch style {
        case .icons: CGSize(width: 76 * scale, height: 76 * scale + 22)
        case .thumbnails: CGSize(width: 190 * scale, height: 120 * scale + 30)
        case .titles: CGSize(width: 420 * scale, height: 30 * scale)
        }
    }

    /// Tiles in a row, at most what fits in `maxWidth`.
    nonisolated static func columns(count: Int, style: SwitcherStyle, scale: CGFloat, maxWidth: CGFloat) -> Int {
        guard style != .titles else { return 1 }
        let tile = tile(style, scale: scale).width
        let fitting = max(Int((maxWidth - 2 * padding + spacing) / (tile + spacing)), 1)
        return max(min(count, fitting), 1)
    }

    /// The panel's size under the notch; rows beyond the screen scroll.
    /// - Parameter room: the largest size the panel may take (the screen, less a margin).
    nonisolated static func size(count: Int, style: SwitcherStyle, scale: CGFloat, notchHeight: CGFloat, room: CGSize) -> CGSize {
        let maxWidth = room.width
        let maxHeight = room.height
        let tile = tile(style, scale: scale)
        let columns = columns(count: count, style: style, scale: scale, maxWidth: maxWidth)
        let rows = Int(ceil(Double(max(count, 1)) / Double(columns)))
        let width = CGFloat(columns) * tile.width + CGFloat(columns - 1) * spacing + 2 * padding
        let height = notchHeight + padding + CGFloat(rows) * tile.height + CGFloat(rows - 1) * spacing + padding
        return CGSize(width: max(width, 320), height: min(height, maxHeight))
    }
}

/// The windows in the notch (spec AS-5, AS-6): thumbnails, app icons or titles; the chosen one
/// highlighted; hovering chooses, a click switches.
struct SwitcherView: View {
    @ObservedObject var switcher: SwitcherController
    @ObservedObject var settings: SwitcherSettings
    let notchHeight: CGFloat
    let width: CGFloat

    private var scale: CGFloat { settings.size.scale }

    var body: some View {
        let columns = SwitcherLayout.columns(
            count: switcher.items.count, style: settings.style, scale: scale, maxWidth: width
        )
        let tile = SwitcherLayout.tile(settings.style, scale: scale)
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(tile.width), spacing: SwitcherLayout.spacing), count: columns),
                        spacing: SwitcherLayout.spacing
                    ) {
                        ForEach(Array(switcher.items.enumerated()), id: \.element.id) { index, item in
                            entry(item, isSelected: index == switcher.selection)
                                .frame(width: tile.width, height: tile.height)
                                .id(item.id)
                                .contentShape(Rectangle())
                                .onHover { if $0 { switcher.choose(index) } }
                                .onTapGesture { switcher.pick(index) }
                        }
                    }
                    .padding(SwitcherLayout.padding)
                }
                .scrollIndicators(.never)
                .onChange(of: switcher.selection) { _, _ in
                    if let item = switcher.selected { proxy.scrollTo(item.id) }
                }
            }
        }
    }

    @ViewBuilder private func entry(_ item: SwitcherItem, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
        Group {
            switch settings.style {
            case .icons: iconEntry(item, isSelected: isSelected)
            case .thumbnails: thumbnailEntry(item)
            case .titles: titleEntry(item)
            }
        }
        .background(shape.fill(Color.white.opacity(isSelected ? 0.18 : 0)))
        .overlay(shape.strokeBorder(isSelected ? Theme.blue : .clear, lineWidth: 2))
    }

    private func appIcon(_ item: SwitcherItem) -> NSImage {
        NSRunningApplication(processIdentifier: item.pid)?.icon ?? NSWorkspace.shared.icon(for: .application)
    }

    private func iconEntry(_ item: SwitcherItem, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            Image(nsImage: appIcon(item)).resizable().scaledToFit()
                .frame(width: 60 * scale, height: 60 * scale)
                .opacity(item.isMinimized ? 0.55 : 1)
            Text(isSelected ? item.label : item.appName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(6)
    }

    private func thumbnailEntry(_ item: SwitcherItem) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.06))
                if let preview = switcher.previews[item.windowID] {
                    Image(nsImage: preview).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    // Without previews (off, or no permission): the app's icon (spec AS-7).
                    Image(nsImage: appIcon(item)).resizable().scaledToFit().frame(width: 52 * scale, height: 52 * scale)
                }
            }
            .frame(maxHeight: .infinity)
            HStack(spacing: 5) {
                Image(nsImage: appIcon(item)).resizable().scaledToFit().frame(width: 14, height: 14)
                Text(item.label).font(.system(size: 11, weight: .medium)).foregroundStyle(.white).lineLimit(1)
            }
        }
        .padding(6)
    }

    private func titleEntry(_ item: SwitcherItem) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: appIcon(item)).resizable().scaledToFit().frame(width: 18 * scale, height: 18 * scale)
            Text(item.label)
                .font(.system(size: 12 * scale, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 6)
            if item.label != item.appName {
                Text(item.appName).font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.45)).lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
    }
}
