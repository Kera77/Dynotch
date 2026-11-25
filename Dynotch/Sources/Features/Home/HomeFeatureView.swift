import SwiftUI

/// What the tiles read and act on (spec HT-7): the services the notch already has.
@MainActor
struct HomeTileServices {
    let calendar: CalendarService
    let stats: StatsService
    let notifications: NotificationService
    let badges: BadgeService
    let reminders: RemindersStore
    let notes: NotesStore
    let calculator: CalculatorStore
    let usage: ClaudeUsageService
    let chat: ClaudeChatService
    let battery: BatteryService
    let clipboard: ClipboardStore
    let tray: TrayStore
    let music: MusicService
}

/// The Home: the chosen tiles in a grid that scrolls, or the clock when there are none (spec HT-1…HT-6).
struct HomeFeatureView: View {
    var tiles: HomeTileSettings
    let services: HomeTileServices
    /// The Home is on screen: the tiles read their numbers only then (spec HT-9).
    let isActive: Bool
    /// A tile (or a part of one) clicked, with where it is in the visible Home (spec HT-11, HT-27).
    let open: @MainActor @Sendable (HomeTile, FeatureID?, UnitPoint) -> Void

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
                .environment(\.openTilePart) { [open] tile, part in open(tile, part, .center) }
            }
            .onAppear { visibilityChanged(isActive) }
            .onChange(of: isActive) { _, active in visibilityChanged(active) }
            .onDisappear { visibilityChanged(false) }
        }
    }

    /// The System's readings and the month page follow the Home being shown (spec HT-9, HT-18).
    private func visibilityChanged(_ visible: Bool) {
        let shown = Set(tiles.tiles.map(\.feature))
        services.stats.setTilesVisible(visible && shown.contains(.stats), processes: visible && tiles.contains(.topProcesses))
        guard visible else { return MonthTilePager.shared.reset() }
        if shown.contains(.weather) || tiles.contains(.today) { WeatherService.shared.refreshIfStale() }
        if shown.contains(.claudeUsage) { services.usage.refreshIfStale() }
        if shown.contains(.music) { services.music.refresh() }
        if tiles.contains(.latestNote) { services.notes.refreshLatest() }
    }

    private func grid(width: CGFloat) -> some View {
        let columns = HomeLayout.columns(for: width)
        let cell = HomeLayout.cell(width: width, columns: columns)
        let placements = HomeLayout.place(tiles.tiles, columns: columns)
        let rows = HomeLayout.rows(of: placements)
        let step = cell + HomeLayout.gap
        return ZStack(alignment: .topLeading) {
            ForEach(placements, id: \.tile) { placement in
                HomeTileCard(tile: placement.tile, viewportSpace: Self.space, open: { open($0, nil, $1) }) {
                    HomeTileContent(tile: placement.tile, services: services, size: placement.size)
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

/// The Month tile's page: months from now, stepped by a swipe over the tile (spec HT-18).
@MainActor
@Observable
final class MonthTilePager {
    static let shared = MonthTilePager()

    private(set) var offset = 0
    /// The pointer is over a Month or Calendar tile: a sideways swipe pages it, not the modules.
    var isHovered = false

    /// One month on or back; false when the pointer is not over the tile.
    func step(by months: Int) -> Bool {
        guard isHovered else { return false }
        offset += months
        return true
    }

    func reset() {
        if offset != 0 { offset = 0 }
    }

    /// The first day of the shown month.
    func month(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
        return calendar.date(byAdding: .month, value: offset, to: start) ?? start
    }
}

private struct HomeViewportKey: EnvironmentKey {
    static let defaultValue = CGSize(width: 1, height: 1)
}

private struct OpenTilePartKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable (HomeTile, FeatureID) -> Void = { _, _ in }
}

extension EnvironmentValues {
    /// The visible Home's size, for where a clicked tile is (spec HT-11).
    var homeViewport: CGSize {
        get { self[HomeViewportKey.self] }
        set { self[HomeViewportKey.self] = newValue }
    }

    /// Opens another module from a part of a tile (the Today tile, spec HT-27).
    var openTilePart: @MainActor @Sendable (HomeTile, FeatureID) -> Void {
        get { self[OpenTilePartKey.self] }
        set { self[OpenTilePartKey.self] = newValue }
    }
}
