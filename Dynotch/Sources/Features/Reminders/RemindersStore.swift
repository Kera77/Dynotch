import AppKit
import Combine
import EventKit

/// Apple Reminders through EventKit, shared by the notch and the menu bar panel (spec R-1…R-8).
@MainActor
final class RemindersStore: ObservableObject {
    enum Access: Equatable {
        case notDetermined
        case granted
        case denied
    }

    @Published private(set) var access: Access
    @Published private(set) var lists: [ReminderList] = []
    /// Incomplete reminders of every list.
    @Published private(set) var open: [ReminderItem] = []
    /// Reminders of the selected list completed in the last 7 days.
    @Published private(set) var recentlyCompleted: [ReminderItem] = []
    /// Checked in the UI, saved a moment later (so the tick can be seen).
    @Published private(set) var completing: Set<String> = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var now = Date()

    @Published var selectedListID: String? {
        didSet {
            defaults.set(selectedListID, forKey: Key.list)
            fetchCompleted()
        }
    }
    @Published var sort: ReminderSort {
        didSet { defaults.set(sort.rawValue, forKey: Key.sort) }
    }
    @Published var showCompleted: Bool {
        didSet {
            defaults.set(showCompleted, forKey: Key.showCompleted)
            fetchCompleted()
        }
    }
    /// Quick add: due today when the text names no date.
    @Published var autoToday: Bool {
        didSet { defaults.set(autoToday, forKey: Key.autoToday) }
    }
    /// Quick add: remove the recognised date from the title.
    @Published var removeParsedDate: Bool {
        didSet { defaults.set(removeParsedDate, forKey: Key.removeDate) }
    }

    private enum Key {
        static let list = "remindersList"
        static let sort = "remindersSort"
        static let showCompleted = "remindersShowCompleted"
        static let autoToday = "remindersAutoToday"
        static let removeDate = "remindersRemoveDate"
    }

    private let store = EKEventStore()
    private let defaults: UserDefaults
    private var storeObserver: NSObjectProtocol?
    private var started = false
    private static let completionDelay: Duration = .milliseconds(700)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        access = Self.currentAccess()
        selectedListID = defaults.string(forKey: Key.list)
        sort = defaults.string(forKey: Key.sort).flatMap(ReminderSort.init(rawValue:)) ?? .due
        showCompleted = defaults.bool(forKey: Key.showCompleted)
        autoToday = defaults.bool(forKey: Key.autoToday)
        removeParsedDate = defaults.object(forKey: Key.removeDate) as? Bool ?? true
    }

    // MARK: - Derived

    var selectedList: ReminderList? {
        lists.first { $0.id == selectedListID }
    }

    /// Open reminders of the selected list, sorted.
    var tasks: [ReminderItem] {
        ReminderLogic.sorted(open.filter { $0.listID == selectedListID }, by: sort)
    }

    /// Open reminders due within 7 days (and overdue), from every list.
    var upcoming: [ReminderItem] {
        ReminderLogic.sorted(ReminderLogic.upcoming(open, now: now), by: sort == .title ? .title : .due)
    }

    /// Shown on the menu bar icon (spec R-7).
    var openCount: Int {
        open.filter { $0.listID == selectedListID && !completing.contains($0.id) }.count
    }

    func list(for item: ReminderItem) -> ReminderList? {
        lists.first { $0.id == item.listID }
    }

    // MARK: - Loading

    /// Starts watching Reminders once access is granted; asks for access only when a reminders
    /// view is shown (`activate`).
    func start() {
        guard !started else { return }
        started = true
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        if access == .granted { reload() }
    }

    /// Called whenever a reminders view is shown (notch page, menu bar panel).
    func activate() {
        start()
        switch Self.currentAccess() {
        case .granted:
            reload()
        case .notDetermined:
            access = .notDetermined
            if !hasRequested { requestAccess() }
        case .denied:
            access = .denied
        }
    }

    /// Re-reads the permission, e.g. after it was changed in System Settings.
    func refreshAccess() {
        let current = Self.currentAccess()
        if current == .granted, access != .granted {
            reload()
        } else if current != access {
            access = current
        }
    }

    private var hasRequested = false

    func requestAccess() {
        if Self.currentAccess() == .granted {
            reload()
            return
        }
        hasRequested = true
        NSApp.activate()
        store.requestFullAccessToReminders { [weak self] granted, error in
            let message = "request finished: granted=\(granted) error=\(error.map { "\($0)" } ?? "-")"
            Task { @MainActor in
                guard let self else { return }
                self.log(message)
                if Self.currentAccess() == .granted {
                    self.reload()
                } else {
                    self.access = Self.currentAccess()
                }
            }
        }
    }

    private func reload() {
        now = Date()
        guard Self.currentAccess() == .granted else {
            log("reload skipped: no access")
            return
        }
        if access != .granted {
            // Access arrived after the store was created: it must re-read everything.
            store.reset()
            access = .granted
            log("access granted")
        }
        lists = store.calendars(for: .reminder).map { calendar in
            ReminderList(id: calendar.calendarIdentifier, title: calendar.title, color: Self.color(of: calendar))
        }
        if selectedListID == nil || !lists.contains(where: { $0.id == selectedListID }) {
            selectedListID = store.defaultCalendarForNewReminders()?.calendarIdentifier ?? lists.first?.id
        }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        store.fetchReminders(matching: predicate) { [weak self] reminders in
            let items = (reminders ?? []).map(Self.makeItem)
            Task { @MainActor in self?.open = items }
        }
        fetchCompleted()
    }

    private func fetchCompleted() {
        guard showCompleted, access == .granted,
              let listID = selectedListID, let calendar = store.calendar(withIdentifier: listID)
        else {
            if !recentlyCompleted.isEmpty { recentlyCompleted = [] }
            return
        }
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        let predicate = store.predicateForCompletedReminders(withCompletionDateStarting: start, ending: Date(), calendars: [calendar])
        store.fetchReminders(matching: predicate) { [weak self] reminders in
            let items = (reminders ?? []).map(Self.makeItem)
            Task { @MainActor in self?.recentlyCompleted = items }
        }
    }

    // MARK: - Editing

    /// Ticks a reminder: shown as done at once, saved as completed a moment later (spec R-5).
    func complete(_ item: ReminderItem) {
        guard !item.isCompleted, !completing.contains(item.id) else { return }
        completing.insert(item.id)
        Task { [weak self] in
            try? await Task.sleep(for: Self.completionDelay)
            guard let self, self.completing.contains(item.id) else { return }
            self.setCompleted(item.id, true)
            self.completing.remove(item.id)
        }
    }

    /// Unticks: a pending tick is cancelled, a completed reminder is reopened.
    func uncomplete(_ item: ReminderItem) {
        if completing.remove(item.id) != nil { return }
        if item.isCompleted { setCompleted(item.id, false) }
    }

    /// Creates a reminder from the quick-add text (spec R-3).
    @discardableResult
    func add(_ text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard access == .granted else {
            log("add skipped: access=\(access)")
            return false
        }
        let parsed = ReminderParser.parse(
            text, lists: lists, now: Date(), autoToday: autoToday, removeDate: removeParsedDate
        )
        let reminder = EKReminder(eventStore: store)
        reminder.title = parsed.title
        let listID = parsed.listID ?? selectedListID
        reminder.calendar = listID.flatMap(store.calendar(withIdentifier:)) ?? store.defaultCalendarForNewReminders()
        if let due = parsed.due {
            let components: Set<Calendar.Component> = parsed.dueHasTime
                ? [.year, .month, .day, .hour, .minute]
                : [.year, .month, .day]
            reminder.dueDateComponents = Calendar.current.dateComponents(components, from: due)
        }
        // The list only, never the text.
        let target = reminder.calendar.map { "\($0.calendarIdentifier) writable=\($0.allowsContentModifications)" } ?? "none"
        do {
            try store.save(reminder, commit: true)
            errorMessage = nil
            log("added to \(target)")
            reload()
            return true
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
            log("add to \(target) failed: \(error)")
            return false
        }
    }

    private func setCompleted(_ id: String, _ completed: Bool) {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        reminder.isCompleted = completed
        do {
            try store.save(reminder, commit: true)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
        reload()
    }
}

// MARK: - Helpers

extension RemindersStore {
    func log(_ message: String) {
        DiagnosticsLog.append("reminders", "\(message) status=\(EKEventStore.authorizationStatus(for: .reminder).rawValue)")
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
            NSWorkspace.shared.open(url)
        }
    }

    func openRemindersApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess, .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    nonisolated static func makeItem(_ reminder: EKReminder) -> ReminderItem {
        let components = reminder.dueDateComponents
        let due = components.flatMap { Calendar.current.date(from: $0) }
        return ReminderItem(
            id: reminder.calendarItemIdentifier,
            title: reminder.title?.isEmpty == false ? reminder.title : "(No title)",
            listID: reminder.calendar?.calendarIdentifier ?? "",
            due: due,
            dueHasTime: components?.hour != nil,
            priority: reminder.priority,
            isCompleted: reminder.isCompleted,
            created: reminder.creationDate
        )
    }

    static func color(of calendar: EKCalendar) -> CalendarColor {
        guard let rgb = NSColor(cgColor: calendar.cgColor)?.usingColorSpace(.sRGB) else { return .fallback }
        return CalendarColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
    }

    /// Puts the store into a loaded state without EventKit (tests, previews).
    func setLoadedState(lists: [ReminderList], open: [ReminderItem], selectedListID: String?) {
        self.lists = lists
        self.open = open
        self.selectedListID = selectedListID
        access = .granted
    }
}
