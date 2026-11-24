import AppKit
import Combine
import EventKit

/// Reads events from macOS Calendar (iCloud, Google, Exchange… whatever is configured in
/// System Settings › Internet Accounts) and tracks the upcoming event.
@MainActor
final class CalendarService: ObservableObject {
    enum Access: Equatable {
        case notDetermined
        case granted
        case denied
    }

    @Published private(set) var access: Access
    @Published private(set) var events: [CalendarEvent] = []
    /// Events per day (keyed by start of day), for the dots under the dates.
    @Published private(set) var dayCounts: [Date: Int] = [:]
    /// Events shown beside the closed notch: in progress, or starting soon.
    @Published private(set) var indicatorEvents: [CalendarEvent] = [] {
        didSet { if indicator.events != indicatorEvents { indicator.events = indicatorEvents } }
    }
    /// What the closed notch shows, so it is not redrawn for every tick of the day view (spec N-16).
    let indicator = CalendarIndicator()
    /// A meeting that just entered the lead time: its name stays open below the notch until
    /// swiped away (spec K-8f).
    @Published private(set) var announcement: CalendarEvent? {
        didSet { if indicator.announcement != announcement { indicator.announcement = announcement } }
    }
    /// Meetings already announced, so each is announced once (also across restarts).
    private var announced: Set<String> {
        didSet { UserDefaults.standard.set(Array(announced), forKey: Self.announcedKey) }
    }
    private static let announcedKey = "announcedMeetings"
    @Published private(set) var now = Date()
    /// Day whose events are shown (start of day).
    @Published var selectedDay = Calendar.current.startOfDay(for: Date())

    private let store = EKEventStore()
    private let settings: AppSettings
    private var extraRange: DateInterval?
    private var storeObserver: NSObjectProtocol?
    private var tickTimer: Poller?
    private var lastFetch: Date?
    private var settingsObserver: AnyCancellable?

    private static let dismissedKey = "dismissedCountdowns"
    /// Countdowns hidden with the X (event ids); kept across restarts (spec K-8e).
    private var dismissed: Set<String> {
        didSet { UserDefaults.standard.set(Array(dismissed), forKey: Self.dismissedKey) }
    }

    private static let refetchInterval: TimeInterval = 5 * 60
    private static let tickInterval: TimeInterval = 15
    private static let daysBack = 45
    private static let daysAhead = 120

    init(settings: AppSettings) {
        self.settings = settings
        access = Self.currentAccess()
        dismissed = Set(UserDefaults.standard.stringArray(forKey: Self.dismissedKey) ?? [])
        announced = Set(UserDefaults.standard.stringArray(forKey: Self.announcedKey) ?? [])
    }

    /// How long before an event the indicator appears.
    var leadTime: TimeInterval {
        TimeInterval(settings.calendarLeadMinutes * 60)
    }

    var today: Date {
        Calendar.current.startOfDay(for: now)
    }

    func start() {
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.fetch() }
        }

        // Cheap and on time for the meeting alerts: paused while asleep, not slowed (spec RF-9).
        tickTimer = Poller.start(every: Self.tickInterval, scalesWithPower: false) { [weak self] in self?.tick() }

        settingsObserver = settings.afterChange { [weak self] in self?.recompute() }

        if access == .notDetermined, settings.isEnabled(.calendar) {
            requestAccess()
        } else {
            fetch()
        }
    }

    /// Asks for Calendar access, or opens System Settings if it was denied before.
    func requestAccess() {
        switch Self.currentAccess() {
        case .granted:
            access = .granted
            fetch()
        case .denied:
            openPrivacySettings()
        case .notDetermined:
            NSApp.activate()
            store.requestFullAccessToEvents { [weak self] _, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.access = Self.currentAccess()
                    self.store.reset()
                    self.fetch()
                }
            }
        }
    }

    /// Called when a panel opens: show today and make sure the data is fresh.
    func panelDidOpen() {
        if let lastFetch, Date().timeIntervalSince(lastFetch) < 60 {
            tick()
        } else {
            fetch()
        }
        if selectedDay != today { selectedDay = today }
    }

    /// Makes sure events of the given month are loaded (full calendar navigation).
    func ensureLoaded(month: Date) {
        guard let interval = Calendar.current.dateInterval(of: .month, for: month) else { return }
        let padded = DateInterval(start: interval.start.addingTimeInterval(-7 * 86400), end: interval.end.addingTimeInterval(7 * 86400))
        let loaded = loadedRange()
        guard padded.start < loaded.start || padded.end > loaded.end else { return }
        let start = min(padded.start, extraRange?.start ?? padded.start)
        let end = max(padded.end, extraRange?.end ?? padded.end)
        extraRange = DateInterval(start: start, end: end)
        fetch()
    }

    func events(on day: Date) -> [CalendarEvent] {
        CalendarAgenda.events(on: day, from: events)
    }

    func agenda(startingAt day: Date) -> [AgendaDay] {
        CalendarAgenda.agenda(from: events, startingAt: day)
    }

    /// Announces a meeting when it enters the lead time; drops the announcement when the meeting
    /// is no longer counted down.
    private func updateAnnouncement(now: Date) {
        if let current = announcement, !indicatorEvents.contains(where: { $0.id == current.id }) {
            announcement = nil
        }
        let result = CalendarAgenda.newAnnouncement(in: indicatorEvents, announced: announced, now: now)
        if let event = result.event {
            announcement = event
            RecentNotice.shared.note(.calendar, id: "meeting:" + event.id)
        }
        if result.announced != announced { announced = result.announced }
    }

    /// Two-finger swipe up on the open name (spec K-8f).
    func dismissAnnouncement() {
        announcement = nil
    }

    /// Hides a countdown beside the notch for this event (spec K-8e).
    func dismissIndicator(_ event: CalendarEvent) {
        if announcement?.id == event.id { announcement = nil }
        // Forget ids of events that have ended, so the set stays small.
        let liveIDs = Set(events.filter { !$0.hasEnded(at: now) }.map(\.id))
        dismissed = dismissed.intersection(liveIDs).union([event.id])
        recompute()
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens the meeting in the browser in use, never directly in the meeting app (spec K-6, E-2f).
    func join(_ event: CalendarEvent) {
        guard let url = event.meetingURL else { return }
        ActiveBrowser.shared.open(url)
    }

    // MARK: - Private

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    private func loadedRange() -> DateInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var start = calendar.date(byAdding: .day, value: -Self.daysBack, to: today) ?? today
        var end = calendar.date(byAdding: .day, value: Self.daysAhead, to: today) ?? today
        if let extraRange {
            start = min(start, extraRange.start)
            end = max(end, extraRange.end)
        }
        return DateInterval(start: start, end: end)
    }

    private func fetch() {
        access = Self.currentAccess()
        guard access == .granted else {
            events = []
            dayCounts = [:]
            recompute()
            return
        }

        let range = loadedRange()
        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
        let fetched = store.events(matching: predicate)
            .filter { $0.status != .canceled }
            .map(Self.makeEvent)
        if fetched != events {
            events = fetched
            dayCounts = CalendarAgenda.eventCounts(from: fetched)
        }
        lastFetch = Date()
        recompute()
    }

    private func tick() {
        if let lastFetch, Date().timeIntervalSince(lastFetch) > Self.refetchInterval {
            fetch()
        } else {
            recompute()
        }
    }

    private func recompute() {
        let now = Date()
        self.now = now

        let newIndicatorEvents = settings.calendarAlertEnabled && settings.isEnabled(.calendar)
            ? CalendarAgenda.indicatorEvents(in: events.filter { !dismissed.contains($0.id) }, now: now, leadTime: leadTime)
            : []
        if newIndicatorEvents != indicatorEvents { indicatorEvents = newIndicatorEvents }
        updateAnnouncement(now: now)
    }

    private static func makeEvent(_ event: EKEvent) -> CalendarEvent {
        CalendarEvent(
            id: "\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)",
            title: event.title?.isEmpty == false ? event.title : "(No title)",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            color: color(of: event.calendar),
            meetingURL: MeetingLink.find(url: event.url, texts: [event.location, event.notes])
        )
    }

    private static func color(of calendar: EKCalendar?) -> CalendarColor {
        guard let cgColor = calendar?.cgColor,
              let rgb = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB)
        else { return .fallback }
        return CalendarColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
    }
}

/// The meetings beside the closed notch and the announced one: all the notch watches of the calendar.
@MainActor
final class CalendarIndicator: ObservableObject {
    @Published fileprivate(set) var events: [CalendarEvent] = []
    @Published fileprivate(set) var announcement: CalendarEvent?
}
