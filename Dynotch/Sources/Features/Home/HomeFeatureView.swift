import SwiftUI

/// The Home: the chosen tiles in a grid that scrolls, or the clock when there are none (spec HT-1…HT-6).
struct HomeFeatureView: View {
    var tiles: HomeTileSettings
    let calendar: CalendarService
    let stats: StatsService
    /// The Home is on screen: the tiles read their numbers only then (spec HT-9).
    let isActive: Bool
    /// A tile clicked, with where it is in the visible Home (spec HT-11).
    let open: (HomeTile, UnitPoint) -> Void

    private static let space = "homeViewport"

    var body: some View {
        if tiles.tiles.isEmpty {
            HomeClockView(showsHint: true)
        } else {
            GeometryReader { proxy in
                ScrollView(.vertical) {
                    grid(width: proxy.size.width)
                }
                .scrollIndicators(.never)
                .coordinateSpace(.named(Self.space))
                .environment(\.homeViewport, proxy.size)
            }
            .onAppear { stats.setTilesVisible(isActive && showsStats) }
            .onChange(of: isActive && showsStats) { _, visible in stats.setTilesVisible(visible) }
            .onDisappear { stats.setTilesVisible(false) }
        }
    }

    private var showsStats: Bool { tiles.tiles.contains { $0.feature == .stats } }

    private func grid(width: CGFloat) -> some View {
        let columns = HomeLayout.columns(for: width)
        let cell = HomeLayout.cell(width: width, columns: columns)
        let placements = HomeLayout.place(tiles.tiles, columns: columns)
        let rows = HomeLayout.rows(of: placements)
        let step = cell + HomeLayout.gap
        return ZStack(alignment: .topLeading) {
            ForEach(placements, id: \.tile) { placement in
                HomeTileCard(tile: placement.tile, viewportSpace: Self.space, open: open) {
                    HomeTileContent(tile: placement.tile, calendar: calendar, stats: stats)
                }
                .frame(
                    width: step * CGFloat(placement.size.columns) - HomeLayout.gap,
                    height: step * CGFloat(placement.size.rows) - HomeLayout.gap
                )
                .offset(x: step * CGFloat(placement.column), y: step * CGFloat(placement.row))
            }
        }
        .frame(width: width, height: max(step * CGFloat(rows) - HomeLayout.gap, 0), alignment: .topLeading)
        .animation(Motion.spring, value: placements)
    }
}

/// The clock and date: the Home without tiles (spec HT-1).
struct HomeClockView: View {
    var showsHint = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 4) {
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.notch(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(context.date, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.notch(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                if showsHint {
                    Text("Add tiles in Settings › Modules › Home")
                        .font(.notch(size: 11))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 6)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct HomeViewportKey: EnvironmentKey {
    static let defaultValue = CGSize(width: 1, height: 1)
}

extension EnvironmentValues {
    /// The visible Home's size, for where a clicked tile is (spec HT-11).
    var homeViewport: CGSize {
        get { self[HomeViewportKey.self] }
        set { self[HomeViewportKey.self] = newValue }
    }
}
