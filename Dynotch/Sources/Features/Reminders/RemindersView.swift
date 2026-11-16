import SwiftUI

/// Reminders: quick add, upcoming reminders and the selected list's tasks (spec R-2…R-6).
struct RemindersView: View {
    enum Layout {
        /// One column (menu bar panel).
        case column
        /// Add field and upcoming on the left, tasks on the right (notch).
        case split
    }

    @ObservedObject var store: RemindersStore
    let layout: Layout
    let isActive: Bool
    var pin: PinControl?

    static let red = Color(red: 1, green: 0.27, blue: 0.27)
    static let blue = Color(red: 0.04, green: 0.52, blue: 1)

    var body: some View {
        Group {
            switch store.access {
            case .granted:
                content
            case .notDetermined:
                prompt(
                    "Dynotch needs access to your reminders.",
                    button: "Allow Access",
                    action: store.requestAccess
                )
            case .denied:
                prompt(
                    "No access to reminders.\nPrivacy & Security › Reminders › Dynotch",
                    button: "Open System Settings",
                    action: store.openPrivacySettings
                )
            }
        }
        .onAppear { if isActive { store.activate() } }
        .onChange(of: isActive) { _, active in
            if active { store.activate() }
        }
        // Notices a permission granted in System Settings while the view is open.
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            if isActive, store.access != .granted { store.refreshAccess() }
        }
    }

    @ViewBuilder private var content: some View {
        switch layout {
        case .column:
            VStack(alignment: .leading, spacing: 12) {
                QuickAddField(store: store)
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 14) {
                        UpcomingSection(store: store)
                        TasksSection(store: store)
                    }
                }
                .scrollIndicators(.never)
                bottomBar
            }
        case .split:
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        QuickAddField(store: store)
                        ScrollView(.vertical) { UpcomingSection(store: store) }
                            .scrollIndicators(.never)
                    }
                    .frame(maxWidth: .infinity)
                    ScrollView(.vertical) { TasksSection(store: store) }
                        .scrollIndicators(.never)
                        .frame(maxWidth: .infinity)
                }
                bottomBar
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                store.showCompleted.toggle()
            } label: {
                Image(systemName: store.showCompleted ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(store.showCompleted ? Self.blue : Color.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help(store.showCompleted ? "Hide completed" : "Show tasks completed in the last 7 days")

            Spacer()
            Text(store.errorMessage ?? "\(store.openCount) open")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(store.errorMessage == nil ? Color.white.opacity(0.5) : Self.red)
                .lineLimit(1)
            Spacer()

            if let pin {
                PinButton(isPinned: pin.isPinned, action: pin.toggle)
                    .frame(width: 30, height: 26)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.14)))
            }
            Button(action: store.openRemindersApp) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Open in Reminders")
        }
    }

    private func prompt(_ text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(button, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// "Type a reminder and hit enter" field with the list and option menu (spec R-3, R-4).
private struct QuickAddField: View {
    @ObservedObject var store: RemindersStore
    @State private var text = ""

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.4))
                TextField("Type a reminder and hit enter", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        if store.add(text) { text = "" }
                    }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.1)))

            Menu {
                ForEach(store.lists) { list in
                    Button {
                        store.selectedListID = list.id
                    } label: {
                        if list.id == store.selectedListID {
                            Label(list.title, systemImage: "checkmark")
                        } else {
                            Text(list.title)
                        }
                    }
                }
                Divider()
                Toggle("Auto suggest today as date", isOn: $store.autoToday)
                Toggle("Remove parsed date from title", isOn: $store.removeParsedDate)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(RemindersView.blue))
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Lists and options. Type \"@List\" to pick a list; dates like \"tomorrow 2pm\" are recognised.")
        }
    }
}

private struct UpcomingSection: View {
    @ObservedObject var store: RemindersStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Upcoming reminders")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(RemindersView.red)
                Spacer()
                Menu {
                    Picker("Sort", selection: $store.sort) {
                        ForEach(ReminderSort.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(store.sort.title)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            let upcoming = store.upcoming
            if upcoming.isEmpty {
                Label("No upcoming reminders", systemImage: "tray")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .padding(.vertical, 4)
            } else {
                ForEach(upcoming) { item in
                    ReminderRow(store: store, item: item, showsList: true)
                }
            }
        }
    }
}

private struct TasksSection: View {
    @ObservedObject var store: RemindersStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(store.selectedList?.title ?? "Tasks")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(store.selectedList?.color.color ?? RemindersView.blue)
                Spacer()
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            let tasks = store.tasks
            if tasks.isEmpty {
                Text("No open tasks")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.vertical, 4)
            }
            ForEach(tasks) { item in
                ReminderRow(store: store, item: item, showsList: false)
            }
            if store.showCompleted, !store.recentlyCompleted.isEmpty {
                Text("Completed (7 days)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.top, 6)
                ForEach(store.recentlyCompleted) { item in
                    ReminderRow(store: store, item: item, showsList: false)
                }
            }
        }
    }
}

/// Circle checkbox, title and due date (spec R-5).
private struct ReminderRow: View {
    @ObservedObject var store: RemindersStore
    let item: ReminderItem
    let showsList: Bool

    private var isChecked: Bool {
        item.isCompleted || store.completing.contains(item.id)
    }

    private var color: Color {
        store.list(for: item)?.color.color ?? RemindersView.blue
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    if isChecked { store.uncomplete(item) } else { store.complete(item) }
                }
            } label: {
                ZStack {
                    Circle().stroke(color.opacity(isChecked ? 1 : 0.85), lineWidth: 1.5)
                    if isChecked {
                        Circle().fill(color).padding(3)
                    }
                }
                .frame(width: 17, height: 17)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(isChecked ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isChecked ? Color.white.opacity(0.45) : .white)
                    .strikethrough(isChecked)
                    .lineLimit(2)
                if let due = ReminderLogic.dueText(for: item, now: store.now) {
                    HStack(spacing: 4) {
                        if showsList {
                            Circle().fill(color).frame(width: 5, height: 5)
                        }
                        Text(due)
                            .font(.system(size: 11))
                            .foregroundStyle(item.isOverdue(at: store.now) ? RemindersView.red : Color.white.opacity(0.5))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        // Room left of the circle, so it does not touch the edge (spec R-6).
        .padding(.leading, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.leading, 31)
        }
    }
}

/// Reminders feature in the notch.
struct RemindersFeatureView: View {
    @ObservedObject var store: RemindersStore
    let isActive: Bool

    var body: some View {
        RemindersView(store: store, layout: .split, isActive: isActive)
            .padding(.top, 6)
    }
}

/// Content of the reminders menu bar panel.
struct RemindersMenuBarView: View {
    @ObservedObject var store: RemindersStore
    @ObservedObject var state: MenuBarPanelState

    var body: some View {
        RemindersView(
            store: store,
            layout: .column,
            isActive: true,
            pin: PinControl(isPinned: state.isPinned) { state.isPinned.toggle() }
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .popoverChrome(arrowX: state.arrowX)
    }
}
