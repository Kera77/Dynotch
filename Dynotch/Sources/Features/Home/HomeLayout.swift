import CoreGraphics

/// Where a tile sits in the Home's grid, in rows and columns.
struct TilePlacement: Equatable, Sendable {
    let tile: HomeTile
    let row: Int
    let column: Int
    let size: TileSize
}

/// The Home's grid (spec HT-3, HT-4).
enum HomeLayout {
    /// The narrowest a column gets; a wider panel gets more columns, not larger tiles.
    static let minimumTile: CGFloat = 100
    static let gap: CGFloat = 8

    /// As many columns of at least `minimumTile` as fit, at least two.
    static func columns(for width: CGFloat) -> Int {
        max(2, Int((width + gap) / (minimumTile + gap)))
    }

    /// A column's width (and a row's height: tiles are square) in `width` with `columns` columns.
    static func cell(width: CGFloat, columns: Int) -> CGFloat {
        max((width - gap * CGFloat(columns - 1)) / CGFloat(max(columns, 1)), 0)
    }

    /// Each tile in order, at the first place from the top left where it fits whole, so a later
    /// small tile fills the hole a wide one left at a row's end. A tile wider than the grid is narrowed.
    static func place(_ tiles: [HomeTile], columns: Int) -> [TilePlacement] {
        let columns = max(columns, 1)
        var taken = Set<Int>()
        var placements: [TilePlacement] = []
        for tile in tiles {
            let size = TileSize(rows: tile.size.rows, columns: min(tile.size.columns, columns))
            var row = 0
            placing: while true {
                for column in 0...(columns - size.columns)
                where fits(size, row: row, column: column, columns: columns, in: taken) {
                    for cell in cells(size, row: row, column: column, columns: columns) { taken.insert(cell) }
                    placements.append(TilePlacement(tile: tile, row: row, column: column, size: size))
                    break placing
                }
                row += 1
            }
        }
        return placements
    }

    /// How many rows the placed tiles fill.
    static func rows(of placements: [TilePlacement]) -> Int {
        placements.map { $0.row + $0.size.rows }.max() ?? 0
    }

    private static func fits(_ size: TileSize, row: Int, column: Int, columns: Int, in taken: Set<Int>) -> Bool {
        taken.isDisjoint(with: cells(size, row: row, column: column, columns: columns))
    }

    private static func cells(_ size: TileSize, row: Int, column: Int, columns: Int) -> [Int] {
        (row..<(row + size.rows)).flatMap { line in (column..<(column + size.columns)).map { line * columns + $0 } }
    }
}
