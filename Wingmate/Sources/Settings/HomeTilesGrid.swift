import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The small Home in Settings › Modules › Home: five columns, centred, a tile where it is dropped,
/// one empty row below, and a faint grid with the target while a tile is over it (spec HT-38).
struct HomeTilesGrid: View {
    @Bindable var tiles: HomeTileSettings
    /// The tile being dragged, from the catalog or from here (spec HT-37).
    @Binding var dragged: HomeTile?
    @Binding var isOverGrid: Bool
    /// A drag starts from a tile here.
    let lift: (HomeTile) -> Void

    static let cell: CGFloat = 62
    static let gap: CGFloat = 6
    static let inset: CGFloat = 8

    @State private var target: GridCell?

    private static var step: CGFloat { cell + gap }

    var body: some View {
        let placements = HomeLayout.placements(tiles.slots)
        // Always one free row below the tiles to drop into.
        let rows = HomeLayout.rows(of: placements) + 1
        let width = Self.step * CGFloat(HomeLayout.columns) - Self.gap
        return ZStack(alignment: .topLeading) {
            if isOverGrid { cells(rows: rows) }
            ForEach(placements, id: \.tile) { placement in
                let tile = placement.tile
                PreviewTile(tile: tile, isLifted: dragged == tile && !isOverGrid) {
                    withAnimation(Motion.quick) { tiles.remove(tile) }
                }
                .frame(width: span(placement.size.columns), height: span(placement.size.rows))
                .offset(x: Self.step * CGFloat(placement.column), y: Self.step * CGFloat(placement.row))
                .onDrag {
                    lift(tile)
                    return NSItemProvider(object: tile.rawValue as NSString)
                }
            }
            if let target, let tile = dragged {
                let footprint = HomeLayout.footprint(of: tile, at: target)
                let shape = RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                shape.strokeBorder(Color.accentColor, lineWidth: 2)
                    .background(shape.fill(Color.accentColor.opacity(0.18)))
                    .frame(width: span(footprint.size.columns), height: span(footprint.size.rows))
                    .offset(x: Self.step * CGFloat(footprint.column), y: Self.step * CGFloat(footprint.row))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: Self.step * CGFloat(rows) - Self.gap, alignment: .topLeading)
        .padding(Self.inset)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).fill(Color.secondary.opacity(0.12)))
        .contentShape(Rectangle())
        .onDrop(of: [.utf8PlainText, .plainText], delegate: GridDrop(
            cellAt: Self.cell(at:), target: $target, isOver: $isOverGrid, dragged: $dragged
        ) { tile, cell in
            withAnimation(Motion.quick) { tiles.put(tile, row: cell.row, column: cell.column) }
        })
        .frame(maxWidth: .infinity)
        .animation(Motion.quick, value: placements)
        .animation(Motion.quick, value: isOverGrid)
    }

    private func span(_ count: Int) -> CGFloat {
        Self.step * CGFloat(count) - Self.gap
    }

    /// The faint grid shown while a tile is over the small Home.
    private func cells(rows: Int) -> some View {
        ForEach(0..<(rows * HomeLayout.columns), id: \.self) { index in
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: Self.cell, height: Self.cell)
                .offset(x: Self.step * CGFloat(index % HomeLayout.columns), y: Self.step * CGFloat(index / HomeLayout.columns))
                .allowsHitTesting(false)
        }
    }

    /// The cell under a point of the drop area (its padding included).
    private static func cell(at point: CGPoint) -> GridCell {
        let column = Int(((point.x - inset) / step).rounded(.down))
        let row = Int(((point.y - inset) / step).rounded(.down))
        return GridCell(row: max(row, 0), column: min(max(column, 0), HomeLayout.columns - 1))
    }
}

/// Drops onto the small Home: follows the pointer for the target cell, puts the tile there (spec HT-38).
private struct GridDrop: DropDelegate {
    let cellAt: (CGPoint) -> GridCell
    @Binding var target: GridCell?
    @Binding var isOver: Bool
    @Binding var dragged: HomeTile?
    let put: @MainActor (HomeTile, GridCell) -> Void

    func dropEntered(info: DropInfo) {
        isOver = true
        target = cellAt(info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let cell = cellAt(info.location)
        if cell != target { target = cell }
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        isOver = false
        target = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        let cell = cellAt(info.location)
        defer {
            target = nil
            isOver = false
            dragged = nil
        }
        if let tile = dragged {
            put(tile, cell)
            return true
        }
        // A tile from somewhere the editor did not see start the drag.
        guard let provider = info.itemProviders(for: [.utf8PlainText, .plainText]).first else { return false }
        let put = put
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let raw = object as? NSString else { return }
            let id = String(raw)
            Task { @MainActor in
                if let tile = HomeTile(rawValue: id) { put(tile, cell) }
            }
        }
        return true
    }
}

/// Anywhere in the editor but the small Home: a tile from the Home dropped here comes off; no
/// green plus on the pointer (spec HT-31, HT-37).
struct RemoveDrop: DropDelegate {
    let remove: @MainActor () -> Bool

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        remove()
    }
}

/// A small red minus beside the pointer while a tile from the Home is outside it, wherever the
/// pointer is (spec HT-37), as the system shows a green plus when a drop would add.
@MainActor
final class RemoveBadge {
    static let shared = RemoveBadge()

    private var window: NSPanel?
    private var timer: Timer?

    func show(_ shown: Bool) {
        if shown { start() } else { stop() }
    }

    private func start() {
        guard timer == nil else { return }
        let panel = window ?? makeWindow()
        window = panel
        follow()
        panel.orderFrontRegardless()
        timer = RepeatingTimer.start(every: 1.0 / 60, tolerance: 0) { [weak self] in self?.follow() }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        window?.orderOut(nil)
    }

    /// Below and right of the arrow's tip, where the system puts its own drag badges.
    private func follow() {
        let mouse = NSEvent.mouseLocation
        window?.setFrameOrigin(NSPoint(x: mouse.x + 8, y: mouse.y - 30))
    }

    private func makeWindow() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 18, height: 18), styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.draggingWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let badge = Image(systemName: "minus.circle.fill")
            .font(.system(size: 15, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .red)
            .frame(width: 18, height: 18)
        panel.contentView = NSHostingView(rootView: badge)
        return panel
    }
}
