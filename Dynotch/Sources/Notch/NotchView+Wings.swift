import SwiftUI

// MARK: - DyNotch Wings content (spec PV-9)

extension NotchView {
    /// What stands left of the notch for the current module.
    @ViewBuilder var wingsLeft: some View {
        switch model.currentFeature {
        case .calendar: calendarWingLeft
        case .notifications: notificationsWingLeft
        case .calculator: WingLabel(symbol: "equal.square", text: lastCalculation?.line ?? "Empty")
        case .notes: WingLabel(symbol: "note.text", text: noteLines.first ?? "Empty note")
        case .reminders: remindersWingLeft
        case .claudeUsage: usageWing(id: "five_hour", title: "5h")
        case .claudeChat: WingLabel(symbol: "sparkles", text: chat.isWorking ? "Working…" : chat.selected?.title ?? "Claude")
        case .battery: batteryWingLeft
        case .clipboard: clipboardWingLeft
        case .tray: trayWingLeft
        case .music: musicWingLeft
        case .stats: statsWingLeft
        case .home: TimelineView(.periodic(from: .now, by: 1)) { WingText($0.date.formatted(date: .omitted, time: .shortened), bold: true) }
        case .info: WingText("Dynotch \(AppInfo.version)", bold: true)
        }
    }

    /// What stands right of the notch for the current module.
    @ViewBuilder var wingsRight: some View {
        switch model.currentFeature {
        case .calendar: calendarWingRight
        case .notifications: WingText(featurePreview.detail)
        case .calculator: calculatorWingRight
        case .notes: WingText(noteLines.dropFirst().first ?? "", dim: true)
        case .reminders: remindersWingRight
        case .claudeUsage: usageWing(id: "seven_day", title: "Week", showsReset: true)
        case .claudeChat: WingText(FeaturePreview.line(of: lastAnswer, fallback: "Ask Claude anything"), dim: true)
        case .battery: batteryWingRight
        case .clipboard: clipboardWingRight
        case .tray: trayWingRight
        case .music: musicWingRight
        case .stats: statsWingRight
        case .home: WingText(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()), dim: true)
        case .info: WingText(model.screenName, dim: true)
        }
    }

    // MARK: Calendar

    private var nextEvent: CalendarEvent? {
        calendar.events(on: Date()).first { $0.end > Date() && !$0.isAllDay }
    }

    private var calendarWingLeft: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if let event = nextEvent {
                HStack(spacing: 6) {
                    WingSymbol("calendar")
                    WingText(event.start.formatted(date: .omitted, time: .shortened), bold: true)
                    WingText(WingFormat.countdown(to: event.start, end: event.end, now: context.date), dim: true)
                }
            } else {
                WingLabel(symbol: "calendar", text: "Nothing more today")
            }
        }
    }

    @ViewBuilder private var calendarWingRight: some View {
        if let event = nextEvent {
            HStack(spacing: 8) {
                WingText(event.title)
                if event.meetingURL != nil {
                    WingButton(title: "Join", symbol: "video.fill", prominent: true) { joinedMeeting(event) }
                }
            }
        }
    }

    // MARK: Notifications

    private var notificationsWingLeft: some View {
        let groups = Dictionary(grouping: notifications.recent, by: \.appIdentifier)
            .map { key, list in
                (app: notifications.catalog.app(for: key), count: list.count, newest: list.map(\.date).max() ?? .distantPast)
            }
            .sorted { $0.newest > $1.newest }
            .prefix(4)
        return HStack(spacing: 8) {
            if groups.isEmpty, notifications.mail.totalUnread == 0 {
                WingLabel(symbol: "bell", text: "No new notifications")
            }
            if notifications.mail.isActive, notifications.mail.totalUnread > 0 {
                WingCount(count: notifications.mail.totalUnread) { WingSymbol("envelope.fill") }
            }
            ForEach(Array(groups), id: \.app.identifier) { group in
                WingCount(count: group.count) { AppIconView(app: group.app, size: 16) }
            }
        }
    }

    // MARK: Calculator, notes, chat

    private var lastCalculation: (line: String, result: String)? {
        CalculatorEngine.results(in: calculator.text).last
    }

    @ViewBuilder private var calculatorWingRight: some View {
        if let result = lastCalculation?.result {
            WingButton(title: "= " + result, symbol: nil, help: "Copy the result") { WingFormat.copy(result) }
        }
    }

    private var noteLines: [String] {
        notes.text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var lastAnswer: String {
        chat.selected?.messages.last { $0.role == .assistant }?.text ?? ""
    }

    // MARK: Reminders

    private var remindersWingLeft: some View {
        let overdue = reminders.open.filter { $0.isOverdue(at: Date()) }.count
        return HStack(spacing: 6) {
            WingSymbol("checklist")
            WingText(reminders.open.isEmpty ? "Nothing open" : "\(reminders.open.count) open", bold: true)
            if overdue > 0 { WingText("· \(overdue) overdue").foregroundStyle(.red) }
        }
    }

    @ViewBuilder private var remindersWingRight: some View {
        let next = reminders.open.filter { $0.due != nil }.min { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
            ?? reminders.open.first
        if let next {
            HStack(spacing: 8) {
                WingText(next.title)
                if let due = next.due {
                    let time = next.dueHasTime
                        ? due.formatted(date: .omitted, time: .shortened) : due.formatted(.dateTime.month(.abbreviated).day())
                    WingText(time, dim: true)
                }
                WingButton(title: nil, symbol: "checkmark.circle", help: "Done") { reminders.complete(next) }
            }
        }
    }

    // MARK: AI usage

    @ViewBuilder private func usageWing(id: String, title: String, showsReset: Bool = false) -> some View {
        if let limit = claudeUsage.limits.first(where: { $0.id == id }) {
            HStack(spacing: 6) {
                WingText(title, dim: true)
                StatsBar(fraction: limit.utilization / 100, color: WingFormat.color(limit.level)).frame(width: 56)
                WingText("\(Int(limit.utilization.rounded()))%", bold: true)
                if showsReset, let reset = limit.resetsAt {
                    WingText("· " + reset.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)), dim: true)
                }
            }
        } else if id == "five_hour" {
            WingLabel(symbol: "gauge.with.dots.needle.50percent", text: "No usage loaded")
        }
    }
}
