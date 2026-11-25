import SwiftUI

/// A tile's card: the module's icon, the content, a hover highlight; a click opens the module (spec HT-6, HT-11).
struct HomeTileCard<Content: View>: View {
    let tile: HomeTile
    let viewportSpace: String
    let open: (HomeTile, UnitPoint) -> Void
    @ViewBuilder let content: Content

    @Environment(\.homeViewport) private var viewport
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: tile.feature.symbolName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .foregroundStyle(.white)
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(isHovered ? Theme.selectedFill : Theme.fill)
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .onHover { hovering in withAnimation(Motion.hover) { isHovered = hovering } }
        .modifier(TileTap(isOn: !HomeTile.withFields.contains(tile), space: viewportSpace) { location in
            let anchor = UnitPoint(x: location.x / max(viewport.width, 1), y: location.y / max(viewport.height, 1))
            open(tile, anchor)
        })
        .accessibilityElement(children: .contain)
        .accessibilityLabel(tile.title)
        .accessibilityAction { open(tile, .center) }
        .help(tile.feature == .home ? tile.title : "Open \(tile.feature.title)")
    }
}

/// The click that opens the module; left off on tiles with a text field, so a click there types (spec HT-28).
private struct TileTap: ViewModifier {
    let isOn: Bool
    let space: String
    let action: (CGPoint) -> Void

    func body(content: Content) -> some View {
        if isOn {
            content.onTapGesture(coordinateSpace: .named(space), perform: action)
        } else {
            content
        }
    }
}

/// A tile's title, its large value and a line under it.
struct TileValueView: View {
    let title: String
    let value: String
    var detail: String?
    var color: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.notch(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.notch(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let detail {
                Text(detail)
                    .font(.notch(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

/// A small round button on a tile (spec HT-7): acts, does not open the module.
struct TileButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Theme.selectedFill))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// A line of a list on a tile: a leading mark, the text, a trailing note.
struct TileRow<Mark: View>: View {
    let text: String
    var note: String?
    @ViewBuilder let mark: Mark

    var body: some View {
        HStack(spacing: 5) {
            mark
            Text(text)
                .font(.notch(size: 11))
                .lineLimit(1)
            Spacer(minLength: 2)
            if let note {
                Text(note)
                    .font(.notch(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// A tile's empty or not-allowed state (spec HT-8).
struct TileEmptyView: View {
    let title: String
    let text: String

    var body: some View {
        TileValueView(title: title, value: "—", detail: text)
    }
}

/// How many list lines fit a tile of this size.
extension TileSize {
    var lines: Int { rows == 1 ? (columns == 1 ? 2 : 3) : rows * 4 - 1 }
}

/// What a tile shows (spec HT-14), by module.
struct HomeTileContent: View {
    let tile: HomeTile
    let services: HomeTileServices
    let size: TileSize

    var body: some View {
        switch tile.feature {
        case .home, .calendar:
            CalendarTileContent(tile: tile, services: services, size: size)
        case .weather:
            WeatherTileContent(tile: tile, size: size)
        case .notifications, .reminders:
            InboxTileContent(tile: tile, services: services, size: size)
        case .notes, .calculator, .clipboard:
            TextTileContent(tile: tile, services: services, size: size)
        case .claudeUsage, .claudeChat, .battery:
            AITileContent(tile: tile, services: services, size: size)
        case .tray, .music:
            MediaTileContent(tile: tile, services: services, size: size)
        case .stats:
            StatsTileContent(tile: tile, stats: services.stats, size: size)
        default:
            ToolTileContent(tile: tile, size: size)
        }
    }
}
