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
    static let blue = Theme.blue

    var body: some View {
        Group {
            switch store.access {
            case .granted:
                content
                    // The info panel over the module (spec R-14).
                    .overlay {
                        if let id = store.editingID {
                            ReminderDetailView(store: store, id: id)
                                .id(id)
                                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        }
                    }
                    .animation(Motion.quick, value: store.editingID)
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
                        ReminderColumn(store: store, side: .left)
                        ReminderColumn(store: store, side: .right)
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
                        // Each column shows what is picked in its header (spec R-15).
                        ScrollView(.vertical) { ReminderColumn(store: store, side: .left) }
                            .scrollIndicators(.never)
                    }
                    .frame(maxWidth: .infinity)
                    ScrollView(.vertical) { ReminderColumn(store: store, side: .right) }
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
            .accessibilityLabel("Open in Reminders")
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

/// Circle checkbox, title and due date (spec R-5).
struct ReminderRow: View {
    @ObservedObject var store: RemindersStore
    let item: ReminderItem
    let showsList: Bool
    @State private var isHovered = false

    private var isChecked: Bool {
        item.isCompleted || store.completing.contains(item.id)
    }

    private var color: Color {
        store.list(for: item)?.color.color ?? RemindersView.blue
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                withAnimation(Motion.quick) {
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
                        DuePill(text: due, urgency: ReminderLogic.urgency(of: item, now: store.now), isDone: isChecked)
                    }
                }
            }
            Spacer(minLength: 0)
            // Like the Reminders app: an "i" on hover opens the details (spec R-14).
            if !item.isCompleted {
                Button {
                    store.editingID = item.id
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.blue)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
                .help("Details")
                .accessibilityLabel("Details")
                .padding(.trailing, 4)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
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
