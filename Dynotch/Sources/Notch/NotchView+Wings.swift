import SwiftUI

// MARK: - DyNotch Wings content (spec PV-9)

extension NotchView {
    /// What stands left of the notch for the current module.
    @ViewBuilder var wingsLeft: some View {
        switch wingsFeature {
        case .calendar: calendarWingLeft
        case .notifications: notificationsWingLeftV2
        case .calculator: WingLabel(symbol: "equal.square", text: lastCalculation?.line ?? "Empty")
        case .notes: notesWingLeftV2
        case .reminders: remindersWingLeftV2
        case .claudeUsage: aiWingLeft
        case .claudeChat: WingLabel(symbol: "sparkles", text: chat.isWorking ? "Working…" : chat.selected?.title ?? "Claude")
        case .battery: batteryWingLeft
        case .clipboard: clipboardWingLeftV2
        case .tray: trayWingLeft
        case .music: musicWingLeft
        case .stats: statsWingLeftV2
        case .home: TimelineView(.periodic(from: .now, by: 1)) { WingText($0.date.formatted(date: .omitted, time: .shortened), bold: true) }
        case .info: WingText("Dynotch \(AppInfo.version)", bold: true)
        case .terminal: WingLabel(symbol: "apple.terminal", text: TerminalStore.shared.selected?.title ?? "Terminal")
        }
    }

    /// What stands right of the notch for the current module.
    @ViewBuilder var wingsRight: some View {
        switch wingsFeature {
        case .calendar: calendarWingRight
        case .notifications: notificationsWingRightV2
        case .calculator: calculatorWingRight
        case .notes: notesWingRightV2
        case .reminders: remindersWingRightV2
        case .claudeUsage: usageSessionWing
        case .claudeChat: WingText(FeaturePreview.line(of: lastAnswer, fallback: "Ask Claude anything"), dim: true)
        case .battery: batteryWingRight
        case .clipboard: clipboardWingRightV2
        case .tray: trayWingRight
        case .music: musicWingRight
        case .stats: statsWingRightV2
        case .home: WingText(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()), dim: true)
        case .info: WingText(model.screenName, dim: true)
        case .terminal: WingText(TerminalWing.tabs(TerminalStore.shared.sessions.count), dim: true)
        }
    }

    /// The top of the module strip: under the notch, or under the Wings and what hangs below them (spec PV-29).
    var stripTop: CGFloat {
        model.isExpanded && model.isPreview ? max(model.openSize.height, geometry.notchSize.height) : geometry.notchSize.height
    }

    /// The Wings in the open panel (spec PV-4, PV-24).
    var wingsContent: some View {
        WingsView(
            notchWidth: geometry.notchSize.width, sides: model.wingsSides, openFully: openFully,
            measured: wingsMeasured, identity: wingsFeature.rawValue,
            left: { wingsLeft },
            right: { wingsRight }
        )
        .frame(width: model.openSize.width, height: model.openSize.height)
    }

    /// Each side's natural width, measured by the Wings (spec PV-24).
    func wingsMeasured(_ needs: WingsSides) {
        let old = model.wingsLasting.needs
        // While something is hovered the wings never narrow under the pointer (spec PV-40); the
        // Notifications text on the right always fits its content (spec PV-65).
        let fitsRight = wingsFeature == .notifications
        let needs = model.wings.holdsWidth
            ? WingsSides(left: max(old.left, needs.left), right: fitsRight ? needs.right : max(old.right, needs.right)) : needs
        guard abs(old.left - needs.left) > 1 || abs(old.right - needs.right) > 1 else { return }
        withAnimation(Self.quickAnimation) { model.wingsLasting.needs = needs }
    }

    /// A second click on the open panel's notch folds it back into the Wings (spec PV-23).
    @ViewBuilder var backToWingsArea: some View {
        if settings.hoverPreview, !model.isShowingNotifications {
            Color.clear
                .frame(width: geometry.notchSize.width, height: geometry.notchSize.height)
                .contentShape(Rectangle())
                .onTapGesture(perform: backToWings)
        }
    }

    /// The module whose wings show: the merged AI module always shows the session (spec PV-30).
    private var wingsFeature: FeatureID {
        let feature = model.currentFeature
        if feature == .claudeChat, settings.isEnabled(.claudeUsage) { return .claudeUsage }
        return feature
    }

    // MARK: Calendar (spec PV-25)

    /// The next event that is not all day, whichever day it is on.
    private var nextEvent: CalendarEvent? {
        let now = Date()
        return calendar.events.filter { $0.end > now && !$0.isAllDay }.min { $0.start < $1.start }
    }

    private var calendarWingLeft: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if let event = nextEvent {
                HStack(spacing: 6) {
                    WingSymbol("calendar")
                    if let day = WingFormat.day(of: event.start, now: context.date) {
                        WingText(day, bold: true)
                        WingText(event.start.formatted(date: .omitted, time: .shortened), dim: true)
                    } else {
                        WingText(event.start.formatted(date: .omitted, time: .shortened), bold: true)
                        WingText(WingFormat.countdown(to: event.start, end: event.end, now: context.date), dim: true)
                    }
                }
            } else {
                WingLabel(symbol: "calendar", text: "Nothing coming up")
            }
        }
    }

    @ViewBuilder private var calendarWingRight: some View {
        if let event = nextEvent {
            HStack(spacing: 8) {
                // Join nearest the notch, the first thing the pointer reaches (spec PV-74).
                if event.meetingURL != nil {
                    WingButton(title: "Join", symbol: "video.fill", prominent: true) { joinedMeeting(event) }
                }
                WingText(event.title)
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

    // MARK: AI usage (spec PV-43)

    /// The AI chosen in the module: its logo and name; the chat tab's own AI there (spec PV-50).
    private var aiWingLeft: some View {
        AIWing(usage: claudeUsage, chat: chat, isChat: model.currentFeature == .claudeChat, side: .left)
    }

    /// That AI's current session (spec PV-50).
    var usageSessionWing: some View {
        AIWing(usage: claudeUsage, chat: chat, isChat: model.currentFeature == .claudeChat, side: .right)
    }
}
