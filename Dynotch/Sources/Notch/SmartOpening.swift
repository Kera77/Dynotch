import AppKit

/// What makes the notch open on a module other than the last one, when it opens by hover
/// (spec SO-1…SO-4). New notifications and Claude's answers already open their own views.
enum SmartRule: String, CaseIterable, Sendable {
    case meeting
    case reminder
    case clipboard
    case battery
    case usage

    var title: String {
        switch self {
        case .meeting: "Calendar while a meeting is starting or on"
        case .reminder: "Reminders when one is due within 15 minutes"
        case .clipboard: "Calculator with a calculation just copied"
        case .battery: "Batteries when a device runs low"
        case .usage: "AI usage above 90%"
        }
    }
}

/// What is going on, for the smart opening.
struct SmartContext: Equatable, Sendable {
    /// A meeting being counted down or in progress.
    var meeting: String?
    /// A reminder due within 15 minutes or overdue.
    var reminder: String?
    /// A calculation copied in the last 2 minutes, with the copy's number.
    var clipboard: (text: String, change: Int)?
    /// A device with a low battery.
    var battery: String?
    /// The fullest AI limit's use, in percent.
    var usage: Double?

    static func == (lhs: SmartContext, rhs: SmartContext) -> Bool {
        lhs.meeting == rhs.meeting && lhs.reminder == rhs.reminder && lhs.clipboard?.text == rhs.clipboard?.text
            && lhs.clipboard?.change == rhs.clipboard?.change && lhs.battery == rhs.battery && lhs.usage == rhs.usage
    }
}

enum SmartOpening {
    static let reminderLead: TimeInterval = 15 * 60
    static let clipboardWindow: TimeInterval = 120
    static let usageThreshold: Double = 90

    struct Choice: Equatable {
        let feature: FeatureID
        /// One event opens its module once (spec SO-3).
        let key: String
    }

    /// The first rule that applies, in this order: meeting, reminder, calculation copied,
    /// battery, AI usage (spec SO-2).
    static func choose(_ context: SmartContext, isOn: (SmartRule) -> Bool, used: Set<String>) -> Choice? {
        var candidates: [(SmartRule, Choice)] = []
        if let meeting = context.meeting { candidates.append((.meeting, Choice(feature: .calendar, key: "meeting:" + meeting))) }
        if let reminder = context.reminder { candidates.append((.reminder, Choice(feature: .reminders, key: "reminder:" + reminder))) }
        if let copied = context.clipboard {
            candidates.append((.clipboard, Choice(feature: .calculator, key: "clipboard:\(copied.change)")))
        }
        if let battery = context.battery { candidates.append((.battery, Choice(feature: .battery, key: "battery:" + battery))) }
        if let usage = context.usage, usage >= usageThreshold {
            candidates.append((.usage, Choice(feature: .claudeUsage, key: "usage:\(Int(usage / 10))")))
        }
        return candidates.first { isOn($0.0) && !used.contains($0.1.key) }?.1
    }

    /// A reminder that is due soon or overdue.
    static func dueReminder(in items: [ReminderItem], now: Date) -> ReminderItem? {
        items.first { item in
            guard let due = item.due, item.dueHasTime, !item.isCompleted else { return false }
            return due.timeIntervalSince(now) <= reminderLead
        }
    }

    /// A copied text that is a calculation (or a number) for the calculator.
    static func calculation(in text: String) -> String? {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !line.contains("\n"), line.count <= 80 else { return nil }
        return CalculatorEngine.evaluate(line) == nil ? nil : line
    }
}

/// Notices when something is copied, so a fresh calculation can open the calculator.
@MainActor
final class ClipboardWatcher {
    static let shared = ClipboardWatcher()

    private var lastCount = NSPasteboard.general.changeCount
    private(set) var copiedAt = Date.distantPast

    /// Cheap: only the pasteboard's change counter is read.
    func poll() {
        let count = NSPasteboard.general.changeCount
        guard count != lastCount else { return }
        lastCount = count
        copiedAt = Date()
    }

    /// The calculation copied in the last two minutes, if any.
    func recentCalculation(now: Date) -> (text: String, change: Int)? {
        guard now.timeIntervalSince(copiedAt) <= SmartOpening.clipboardWindow,
              let text = NSPasteboard.general.string(forType: .string),
              let calculation = SmartOpening.calculation(in: text)
        else { return nil }
        return (calculation, lastCount)
    }
}
