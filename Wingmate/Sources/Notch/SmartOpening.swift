import AppKit

/// What makes the notch open on a module other than the last one, when it opens by hover
/// (spec SO-1…SO-4). New notifications and Claude's answers already open their own views.
enum SmartRule: String, CaseIterable, Sendable {
    case meeting
    case notice
    case reminder
    case code
    case clipboard
    case download
    case battery
    case usage
    case morning

    var title: String {
        switch self {
        case .meeting: "Calendar while a meeting is starting or on"
        case .notice: "The module of the latest notification"
        case .reminder: "Reminders when one is due within 15 minutes"
        case .code: "Clipboard with a code just copied"
        case .clipboard: "Calculator with a calculation just copied"
        case .download: "Tray with a file just downloaded"
        case .morning: "Calendar on the first opening of the morning"
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
    /// A code copied in the last 2 minutes, with the copy's number (spec SO-5).
    var code: (text: String, change: Int)?
    /// A file downloaded in the last 2 minutes (spec SO-6).
    var download: URL?
    /// Today, while it is morning (spec SO-7).
    var morning: String?
    /// The latest notification or notice, while its window lasts (spec SO-9).
    var notice: RecentNotice.Entry?

    static func == (lhs: SmartContext, rhs: SmartContext) -> Bool {
        lhs.meeting == rhs.meeting && lhs.reminder == rhs.reminder && lhs.clipboard?.text == rhs.clipboard?.text
            && lhs.clipboard?.change == rhs.clipboard?.change && lhs.battery == rhs.battery && lhs.usage == rhs.usage
            && lhs.code?.text == rhs.code?.text && lhs.code?.change == rhs.code?.change && lhs.download == rhs.download
            && lhs.morning == rhs.morning && lhs.notice == rhs.notice
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

    /// The first rule that applies, in this order: meeting, reminder, code copied, calculation
    /// copied, file downloaded, battery, AI usage, morning (spec SO-2, SO-8); the latest notification
    /// right after the meeting, and on every opening while it lasts, not once (spec SO-9, SO-10).
    static func choose(_ context: SmartContext, isOn: (SmartRule) -> Bool, used: Set<String>) -> Choice? {
        var candidates: [(SmartRule, Choice)] = []
        if let meeting = context.meeting { candidates.append((.meeting, Choice(feature: .calendar, key: "meeting:" + meeting))) }
        if let notice = context.notice {
            candidates.append((.notice, Choice(feature: notice.feature, key: "notice:" + notice.id)))
        }
        if let reminder = context.reminder { candidates.append((.reminder, Choice(feature: .reminders, key: "reminder:" + reminder))) }
        if let code = context.code { candidates.append((.code, Choice(feature: .clipboard, key: "code:\(code.change)"))) }
        if let copied = context.clipboard {
            candidates.append((.clipboard, Choice(feature: .calculator, key: "clipboard:\(copied.change)")))
        }
        if let download = context.download {
            candidates.append((.download, Choice(feature: .tray, key: "download:" + download.path)))
        }
        if let battery = context.battery { candidates.append((.battery, Choice(feature: .battery, key: "battery:" + battery))) }
        if let usage = context.usage, usage >= usageThreshold {
            candidates.append((.usage, Choice(feature: .claudeUsage, key: "usage:\(Int(usage / 10))")))
        }
        if let morning = context.morning { candidates.append((.morning, Choice(feature: .calendar, key: "morning:" + morning))) }
        return candidates.first { isOn($0.0) && ($0.0 == .notice || !used.contains($0.1.key)) }?.1
    }

    /// A reminder that is due soon or overdue.
    static func dueReminder(in items: [ReminderItem], now: Date) -> ReminderItem? {
        items.first { item in
            guard let due = item.due, item.dueHasTime, !item.isCompleted else { return false }
            return due.timeIntervalSince(now) <= reminderLead
        }
    }

    /// A copied text that is a calculation (or a number) for the calculator; a code is not (spec SO-5).
    static func calculation(in text: String) -> String? {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !line.contains("\n"), line.count <= 80, code(in: line) == nil else { return nil }
        return CalculatorEngine.evaluate(line) == nil ? nil : line
    }
}

extension SmartOpening {
    static let downloadWindow: TimeInterval = 120
    static let partialExtensions: Set<String> = ["crdownload", "download", "part", "partial"]

    /// A copied one-time code: 4–8 digits, at most one space or dash between them (spec SO-5).
    static func code(in text: String) -> String? {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = line.split(omittingEmptySubsequences: false) { $0 == " " || $0 == "-" }
        let digits = parts.joined()
        guard parts.count <= 2, parts.allSatisfy({ !$0.isEmpty }), (4...8).contains(digits.count),
              digits.allSatisfy({ $0.isASCII && $0.isNumber })
        else { return nil }
        return line
    }

    /// The day's key while it is morning, 5:00–12:00 (spec SO-7).
    static func morningKey(now: Date, calendar: Calendar = .current) -> String? {
        let hour = calendar.component(.hour, from: now)
        guard (5..<12).contains(hour) else { return nil }
        let day = calendar.dateComponents([.year, .month, .day], from: now)
        return "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
    }

    /// The newest finished file in Downloads from the last 2 minutes (spec SO-6). Read only
    /// when the notch opens.
    static func recentDownload(now: Date, folder: URL? = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first)
        -> URL? {
        guard let folder else { return nil }
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        )) ?? []
        return files.compactMap { url -> (URL, Date)? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isDirectory != true,
                  !partialExtensions.contains(url.pathExtension.lowercased()),
                  let date = values.contentModificationDate, now.timeIntervalSince(date) <= downloadWindow
            else { return nil }
            return (url, date)
        }.max { $0.1 < $1.1 }?.0
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

    /// The code copied in the last two minutes, if any (spec SO-5).
    func recentCode(now: Date) -> (text: String, change: Int)? {
        guard now.timeIntervalSince(copiedAt) <= SmartOpening.clipboardWindow,
              let text = NSPasteboard.general.string(forType: .string),
              let code = SmartOpening.code(in: text)
        else { return nil }
        return (code, lastCount)
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
