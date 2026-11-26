import AppKit
import SwiftUI

/// Settings › Modules › Home: the Home's tiles and the catalog by module, the full settings width
/// (spec HT-20…HT-23, HT-30…HT-34).
struct HomeTilesEditor: View {
    @Bindable var tiles: HomeTileSettings
    /// The modules' order, for the catalog (spec HT-21).
    let order: [FeatureID]

    private static let columns = 4
    private static let cellHeight: CGFloat = 40
    private static let gap: CGFloat = 6
    private static let inset: CGFloat = 8
    /// Room left above the block when it stops at the top (spec HT-33).
    private static let topMargin: CGFloat = 16

    /// The catalog groups folded by hand; all open by default (spec HT-34).
    @AppStorage("home.collapsedGroups") private var collapsedRaw = ""
    /// The settings' visible height and the height above the catalog (spec HT-33).
    @State private var viewportHeight: CGFloat = 400
    @State private var headHeight: CGFloat = 0
    @State private var previewWidth: CGFloat = 0
    /// A tile dragged from the small Home, and whether the pointer is still over it (spec HT-31).
    @State private var dragged: HomeTile?
    @State private var isOverPreview = false

    private var isRemoving: Bool { dragged != nil && !isOverPreview }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("On the Home: drag to reorder; drag out or click × to remove.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    preview
                    Text("Tiles: drag onto the Home, click + or double-click to add.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headHeight = $0 }
                catalog
                    .frame(height: max(viewportHeight - headHeight - 8 - Self.topMargin, 160))
            }
            // Dropped anywhere outside the small Home: off the Home (spec HT-31).
            .dropDestination(for: String.self) { items, _ in removeDragged(items) }
            if tiles.contains(.worldClock) || tiles.contains(.run) { options }
            HStack {
                Spacer()
                Button("Reset to default") { withAnimation(Motion.quick) { tiles.reset() } }
            }
        }
        .task(id: dragged) { await watchDragEnd() }
    }

    // MARK: - The Home, small (spec HT-20, HT-22, HT-31)

    private var cellWidth: CGFloat {
        let room = previewWidth - Self.inset * 2 - Self.gap * CGFloat(Self.columns - 1)
        return max(room / CGFloat(Self.columns), 30)
    }

    private var preview: some View {
        let placements = HomeLayout.place(tiles.tiles, columns: Self.columns)
        let stepX = cellWidth + Self.gap
        let stepY = Self.cellHeight + Self.gap
        let rows = max(HomeLayout.rows(of: placements), 1)
        return ZStack(alignment: .topLeading) {
            ForEach(placements, id: \.tile) { placement in
                let tile = placement.tile
                PreviewTile(
                    tile: tile, isRemoving: isRemoving && dragged == tile,
                    remove: { withAnimation(Motion.quick) { tiles.remove(tile) } }
                )
                .frame(
                    width: stepX * CGFloat(placement.size.columns) - Self.gap,
                    height: stepY * CGFloat(placement.size.rows) - Self.gap
                )
                .offset(x: stepX * CGFloat(placement.column), y: stepY * CGFloat(placement.row))
                .onDrag {
                    dragged = tile
                    return NSItemProvider(object: tile.rawValue as NSString)
                }
            }
        }
        .padding(Self.inset)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: stepY * CGFloat(rows) - Self.gap + Self.inset * 2, alignment: .topLeading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { previewWidth = $0 }
        .background(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).fill(Color.secondary.opacity(0.12)))
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, location in
            drop(items, at: location, in: placements)
        } isTargeted: { isOverPreview = $0 }
        .animation(Motion.quick, value: placements)
    }

    /// Before the tile under the drop point, or at the end (spec HT-22).
    private func drop(_ items: [String], at location: CGPoint, in placements: [TilePlacement]) -> Bool {
        dragged = nil
        guard let tile = items.first.flatMap(HomeTile.init(rawValue:)) else { return false }
        let column = Int((location.x - Self.inset) / (cellWidth + Self.gap))
        let row = Int((location.y - Self.inset) / (Self.cellHeight + Self.gap))
        let target = placements.first { placement in
            (placement.column..<(placement.column + placement.size.columns)).contains(column)
                && (placement.row..<(placement.row + placement.size.rows)).contains(row)
        }
        withAnimation(Motion.quick) { tiles.place(tile, at: target.flatMap { tiles.tiles.firstIndex(of: $0.tile) }) }
        return true
    }

    private func removeDragged(_ items: [String]) -> Bool {
        defer { dragged = nil }
        guard let tile = items.first.flatMap(HomeTile.init(rawValue:)), tile == dragged else { return false }
        withAnimation(Motion.quick) { tiles.remove(tile) }
        return true
    }

    /// A drag can end outside every drop target (another window, the desktop): when the button is
    /// up and the pointer was not over the small Home, the tile comes off (spec HT-31).
    private func watchDragEnd() async {
        while let tile = dragged {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, dragged == tile else { return }
            guard NSEvent.pressedMouseButtons & 1 == 0 else { continue }
            // Let a drop that is still being delivered come first.
            try? await Task.sleep(for: .milliseconds(150))
            guard dragged == tile else { return }
            if !isOverPreview { withAnimation(Motion.quick) { tiles.remove(tile) } }
            dragged = nil
            isOverPreview = false
        }
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

    // MARK: - The catalog (spec HT-21, HT-32…HT-34)

    private var collapsed: Set<String> {
        Set(collapsedRaw.split(separator: ",").map(String.init))
    }

    private func toggle(_ feature: FeatureID) {
        var groups = collapsed
        if groups.remove(feature.rawValue) == nil { groups.insert(feature.rawValue) }
        withAnimation(Motion.quick) { collapsedRaw = groups.sorted().joined(separator: ",") }
    }

    private var catalog: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(HomeTileGroup.catalog(order: order)) { group in
                    catalogGroup(group, isOpen: !collapsed.contains(group.feature.rawValue))
                }
            }
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ScrollChain { viewportHeight = $0 })
        }
        .overlay {
            if isRemoving { RemoveBanner() }
        }
    }

    private func catalogGroup(_ group: HomeTileGroup, isOpen: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { toggle(group.feature) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .frame(width: 12)
                    Label(group.feature.title, systemImage: group.feature.symbolName)
                        .font(.callout.weight(.medium))
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isOpen ? "Fold \(group.feature.title)'s tiles" : "Show \(group.feature.title)'s tiles")
            if isOpen {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(group.tiles) { tile in
                        CatalogChip(tile: tile, isAdded: tiles.contains(tile)) {
                            withAnimation(Motion.quick) { tiles.place(tile) }
                        }
                        .draggable(tile.rawValue)
                        .onTapGesture(count: 2) { withAnimation(Motion.quick) { tiles.place(tile) } }
                    }
                }
            }
        }
    }
}
