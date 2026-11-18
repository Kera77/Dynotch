import SwiftUI

/// What a column of the Reminders module shows (spec R-15): a smart list as in the Reminders app,
/// or one of the lists.
enum ReminderSource: Equatable, Hashable, Sendable {
    case upcoming
    case today
    case scheduled
    case all
    case list(String)

    static let smart: [ReminderSource] = [.upcoming, .today, .scheduled, .all]

    init?(rawValue: String) {
        switch rawValue {
        case "upcoming": self = .upcoming
        case "today": self = .today
        case "scheduled": self = .scheduled
        case "all": self = .all
        default:
            guard rawValue.hasPrefix("list:") else { return nil }
            self = .list(String(rawValue.dropFirst(5)))
        }
    }

    var rawValue: String {
        switch self {
        case .upcoming: "upcoming"
        case .today: "today"
        case .scheduled: "scheduled"
        case .all: "all"
        case .list(let id): "list:" + id
        }
    }

    var smartTitle: String {
        switch self {
        case .upcoming: "Upcoming"
        case .today: "Today"
        case .scheduled: "Scheduled"
        case .all: "All"
        case .list: "List"
        }
    }

    var symbol: String {
        switch self {
        case .upcoming: "clock"
        case .today: "calendar"
        case .scheduled: "calendar.badge.clock"
        case .all: "tray"
        case .list: "list.bullet"
        }
    }

    /// The open reminders this source shows, before sorting.
    nonisolated func filter(_ items: [ReminderItem], now: Date, calendar: Calendar = .current) -> [ReminderItem] {
        switch self {
        case .upcoming:
            return ReminderLogic.upcoming(items, now: now, calendar: calendar)
        case .today:
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            return items.filter { item in item.due.map { $0 < end } ?? false }
        case .scheduled:
            return items.filter { $0.due != nil }
        case .all:
            return items
        case .list(let id):
            return items.filter { $0.listID == id }
        }
    }
}

extension RemindersStore {
    enum Side { case left, right }

    func source(for side: Side) -> ReminderSource {
        let source = side == .left ? leftSource : rightSource
        // A list that is gone falls back to the selected one.
        if case .list(let id) = source, !lists.contains(where: { $0.id == id }) {
            return selectedListID.map(ReminderSource.list) ?? .all
        }
        return source
    }

    func setSource(_ source: ReminderSource, for side: Side) {
        if side == .left { leftSource = source } else { rightSource = source }
    }

    func title(of source: ReminderSource) -> String {
        if case .list(let id) = source { return lists.first { $0.id == id }?.title ?? "List" }
        return source.smartTitle
    }

    func color(of source: ReminderSource) -> Color {
        switch source {
        case .list(let id): lists.first { $0.id == id }?.color.color ?? RemindersView.blue
        case .upcoming, .today: RemindersView.red
        case .scheduled, .all: RemindersView.blue
        }
    }

    /// Sorted as chosen; Upcoming and Scheduled by due date unless sorted by title.
    func items(for source: ReminderSource) -> [ReminderItem] {
        let found = source.filter(open, now: now)
        switch source {
        case .upcoming, .scheduled: return ReminderLogic.sorted(found, by: sort == .title ? .title : .due)
        default: return ReminderLogic.sorted(found, by: sort)
        }
    }
}

/// One column: its picker and sort in the header, then the reminders; a list also gets "New
/// task" and, on the right, its recently completed tasks (spec R-15, R-6b).
struct ReminderColumn: View {
    @ObservedObject var store: RemindersStore
    let side: RemindersStore.Side

    var body: some View {
        let source = store.source(for: side)
        VStack(alignment: .leading, spacing: 6) {
            header(source)
            let items = store.items(for: source)
            if items.isEmpty, !isList(source) {
                Label("Nothing here", systemImage: "tray")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .padding(.vertical, 4)
            }
            ForEach(items) { item in
                ReminderRow(store: store, item: item, showsList: !isList(source))
            }
            if case .list(let id) = source {
                NewTaskRow(store: store, listID: id)
                completed(listID: id)
            }
        }
    }

    private func isList(_ source: ReminderSource) -> Bool {
        if case .list = source { true } else { false }
    }

    @ViewBuilder
    private func completed(listID: String) -> some View {
        if store.showCompleted, listID == store.selectedListID, !store.recentlyCompleted.isEmpty {
            Text("Completed (7 days)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.top, 6)
            ForEach(store.recentlyCompleted) { item in
                ReminderRow(store: store, item: item, showsList: false)
            }
        }
    }

    private func header(_ source: ReminderSource) -> some View {
        HStack {
            Menu {
                Section("Smart lists") {
                    ForEach(ReminderSource.smart, id: \.self) { smart in
                        Button { store.setSource(smart, for: side) } label: { Label(smart.smartTitle, systemImage: smart.symbol) }
                    }
                }
                Section("Lists") {
                    ForEach(store.lists) { list in
                        Button(list.title) { store.setSource(.list(list.id), for: side) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(store.title(of: source))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(store.color(of: source))
                        .lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.white.opacity(0.5))
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("What this column shows")
            Spacer()
            sortMenu
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $store.sort) {
                ForEach(ReminderSort.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text(store.sort.title)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.7))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sort")
    }
}
