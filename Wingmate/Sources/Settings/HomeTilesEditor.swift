import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings › Modules › Home: the way back, the Home's tiles and the catalog by module, the full
/// settings width (spec HT-20…HT-23, HT-30…HT-34, HT-37, HT-38, HT-40).
struct HomeTilesEditor: View {
    @Bindable var tiles: HomeTileSettings
    /// The modules' order, for the catalog (spec HT-21).
    let order: [FeatureID]

    /// Room left above the block when it stops at the top (spec HT-33).
    private static let topMargin: CGFloat = 16

    /// The catalog groups folded by hand; all open by default (spec HT-34).
    @AppStorage("home.collapsedGroups") private var collapsedRaw = ""
    /// The settings' visible height and the height above the catalog (spec HT-33).
    @State private var viewportHeight: CGFloat = 400
    @State private var headHeight: CGFloat = 0
    /// The tile being dragged, whether it came from the small Home, and whether the pointer is
    /// over it (spec HT-31, HT-37, HT-38).
    @State private var dragged: HomeTile?
    @State private var isFromHome = false
    @State private var isOverGrid = false

    /// A tile from the Home is outside it: dropping removes it, a red minus at the pointer says so.
    private var isRemoving: Bool { dragged != nil && isFromHome && !isOverGrid }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Back to Home", selection: $tiles.backGesture) {
                        ForEach(HomeTileSettings.BackGesture.allCases) { Text($0.title).tag($0) }
                    }
                    .help("How a module opened from a tile goes back to the Home; ‹ Home always does")
                    Text("On the Home: drop a tile where you want it; drag out or click × to remove.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HomeTilesGrid(tiles: tiles, dragged: $dragged, isOverGrid: $isOverGrid) { tile in
                        dragged = tile
                        isFromHome = true
                    }
                    Text("Tiles: drag onto the Home, click + or double-click to add.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headHeight = $0 }
                catalog
                    .frame(height: max(viewportHeight - headHeight - 8 - Self.topMargin, 160))
            }
            // Dropped anywhere outside the small Home: off the Home (spec HT-31).
            .onDrop(of: [.utf8PlainText, .plainText], delegate: RemoveDrop(remove: removeDragged))
            if tiles.contains(.worldClock) || tiles.contains(.run) { options }
            HStack {
                Spacer()
                Button("Reset to default") { withAnimation(Motion.quick) { tiles.reset() } }
            }
        }
        .task(id: dragged) { await watchDragEnd() }
        .onChange(of: isRemoving) { _, removing in RemoveBadge.shared.show(removing) }
        .onDisappear { RemoveBadge.shared.show(false) }
    }

    private func lift(_ tile: HomeTile) {
        dragged = tile
        isFromHome = false
    }

    private func removeDragged() -> Bool {
        defer { dragged = nil }
        guard let tile = dragged, isFromHome else { return false }
        withAnimation(Motion.quick) { tiles.remove(tile) }
        return true
    }

    /// A drag can end outside every drop target (another window, the desktop): when the button is
    /// up and the pointer was not over the small Home, a tile from it comes off (spec HT-31).
    private func watchDragEnd() async {
        while let tile = dragged {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, dragged == tile else { return }
            guard NSEvent.pressedMouseButtons & 1 == 0 else { continue }
            // Let a drop that is still being delivered come first.
            try? await Task.sleep(for: .milliseconds(150))
            guard dragged == tile else { return }
            if isFromHome, !isOverGrid { withAnimation(Motion.quick) { tiles.remove(tile) } }
            dragged = nil
            isOverGrid = false
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
                            withAnimation(Motion.quick) { tiles.add(tile) }
                        }
                        .onDrag {
                            lift(tile)
                            return NSItemProvider(object: tile.rawValue as NSString)
                        }
                        .onTapGesture(count: 2) { withAnimation(Motion.quick) { tiles.add(tile) } }
                    }
                }
            }
        }
    }
}
