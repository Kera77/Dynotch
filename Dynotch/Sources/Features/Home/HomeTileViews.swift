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
        .onTapGesture(coordinateSpace: .named(viewportSpace)) { location in
            let anchor = UnitPoint(x: location.x / max(viewport.width, 1), y: location.y / max(viewport.height, 1))
            open(tile, anchor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open(tile, .center) }
        .help(tile.feature == .home ? tile.title : "Open \(tile.feature.title)")
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
            Text(value)
                .font(.notch(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let detail {
                Text(detail)
                    .font(.notch(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

/// What a tile shows (spec HT-14).
struct HomeTileContent: View {
    let tile: HomeTile
    let calendar: CalendarService
    let stats: StatsService

    var body: some View {
        if tile.feature == .stats {
            StatsTileContent(tile: tile, stats: stats)
        } else if tile == .nextEvent {
            NextEventTileContent(calendar: calendar)
        } else {
            ClockTileContent(isWide: tile == .clockWide)
        }
    }
}

private struct ClockTileContent: View {
    let isWide: Bool

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 1) {
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.notch(size: isWide ? 34 : 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(context.date, format: isWide ? .dateTime.weekday(.wide).month(.wide).day() : .dateTime.weekday().day())
                    .font(.notch(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct NextEventTileContent: View {
    var calendar: CalendarService

    var body: some View {
        TimelineView(.everyMinute) { context in
            if calendar.access != .granted {
                TileValueView(title: "Calendar", value: "—", detail: "Needs access")
            } else if let event = calendar.events(on: context.date).first(where: { !$0.isAllDay && $0.end > context.date }) {
                TileValueView(
                    title: event.title,
                    value: event.start.formatted(date: .omitted, time: .shortened),
                    detail: Self.countdown(to: event, now: context.date)
                )
            } else {
                TileValueView(title: "Calendar", value: "—", detail: "Nothing more today")
            }
        }
    }

    static func countdown(to event: CalendarEvent, now: Date) -> String {
        if event.isOngoing(at: now) { return "Now" }
        let minutes = Int((event.start.timeIntervalSince(now) / 60).rounded(.up))
        return minutes < 60 ? "in \(minutes) min" : "in \(minutes / 60) h \(minutes % 60) min"
    }
}

private struct StatsTileContent: View {
    let tile: HomeTile
    var stats: StatsService

    var body: some View {
        let snapshot = stats.snapshot
        switch tile {
        case .cpu:
            VStack(alignment: .leading, spacing: 4) {
                TileValueView(title: "CPU", value: StatsFormat.percent(snapshot.cpu), color: StatsSlot.color(for: snapshot.cpu))
                StatsSparkline(values: stats.cpuHistory, top: 1, color: Theme.blue).frame(height: 18)
            }
        case .memory:
            TileValueView(
                title: "Memory", value: StatsFormat.percent(snapshot.memoryShare),
                detail: snapshot.memory.map { "\(StatsFormat.bytes(Double($0.used))) of \(StatsFormat.bytes(Double($0.total)))" },
                color: StatsSlot.color(for: snapshot.memoryShare)
            )
        case .swap:
            TileValueView(title: "Swap", value: snapshot.memory.map { StatsFormat.bytes(Double($0.swapUsed)) } ?? "—")
        case .network:
            TileValueView(
                title: "Network", value: "↓ " + StatsFormat.shortRate(snapshot.download),
                detail: "↑ " + StatsFormat.rate(snapshot.upload)
            )
        case .disk:
            diskContent(snapshot.disk)
        default:
            batteryContent(snapshot.battery)
        }
    }

    @ViewBuilder
    private func diskContent(_ disk: SystemReadings.Disk?) -> some View {
        if let disk {
            let used = 1 - Double(disk.free) / Double(max(disk.total, 1))
            VStack(alignment: .leading, spacing: 4) {
                TileValueView(title: "Disk", value: StatsFormat.bytes(Double(disk.free)), detail: "free")
                StatsBar(fraction: used, color: StatsSlot.color(for: used))
            }
        } else {
            TileValueView(title: "Disk", value: "—")
        }
    }

    @ViewBuilder
    private func batteryContent(_ battery: MacBattery?) -> some View {
        if let battery {
            let state = battery.isCharging ? "Charging" : battery.isOnPower ? "On power" : "On battery"
            let left = battery.minutesLeft.map { " · " + StatsFormat.minutes($0) } ?? ""
            TileValueView(
                title: "Battery", value: "\(battery.level)%", detail: state + left,
                color: battery.level <= 20 && !battery.isOnPower ? Theme.red : .white
            )
        } else {
            TileValueView(title: "Battery", value: "—", detail: "No battery")
        }
    }
}
