import SwiftUI

// MARK: - DyNotch Wings content (spec PV-9)

extension NotchView {
    /// What stands left of the notch for the current module.
    @ViewBuilder var wingsLeft: some View {
        switch model.currentFeature {
        case .calendar: calendarWingLeft
        case .notifications: notificationsWingLeftV2
        case .calculator: WingLabel(symbol: "equal.square", text: lastCalculation?.line ?? "Empty")
        case .notes: notesWingLeftV2
        case .reminders: remindersWingLeftV2
        case .claudeUsage: usageWing(id: "seven_day", title: "Week", showsReset: true)
        case .claudeChat: WingLabel(symbol: "sparkles", text: chat.isWorking ? "Working…" : chat.selected?.title ?? "Claude")
        case .battery: batteryWingLeft
        case .clipboard: clipboardWingLeftV2
        case .tray: trayWingLeft
        case .music: musicWingLeft
        case .stats: statsWingLeftV2
        case .home: TimelineView(.periodic(from: .now, by: 1)) { WingText($0.date.formatted(date: .omitted, time: .shortened), bold: true) }
        case .info: WingText("Dynotch \(AppInfo.version)", bold: true)
        }
    }

    /// What stands right of the notch for the current module.
    @ViewBuilder var wingsRight: some View {
        switch model.currentFeature {
        case .calendar: calendarWingRight
        case .notifications: notificationsWingRightV2
        case .calculator: calculatorWingRight
        case .notes: notesWingRightV2
        case .reminders: remindersWingRight
        case .claudeUsage: usageSessionWing
        case .claudeChat: WingText(FeaturePreview.line(of: lastAnswer, fallback: "Ask Claude anything"), dim: true)
        case .battery: batteryWingRight
        case .clipboard: clipboardWingRightV2
        case .tray: trayWingRight
        case .music: musicWingRight
        case .stats: statsWingRightV2
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

    // MARK: Calculator, notes, chat

    private var lastCalculation: (line: String, result: String)? {
        CalculatorEngine.results(in: calculator.text).last
    }

    @ViewBuilder private var calculatorWingRight: some View {
        if let result = lastCalculation?.result {
            WingButton(title: result, symbol: nil, help: "Copy the result") { WingFormat.copy(result) }
        }
    }

    private var lastAnswer: String {
        chat.selected?.messages.last { $0.role == .assistant }?.text ?? ""
    }

    // MARK: Reminders

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
        }
    }
}
