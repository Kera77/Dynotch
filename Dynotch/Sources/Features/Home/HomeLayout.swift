import CoreGraphics

/// A tile at the place it was dropped in the Home's grid (spec HT-38).
struct HomeSlot: Hashable, Sendable {
    let tile: HomeTile
    var row: Int
    var column: Int

    /// Saved as `module.tile@row,column` (spec HT-38).
    var saved: String { "\(tile.rawValue)@\(row),\(column)" }

    init(tile: HomeTile, row: Int, column: Int) {
        self.tile = tile
        self.row = row
        self.column = column
    }

    init?(saved: String) {
        let parts = saved.split(separator: "@")
        guard parts.count == 2, let tile = HomeTile(rawValue: String(parts[0])) else { return nil }
        let place = parts[1].split(separator: ",").compactMap { Int($0) }
        guard place.count == 2, place[0] >= 0, place[1] >= 0 else { return nil }
        self.init(tile: tile, row: place[0], column: min(place[1], HomeLayout.columns - 1))
    }
}

/// How the notch moves the saved grid (spec HT-39): rows left out above, columns shifted, its width.
struct ShownOrigin: Equatable, Sendable {
    let top: Int
    let shift: Int
    let columns: Int
}

/// A cell of the Home's grid.
struct GridCell: Hashable, Sendable {
    var row: Int
    var column: Int
}

/// Where a tile sits in the Home's grid, in rows and columns.
struct TilePlacement: Equatable, Sendable {
    let tile: HomeTile
    let row: Int
    let column: Int
    let size: TileSize
}

/// The Home's grid: five columns, each tile where it was put (spec HT-38, HT-39).
enum HomeLayout {
    /// The columns of the normal panel; the editor offers this many (spec HT-38).
    static let columns = 5
    /// The Home is never narrower than this many columns (spec HT-39).
    static let minimumColumns = 3
    static let gap: CGFloat = 8
    /// The page's own side padding in the open panel.
    static let sidePadding: CGFloat = 20

    /// A column's width (and a row's height: tiles are square) in `width` with `columns` columns.
    static func cell(width: CGFloat, columns: Int) -> CGFloat {
        max((width - gap * CGFloat(columns - 1)) / CGFloat(max(columns, 1)), 0)
    }

    /// The size of a tile on the normal-width panel: five columns fill it (spec HT-39).
    static func baseCell(panelWidth: CGFloat) -> CGFloat {
        cell(width: panelWidth - 2 * sidePadding, columns: columns)
    }

    /// The Home panel's width for the tiles' columns (spec HT-39).
    static func panelWidth(columns: Int, normalWidth: CGFloat) -> CGFloat {
        let cell = baseCell(panelWidth: normalWidth)
        return CGFloat(columns) * cell + CGFloat(columns - 1) * gap + 2 * sidePadding
    }

    /// The tile's size within the grid: never wider than five columns, never past its right edge.
    static func placement(of slot: HomeSlot) -> TilePlacement {
        let width = min(slot.tile.size.columns, columns)
        let column = min(max(slot.column, 0), columns - width)
        let size = TileSize(rows: slot.tile.size.rows, columns: width)
        return TilePlacement(tile: slot.tile, row: max(slot.row, 0), column: column, size: size)
    }

    static func placements(_ slots: [HomeSlot]) -> [TilePlacement] {
        slots.map(placement(of:))
    }

    /// How many rows the placed tiles fill.
    static func rows(of placements: [TilePlacement]) -> Int {
        placements.map { $0.row + $0.size.rows }.max() ?? 0
    }

    /// What the notch shows: empty rows above and columns left of every tile are left out, the
    /// widest row sets the width, at least three columns, a narrower set centred (spec HT-39).
    static func shown(_ slots: [HomeSlot]) -> (placements: [TilePlacement], columns: Int) {
        let placed = placements(slots)
        guard let origin = shownOrigin(placed) else { return ([], minimumColumns) }
        let moved = placed.map {
            TilePlacement(tile: $0.tile, row: $0.row - origin.top, column: $0.column + origin.shift, size: $0.size)
        }
        return (moved, origin.columns)
    }

    /// How the notch moves the grid: rows left out above, columns shifted, and its width (spec HT-39).
    static func shownOrigin(_ placed: [TilePlacement]) -> ShownOrigin? {
        guard let top = placed.map(\.row).min(), let left = placed.map(\.column).min(),
              let right = placed.map({ $0.column + $0.size.columns }).max()
        else { return nil }
        let used = right - left
        let width = max(used, minimumColumns)
        return ShownOrigin(top: top, shift: (width - used) / 2 - left, columns: width)
    }

    /// Where a tile dragged in the notch lands in the five columns: its shown cell back to the
    /// saved grid, kept inside it (spec HT-44).
    static func dropCell(of tile: HomeTile, shownRow: Int, shownColumn: Int, in slots: [HomeSlot]) -> GridCell {
        let origin = shownOrigin(placements(slots)) ?? ShownOrigin(top: 0, shift: 0, columns: columns)
        let width = min(tile.size.columns, columns)
        let column = min(max(shownColumn - origin.shift, 0), columns - width)
        return GridCell(row: max(shownRow + origin.top, 0), column: column)
    }

    /// The tiles in reading order: by row, then column.
    static func ordered(_ slots: [HomeSlot]) -> [HomeSlot] {
        slots.sorted { $0.row != $1.row ? $0.row < $1.row : $0.column < $1.column }
    }

    /// The cells a tile would cover at `cell`, kept inside the five columns (the editor's target, spec HT-38).
    static func footprint(of tile: HomeTile, at cell: GridCell) -> TilePlacement {
        placement(of: HomeSlot(tile: tile, row: cell.row, column: cell.column))
    }

    /// The first place, from `start` on in reading order, where `size` fits whole.
    static func firstFree(_ size: TileSize, in slots: [HomeSlot], from start: GridCell = GridCell(row: 0, column: 0)) -> GridCell {
        let taken = cells(of: placements(slots))
        let width = min(size.columns, columns)
        var row = start.row
        var column = min(start.column, columns - width)
        while true {
            if taken.isDisjoint(with: cells(row: row, column: column, size: size, width: width)) {
                return GridCell(row: row, column: column)
            }
            column += 1
            if column > columns - width {
                column = 0
                row += 1
            }
        }
    }

    /// Puts `tile` at a place; the tiles it covers move on to the next free place after where
    /// they were (spec HT-38).
    static func put(_ tile: HomeTile, row: Int, column: Int, in slots: [HomeSlot]) -> [HomeSlot] {
        let moved = placement(of: HomeSlot(tile: tile, row: row, column: column))
        let covered = Set(cells(row: moved.row, column: moved.column, size: moved.size, width: moved.size.columns))
        var kept = slots.filter { $0.tile != tile }
        let pushed = ordered(kept.filter { !cells(of: [placement(of: $0)]).isDisjoint(with: covered) })
        kept.removeAll { pushed.contains($0) }
        kept.append(HomeSlot(tile: tile, row: moved.row, column: moved.column))
        for slot in pushed {
            let spot = firstFree(slot.tile.size, in: kept, from: GridCell(row: slot.row, column: slot.column))
            kept.append(HomeSlot(tile: slot.tile, row: spot.row, column: spot.column))
        }
        return kept
    }

    /// An ordered list of tiles (saved before v1.7.2) laid out in five columns (spec HT-38).
    static func slots(from tiles: [HomeTile]) -> [HomeSlot] {
        var slots: [HomeSlot] = []
        for tile in tiles where !slots.contains(where: { $0.tile == tile }) {
            let spot = firstFree(tile.size, in: slots)
            slots.append(HomeSlot(tile: tile, row: spot.row, column: spot.column))
        }
        return slots
    }

    private static func cells(of placements: [TilePlacement]) -> Set<Int> {
        Set(placements.flatMap { cells(row: $0.row, column: $0.column, size: $0.size, width: $0.size.columns) })
    }

    private static func cells(row: Int, column: Int, size: TileSize, width: Int) -> [Int] {
        (row..<(row + size.rows)).flatMap { line in (column..<(column + width)).map { line * columns + $0 } }
    }
}
