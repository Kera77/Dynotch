import SwiftUI

/// Settings › Modules › Home: the Home's tiles, the catalog by module and the way back (spec HT-20…HT-23).
struct HomeTilesEditor: View {
    @Bindable var tiles: HomeTileSettings
    /// The modules' order, for the catalog (spec HT-21).
    let order: [FeatureID]

    private static let columns = 4
    private static let cell: CGFloat = 54
    private static let gap: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Back to Home", selection: $tiles.backGesture) {
                ForEach(HomeTileSettings.BackGesture.allCases) { gesture in
                    Text(gesture.title).tag(gesture)
                }
            }
            .help("How a module opened from a tile goes back: pinch, or swipe down over its top row, with two fingers")
            Text("On the Home: drag to reorder, drag back to the list or click × to remove.")
                .font(.caption)
                .foregroundStyle(.secondary)
            preview
            Text("Tiles: drag onto the Home or double-click to add.")
                .font(.caption)
                .foregroundStyle(.secondary)
            catalog
            if tiles.contains(.worldClock) || tiles.contains(.run) { options }
            HStack {
                Spacer()
                Button("Reset to default") { withAnimation(Motion.quick) { tiles.reset() } }
            }
        }
    }

    // MARK: - The Home, small (spec HT-20, HT-22)

    private var preview: some View {
        let placements = HomeLayout.place(tiles.tiles, columns: Self.columns)
        let step = Self.cell + Self.gap
        let rows = max(HomeLayout.rows(of: placements), 1)
        return ZStack(alignment: .topLeading) {
            ForEach(placements, id: \.tile) { placement in
                PreviewTile(tile: placement.tile, remove: { withAnimation(Motion.quick) { tiles.remove(placement.tile) } })
                    .frame(
                        width: step * CGFloat(placement.size.columns) - Self.gap,
                        height: step * CGFloat(placement.size.rows) - Self.gap
                    )
                    .offset(x: step * CGFloat(placement.column), y: step * CGFloat(placement.row))
                    .draggable(placement.tile.rawValue)
                    .dropDestination(for: String.self) { items, _ in
                        drop(items, before: tiles.tiles.firstIndex(of: placement.tile))
                    }
            }
        }
        .frame(width: step * CGFloat(Self.columns) - Self.gap, height: step * CGFloat(rows) - Self.gap, alignment: .topLeading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).fill(Color.secondary.opacity(0.12)))
        .dropDestination(for: String.self) { items, _ in drop(items, before: nil) }
        .animation(Motion.quick, value: placements)
    }

    private func drop(_ items: [String], before index: Int?) -> Bool {
        guard let tile = items.first.flatMap(HomeTile.init(rawValue:)) else { return false }
        withAnimation(Motion.quick) { tiles.place(tile, at: index) }
        return true
    }

    // MARK: - Tiles' own settings (spec HT-29)

    private static let zones = TimeZone.knownTimeZoneIdentifiers.sorted()

    @ViewBuilder private var options: some View {
        if tiles.contains(.worldClock) {
            Picker("World clock", selection: $tiles.worldClockZone) {
                ForEach(Self.zones, id: \.self) { zone in
                    Text(zone.replacingOccurrences(of: "_", with: " ")).tag(zone)
                }
            }
            .help("The time zone the World clock tile shows")
        }
        if tiles.contains(.run) {
            TextField("Run tile's name", text: $tiles.runName, prompt: Text("e.g. Deploy"))
            TextField("Run tile's command", text: $tiles.runCommand, prompt: Text("e.g. git pull"))
                .font(.system(.callout, design: .monospaced))
                .help("Typed into the Terminal and run when you click ▶ on the Run tile")
        }
    }

    // MARK: - The catalog (spec HT-21)

    private var catalog: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(HomeTileGroup.catalog(order: order)) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Label(group.feature.title, systemImage: group.feature.symbolName)
                        .font(.callout.weight(.medium))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(group.tiles) { tile in
                            CatalogChip(tile: tile, isAdded: tiles.contains(tile))
                                .draggable(tile.rawValue)
                                .onTapGesture(count: 2) { withAnimation(Motion.quick) { tiles.place(tile) } }
                        }
                    }
                }
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let tile = items.first.flatMap(HomeTile.init(rawValue:)), tiles.contains(tile) else { return false }
            withAnimation(Motion.quick) { tiles.remove(tile) }
            return true
        }
    }
}

/// A tile in the small Home: icon, name, size; × on hover.
private struct PreviewTile: View {
    let tile: HomeTile
    let remove: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: tile.feature.symbolName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(tile.title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).fill(Color.secondary.opacity(0.22)))
        .overlay(alignment: .topTrailing) {
            if isHovered {
                Button(action: remove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(3)
                .help("Remove \(tile.title) from the Home")
                .accessibilityLabel("Remove \(tile.title)")
            }
        }
        .onHover { isHovered = $0 }
    }
}

/// A tile in the catalog: name and size, ticked and dimmed when on the Home.
private struct CatalogChip: View {
    let tile: HomeTile
    let isAdded: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(tile.title)
                .lineLimit(1)
            Text(tile.size.label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if isAdded {
                Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous).fill(Color.secondary.opacity(0.14)))
        .opacity(isAdded ? 0.55 : 1)
        .help(isAdded ? "\(tile.title) is on the Home" : "Drag onto the Home or double-click to add")
    }
}
