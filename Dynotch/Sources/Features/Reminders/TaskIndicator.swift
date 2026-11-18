import Combine
import Foundation

/// What the tasks counter beside the notch shows (spec R-10).
struct TaskCount: Equatable, Sendable {
    let count: Int
    /// Due today (or overdue); otherwise every open task.
    let isToday: Bool

    var text: String {
        isToday ? "\(count) task\(count == 1 ? "" : "s") due today" : "\(count) open task\(count == 1 ? "" : "s")"
    }
}

/// How long the × hides the counter (spec R-11).
enum TaskSnooze: Int, CaseIterable, Sendable {
    case quarterHour = 15
    case halfHour = 30
    case hour = 60
    case twoHours = 120
    case tomorrow = 0

    var title: String {
        switch self {
        case .quarterHour: "15 minutes"
        case .halfHour: "30 minutes"
        case .hour: "1 hour"
        case .twoHours: "2 hours"
        case .tomorrow: "Until tomorrow"
        }
    }

    func until(from now: Date, calendar: Calendar = .current) -> Date {
        guard self != .tomorrow else {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        }
        return now.addingTimeInterval(TimeInterval(rawValue * 60))
    }
}

enum TaskIndicatorLogic {
    /// Today's tasks (due today or overdue) if there are any, otherwise every open one.
    static func count(_ items: [ReminderItem], now: Date, calendar: Calendar = .current) -> TaskCount? {
        let today = items.filter { item in
            item.isOverdue(at: now, calendar: calendar) || item.due.map { calendar.isDate($0, inSameDayAs: now) } == true
        }
        if !today.isEmpty { return TaskCount(count: today.count, isToday: true) }
        return items.isEmpty ? nil : TaskCount(count: items.count, isToday: false)
    }

    /// The hidden counter comes back when its time is up or a task arrived meanwhile.
    static func showsAgain(hiddenUntil: Date, hiddenIDs: Set<String>, openIDs: [String], now: Date) -> Bool {
        hiddenUntil <= now || openIDs.contains { !hiddenIDs.contains($0) }
    }
}

/// The tasks counter right of the closed notch: on or off, hidden for a while by its × (spec R-10, R-11).
@MainActor
final class TaskIndicator: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.enabled); update() }
    }
    @Published var snooze: TaskSnooze {
        didSet { defaults.set(snooze.rawValue, forKey: Key.snooze) }
    }
    @Published private(set) var shown: TaskCount?

    private enum Key {
        static let enabled = "taskIndicator"
        static let snooze = "taskIndicatorSnooze"
        static let hiddenUntil = "taskIndicatorHiddenUntil"
        static let hiddenIDs = "taskIndicatorHiddenIDs"
    }

    private let store: RemindersStore
    private let defaults: UserDefaults
    private var hiddenUntil: Date?
    private var hiddenIDs: Set<String>
    private var changes: AnyCancellable?
    private var wake: Task<Void, Never>?

    init(store: RemindersStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        snooze = (defaults.object(forKey: Key.snooze) as? Int).flatMap(TaskSnooze.init(rawValue:)) ?? .hour
        hiddenUntil = defaults.object(forKey: Key.hiddenUntil) as? Date
        hiddenIDs = Set(defaults.stringArray(forKey: Key.hiddenIDs) ?? [])
        // objectWillChange fires before the change: look once it has happened.
        changes = store.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        update()
        scheduleWake()
    }

    private var openItems: [ReminderItem] {
        store.access == .granted ? store.open.filter { !store.completing.contains($0.id) } : []
    }

    /// The ×: hidden for the chosen time, or until a new task arrives.
    func hide(now: Date = Date()) {
        hiddenUntil = snooze.until(from: now)
        hiddenIDs = Set(openItems.map(\.id))
        save()
        update(now: now)
        scheduleWake()
    }

    func update(now: Date = Date()) {
        let items = openItems
        if let until = hiddenUntil,
           TaskIndicatorLogic.showsAgain(hiddenUntil: until, hiddenIDs: hiddenIDs, openIDs: items.map(\.id), now: now) {
            hiddenUntil = nil
            hiddenIDs = []
            save()
        }
        let next = isEnabled && hiddenUntil == nil ? TaskIndicatorLogic.count(items, now: now) : nil
        if next != shown { shown = next }
    }

    private func save() {
        defaults.set(hiddenUntil, forKey: Key.hiddenUntil)
        defaults.set(Array(hiddenIDs), forKey: Key.hiddenIDs)
    }

    /// Shows the counter again when the snooze ends, even if nothing else changes.
    private func scheduleWake() {
        wake?.cancel()
        guard let until = hiddenUntil else { return }
        wake = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(until.timeIntervalSinceNow, 0) + 1))
            guard !Task.isCancelled else { return }
            self?.update()
        }
    }
}
