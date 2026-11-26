import SwiftUI

/// The Home's own and the Calendar's tiles (spec HT-14, HT-18, HT-27).
struct CalendarTileContent: View {
    let tile: HomeTile
    let services: HomeTileServices
    let size: TileSize

    var body: some View {
        switch tile {
        case .clock, .clockWide:
            ClockTileContent(isWide: tile == .clockWide)
        case .worldClock:
            WorldClockTileContent(settings: .shared)
        case .today:
            TodayTileContent(services: services)
        case .month:
            // One row, two columns: the month without empty room (spec HT-52).
            HomeMonthGrid(calendar: services.calendar, pager: .shared, compact: size.rows < 2)
        case .nextEvent, .nextEventWide:
            NextEventTileContent(calendar: services.calendar, isWide: tile == .nextEventWide)
        case .week:
            WeekTileContent(calendar: services.calendar)
        case .agendaTall, .agenda:
            AgendaTileContent(calendar: services.calendar, lines: size.lines)
        case .days:
            DaysTileContent(calendar: services.calendar)
        default:
            CalendarLargeTileContent(calendar: services.calendar, isWide: tile == .calendarWide)
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

/// The time in another zone, and how far it is from here (spec HT-29).
private struct WorldClockTileContent: View {
    var settings: HomeTileSettings

    var body: some View {
        let zone = settings.worldClockTimeZone
        TimelineView(.everyMinute) { context in
            TileValueView(
                title: Self.city(of: zone),
                value: context.date.formatted(Date.FormatStyle(timeZone: zone).hour().minute()),
                detail: Self.difference(zone, at: context.date)
            )
        }
    }

    static func city(of zone: TimeZone) -> String {
        (zone.identifier.split(separator: "/").last.map(String.init) ?? zone.identifier).replacingOccurrences(of: "_", with: " ")
    }

    static func difference(_ zone: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
        guard seconds != 0 else { return "Same time" }
        let hours = Double(seconds) / 3600
        let text = hours.rounded() == hours ? "\(Int(hours))" : String(format: "%.1f", hours)
        return (seconds > 0 ? "+" : "") + text + " h"
    }
}

/// The next event, with Join on the wide tile (spec HT-14).
private struct NextEventTileContent: View {
    var calendar: CalendarService
    let isWide: Bool

    var body: some View {
        TimelineView(.everyMinute) { context in
            if calendar.access != .granted {
                TileEmptyView(title: "Calendar", text: "Needs access")
            } else if let event = calendar.events(on: context.date).first(where: { !$0.isAllDay && $0.end > context.date }) {
                HStack(alignment: .bottom) {
                    TileValueView(
                        title: event.title,
                        value: event.start.formatted(date: .omitted, time: .shortened),
                        detail: Self.countdown(to: event, now: context.date)
                    )
                    if isWide, event.meetingURL != nil {
                        Spacer(minLength: 4)
                        TileButton(symbol: "video.fill", help: "Join") { calendar.join(event) }
                    }
                }
            } else {
                TileEmptyView(title: "Calendar", text: "Nothing more today")
            }
        }
    }

    static func countdown(to event: CalendarEvent, now: Date) -> String {
        if event.isOngoing(at: now) { return "Now" }
        let minutes = Int((event.start.timeIntervalSince(now) / 60).rounded(.up))
        return minutes < 60 ? "in \(minutes) min" : "in \(minutes / 60) h \(minutes % 60) min"
    }
}

/// The week's seven days, a dot under the days with events.
private struct WeekTileContent: View {
    var calendar: CalendarService

    var body: some View {
        let days = Self.days(of: Date())
        let today = Calendar.current.startOfDay(for: Date())
        HStack(spacing: 2) {
            ForEach(days, id: \.self) { day in
                VStack(spacing: 2) {
                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(.notch(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(day, format: .dateTime.day())
                        .font(.notch(size: 13, weight: .semibold, design: .rounded))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(day == today ? Theme.blue : .clear))
                    Circle()
                        .fill((calendar.dayCounts[day] ?? 0) > 0 ? Color.white.opacity(0.7) : .clear)
                        .frame(width: 4, height: 4)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    static func days(of date: Date, calendar: Calendar = .current) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

/// The rest of today's events.
struct AgendaTileContent: View {
    var calendar: CalendarService
    let lines: Int

    var body: some View {
        TimelineView(.everyMinute) { context in
            let events = calendar.events(on: context.date).filter { $0.end > context.date }
            if calendar.access != .granted {
                TileEmptyView(title: "Today", text: "Needs access")
            } else if events.isEmpty {
                TileEmptyView(title: "Today", text: "Nothing more today")
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today").font(.notch(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    ForEach(events.prefix(lines)) { event in
                        TileRow(text: event.title, note: event.isAllDay ? nil : event.start.formatted(date: .omitted, time: .shortened)) {
                            Capsule().fill(event.color.color).frame(width: 3, height: 12)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

/// The month and today's events: 2×3 side by side, 3×2 one above the other (spec HT-14).
private struct CalendarLargeTileContent: View {
    var calendar: CalendarService
    let isWide: Bool

    var body: some View {
        if isWide {
            HStack(alignment: .top, spacing: 10) {
                HomeMonthGrid(calendar: calendar, pager: .shared, compact: false)
                AgendaTileContent(calendar: calendar, lines: 6)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HomeMonthGrid(calendar: calendar, pager: .shared, compact: false)
                AgendaTileContent(calendar: calendar, lines: 4)
            }
        }
    }
}

/// A month: today in blue, a dot under days with events; a swipe over it pages the months (spec HT-18).
struct HomeMonthGrid: View {
    var calendar: CalendarService
    var pager: MonthTilePager
    let compact: Bool

    var body: some View {
        let month = pager.month()
        let days = Self.cells(of: month)
        let today = Calendar.current.startOfDay(for: Date())
        let font: CGFloat = compact ? 7.5 : 10
        VStack(alignment: .leading, spacing: compact ? 1 : 3) {
            HStack(spacing: 4) {
                Text(month, format: Self.isThisYear(month) ? .dateTime.month(.wide) : .dateTime.month(.abbreviated).year())
                    .font(.notch(size: compact ? 9 : 11, weight: .semibold))
                    .foregroundStyle(pager.offset == 0 ? Theme.red : .white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if pager.offset != 0 {
                    Button("Today") { withAnimation(Motion.quick) { pager.reset() } }
                        .buttonStyle(.plain)
                        .font(.notch(size: compact ? 8 : 10, weight: .medium))
                        .foregroundStyle(Theme.blue)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: compact ? 0 : 2) {
                ForEach(Self.weekdayLetters(), id: \.self) { letter in
                    Text(letter).font(.notch(size: font - 1, weight: .medium)).foregroundStyle(.secondary)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    dayCell(day, today: today, font: font)
                }
            }
        }
        .onHover { pager.isHovered = $0 }
        .onAppear { calendar.ensureLoaded(month: month) }
        .onChange(of: pager.offset) { _, _ in calendar.ensureLoaded(month: pager.month()) }
    }

    @ViewBuilder
    private func dayCell(_ day: Date?, today: Date, font: CGFloat) -> some View {
        if let day {
            let hasEvents = (calendar.dayCounts[day] ?? 0) > 0
            Text(day, format: .dateTime.day())
                .font(.notch(size: font, weight: day == today ? .bold : .regular))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 0 : 1)
                .background(Circle().fill(day == today ? Theme.red : .clear).padding(compact ? -1 : 0))
                .overlay(alignment: .bottom) {
                    if hasEvents, !compact {
                        Circle().fill(Color.white.opacity(0.6)).frame(width: 3, height: 3).offset(y: 3)
                    }
                }
                .opacity(hasEvents || !compact ? 1 : 0.75)
        } else {
            Text(" ").font(.notch(size: font))
        }
    }

    static func isThisYear(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
    }

    /// The month's days in weeks, with empty cells before the first day.
    static func cells(of month: Date, calendar: Calendar = .current) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let days: [Date?] = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
        return Array(repeating: nil, count: leading) + days
    }

    static func weekdayLetters(calendar: Calendar = .current) -> [String] {
        let letters = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        // Two days may share a letter: made unique for the grid's ids by a trailing space.
        return (0..<7).map { letters[(first + $0) % 7] + String(repeating: " ", count: $0) }
    }
}

/// The next event, the weather now and the open reminders; each part opens its module (spec HT-27).
private struct TodayTileContent: View {
    let services: HomeTileServices
    @Environment(\.openTilePart) private var openPart

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            part(.calendar, symbol: "calendar", text: nextEvent)
            part(.weather, symbol: weatherSymbol, text: weather)
            part(.reminders, symbol: "checklist", text: reminders)
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func part(_ feature: FeatureID, symbol: String, text: String) -> some View {
        Button { openPart(.today, feature) } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 12)).frame(width: 18)
                Text(text).font(.notch(size: 12)).lineLimit(2).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open \(feature.title)")
    }

    private var nextEvent: String {
        let now = Date()
        guard services.calendar.access == .granted else { return "Calendar needs access" }
        guard let event = services.calendar.events(on: now).first(where: { !$0.isAllDay && $0.end > now }) else {
            return "Nothing more today"
        }
        return event.start.formatted(date: .omitted, time: .shortened) + " · " + event.title
    }

    private var weatherSymbol: String {
        WeatherService.shared.forecast.map { WeatherCode.symbol($0.now.code, isDay: $0.now.isDay) } ?? "cloud.sun"
    }

    private var weather: String {
        guard let forecast = WeatherService.shared.forecast else { return "No weather loaded" }
        return WeatherService.degrees(forecast.now.temperature) + " · " + WeatherCode.text(forecast.now.code)
    }

    private var reminders: String {
        let open = services.reminders.open
        guard let first = open.first else { return "Nothing open" }
        return "\(open.count) open · \(first.title)"
    }
}
