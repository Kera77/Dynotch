import SwiftUI

/// The Weather tiles (spec HT-14).
struct WeatherTileContent: View {
    let tile: HomeTile
    let size: TileSize
    var weather = WeatherService.shared

    var body: some View {
        if let forecast = weather.forecast {
            switch tile {
            case .hourly: hourly(forecast)
            case .fiveDays: days(forecast)
            case .rain: rain(forecast)
            default: now(forecast)
            }
        } else {
            TileEmptyView(title: "Weather", text: "No weather loaded")
        }
    }

    private func now(_ forecast: WeatherForecast) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: WeatherCode.symbol(forecast.now.code, isDay: forecast.now.isDay))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 18))
            TileValueView(
                title: weather.placeName,
                value: WeatherService.degrees(forecast.now.temperature),
                detail: forecast.today.map { "H \(WeatherService.degrees($0.high))  L \(WeatherService.degrees($0.low))" }
            )
        }
    }

    private func hourly(_ forecast: WeatherForecast) -> some View {
        let hours = forecast.hours.filter { $0.time > Date().addingTimeInterval(-3600) }.prefix(6)
        return HStack(spacing: 0) {
            ForEach(Array(hours)) { hour in
                VStack(spacing: 3) {
                    Text(hour.time, format: .dateTime.hour())
                        .font(.notch(size: 9))
                        .foregroundStyle(.secondary)
                    Image(systemName: WeatherCode.symbol(hour.code, isDay: hour.isDay))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 13))
                    Text(WeatherService.degrees(hour.temperature))
                        .font(.notch(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func days(_ forecast: WeatherForecast) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(forecast.days.prefix(5))) { day in
                HStack(spacing: 6) {
                    Text(day.date, format: .dateTime.weekday())
                        .font(.notch(size: 11))
                        .frame(width: 32, alignment: .leading)
                    Image(systemName: WeatherCode.symbol(day.code))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 12))
                        .frame(width: 18)
                    Spacer(minLength: 2)
                    Text("\(WeatherService.degrees(day.low)) – \(WeatherService.degrees(day.high))")
                        .font(.notch(size: 11))
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func rain(_ forecast: WeatherForecast) -> some View {
        let next = Self.nextRain(in: forecast.hours, now: Date())
        return TileValueView(
            title: "Rain",
            value: next.map { $0.time.formatted(date: .omitted, time: .shortened) } ?? "—",
            detail: next.map { "\($0.rainChance)% chance" } ?? "No rain soon",
            color: next == nil ? .white : Theme.blue
        )
    }

    /// The first hour in the next twelve with at least a 50% chance of rain.
    nonisolated static func nextRain(in hours: [WeatherForecast.Hour], now: Date) -> WeatherForecast.Hour? {
        hours.first { $0.time > now.addingTimeInterval(-3600) && $0.time < now.addingTimeInterval(12 * 3600) && $0.rainChance >= 50 }
    }
}

/// The Notifications and Reminders tiles (spec HT-14).
struct InboxTileContent: View {
    let tile: HomeTile
    let services: HomeTileServices
    let size: TileSize

    var body: some View {
        switch tile {
        case .unread: unread
        case .latest, .latestLarge: latest
        case .mail: mail
        case .remindersOpen: openReminders
        default: ReminderListTileContent(store: services.reminders, isToday: tile == .remindersToday, lines: size.lines)
        }
    }

    private var unread: some View {
        let badges = services.badges.visible.prefix(4)
        return VStack(alignment: .leading, spacing: 4) {
            Text("Unread").font(.notch(size: 10, weight: .medium)).foregroundStyle(.secondary)
            if badges.isEmpty {
                Text("Nothing unread").font(.notch(size: 11)).foregroundStyle(.secondary)
            }
            ForEach(Array(badges), id: \.app.bundleID) { badge in
                HStack(spacing: 4) {
                    BadgeIconView(icon: badge.app.icon, bundleID: badge.app.bundleID, size: 13)
                    Text(badge.label).font(.notch(size: 11, weight: .semibold)).monospacedDigit()
                }
            }
        }
    }

    private var latest: some View {
        let items = services.notifications.recent.prefix(size.rows == 1 ? 2 : 4)
        return VStack(alignment: .leading, spacing: 4) {
            if items.isEmpty {
                TileEmptyView(title: "Notifications", text: "No new notifications")
            }
            ForEach(Array(items), id: \.id) { notification in
                let content = services.notifications.content(for: notification)
                VStack(alignment: .leading, spacing: 0) {
                    Text(content.sender).font(.notch(size: 11, weight: .semibold)).lineLimit(1)
                    Text(content.detail).font(.notch(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var mail: some View {
        let unread = services.notifications.mail.totalUnread
        return TileValueView(title: "Mail", value: "\(unread)", detail: unread == 1 ? "unread message" : "unread messages")
    }

    private var openReminders: some View {
        let open = services.reminders.open
        let overdue = open.filter { ($0.due ?? .distantFuture) < Date() }.count
        return TileValueView(
            title: "Reminders", value: "\(open.count)",
            detail: overdue > 0 ? "\(overdue) overdue" : open.first?.title ?? "Nothing open",
            color: overdue > 0 ? Theme.red : .white
        )
    }
}

/// Reminders with a tick to complete them (spec HT-7): the next ones with a due date, or today's.
private struct ReminderListTileContent: View {
    var store: RemindersStore
    let isToday: Bool
    let lines: Int

    var body: some View {
        let items = Self.items(store.open, today: isToday, now: Date()).prefix(lines)
        VStack(alignment: .leading, spacing: 4) {
            Text(isToday ? "Today" : "Upcoming").font(.notch(size: 10, weight: .medium)).foregroundStyle(.secondary)
            if items.isEmpty {
                Text("Nothing due").font(.notch(size: 11)).foregroundStyle(.secondary)
            }
            ForEach(Array(items)) { item in
                TileRow(text: item.title, note: item.due.map { Self.dueText($0, hasTime: item.dueHasTime) }) {
                    Button { store.complete(item) } label: {
                        // The list's colour, as in the module (spec HT-50).
                        Image(systemName: "circle").font(.system(size: 11))
                            .foregroundStyle(store.list(for: item)?.color.color ?? Theme.blue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Complete \(item.title)")
                }
                .foregroundStyle((item.due ?? .distantFuture) < Date() ? Theme.red : .white)
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Upcoming: everything with a due date, soonest first. Today: due today or before.
    static func items(_ open: [ReminderItem], today: Bool, now: Date, calendar: Calendar = .current) -> [ReminderItem] {
        let dated = open.filter { $0.due != nil }.sorted { ($0.due ?? now) < ($1.due ?? now) }
        guard today else { return dated }
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return dated.filter { ($0.due ?? end) < end }
    }

    static func dueText(_ due: Date, hasTime: Bool) -> String {
        if Calendar.current.isDateInToday(due) { return hasTime ? due.formatted(date: .omitted, time: .shortened) : "Today" }
        return due.formatted(.dateTime.month(.abbreviated).day())
    }
}

/// The Notes, Calculator and Clipboard tiles (spec HT-14).
struct TextTileContent: View {
    let tile: HomeTile
    let services: HomeTileServices
    let size: TileSize

    var body: some View {
        switch tile {
        case .latestNote: latestNote
        case .todos: todos
        case .quickNote: QuickFieldTile(title: "Quick note", placeholder: "Add to the scratchpad…") { services.notes.addToScratchpad($0) }
        case .lastResult: lastResult
        case .keypad: CalculatorKeypadTile()
        case .notepad: CalculatorNotepadTile(store: services.calculator)
        case .lastCopied: lastCopied
        default: recentClips
        }
    }

    private var latestNote: some View {
        let note = services.notes.latest
        return VStack(alignment: .leading, spacing: 2) {
            Text(note?.name ?? "Notes").font(.notch(size: 11, weight: .semibold)).lineLimit(1)
            Text(note.map { FeaturePreview.line(of: $0.text, fallback: "Empty note") } ?? "No note yet")
                .font(.notch(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var todos: some View {
        let open = services.notes.text.split(whereSeparator: \.isNewline).map(String.init)
            .filter { Checklist.state(ofLine: $0) == false }
            .map { String($0.dropFirst(Checklist.openPrefix.count)) }
        return VStack(alignment: .leading, spacing: 4) {
            Text("To-dos").font(.notch(size: 10, weight: .medium)).foregroundStyle(.secondary)
            if open.isEmpty {
                Text("No open to-dos").font(.notch(size: 11)).foregroundStyle(.secondary)
            }
            ForEach(Array(open.prefix(size.lines).enumerated()), id: \.offset) { _, line in
                TileRow(text: line) { Image(systemName: "circle").font(.system(size: 10)) }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var lastResult: some View {
        let line = FeaturePreview.line(of: services.calculator.text, fallback: "", last: true)
        let result = line.split(separator: "=").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? line
        return HStack(alignment: .bottom) {
            TileValueView(title: line.isEmpty ? "Calculator" : line, value: result.isEmpty ? "—" : result)
            if !result.isEmpty {
                Spacer(minLength: 2)
                TileButton(symbol: "doc.on.doc", help: "Copy the result") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result, forType: .string)
                }
            }
        }
    }

    private var lastCopied: some View {
        let item = services.clipboard.history.first
        return VStack(alignment: .leading, spacing: 3) {
            Text("Last copied").font(.notch(size: 10, weight: .medium)).foregroundStyle(.secondary)
            Text(item.map { $0.kind == .image ? "Image" : $0.text } ?? "Nothing copied yet")
                .font(.notch(size: 11))
                .lineLimit(2)
            if let item {
                TileButton(symbol: "doc.on.doc", help: "Copy again") { services.clipboard.copy(item) }
            }
        }
    }

    private var recentClips: some View {
        let items = services.clipboard.history.prefix(size.rows == 1 ? 3 : 7)
        return VStack(alignment: .leading, spacing: 3) {
            if items.isEmpty {
                TileEmptyView(title: "Clipboard", text: "Nothing copied yet")
            }
            ForEach(Array(items)) { item in
                Button { services.clipboard.copy(item) } label: {
                    TileRow(text: item.kind == .image ? "Image" : item.text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        Image(systemName: item.kind == .image ? "photo" : "doc.text").font(.system(size: 10))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// A text field on a tile; Enter hands the text over (spec HT-28).
struct QuickFieldTile: View {
    let title: String
    let placeholder: String
    let submit: (String) -> Void

    @State private var text = ""
    @State private var done = false
    @FocusState private var isFocused: Bool
    @Environment(\.pinNotch) private var pinNotch

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(done ? "Done" : title)
                .font(.notch(size: 10, weight: .medium))
                .foregroundStyle(done ? Theme.green : .secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.notch(size: 12))
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).fill(Theme.selectedFill))
                .focused($isFocused)
                .onChange(of: isFocused) { _, focused in if focused { pinNotch() } }
                .onSubmit(send)
        }
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        submit(trimmed)
        text = ""
        done = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            done = false
        }
    }
}
