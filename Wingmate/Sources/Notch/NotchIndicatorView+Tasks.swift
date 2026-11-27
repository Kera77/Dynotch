import SwiftUI

/// The tasks counter right of the notch: the menu bar's checklist icon and the count, smaller
/// (spec R-10). A click opens the Reminders module.
struct TasksCounter: View {
    let count: TaskCount
    let width: CGFloat
    let open: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "checklist")
                .font(.notch(size: 11, weight: .semibold))
            Text("\(count.count)").numericTransition()
                .font(.notch(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Self.color(for: count.tone))
        .frame(width: width, height: IndicatorLayout.capsuleHeight)
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count.text)
        .accessibilityAddTraits(.isButton)
    }

    /// Red with an overdue task, orange within the hour before one is due (spec R-27).
    static func color(for tone: TaskTone) -> Color {
        switch tone {
        case .normal: .white
        case .soon: .orange
        case .overdue: Theme.red
        }
    }
}

extension NotchIndicatorView {
    /// The counted tasks under their header (spec R-12, R-17); without hover the overdue ones in
    /// thin rows (spec R-26).
    @ViewBuilder
    func tasksLabel(_ count: TaskCount, item: IndicatorItem) -> some View {
        if !showsTaskList, !count.overdue.isEmpty {
            OverdueTaskRows(tasks: count.overdue)
        } else if let tasks = taskIndicator {
            TasksDropDown(tasks: tasks, count: count) {
                HStack(spacing: 8) {
                    OpenModuleButton(help: "Open Tasks", action: openTasks)
                    dismissButton(for: item, help: "Hide for a while; it comes back sooner when a task is added")
                }
            }
        }
    }
}

/// The tasks counter's drop-down: the count, or the lists side by side when the tasks are in
/// several (spec R-17); the chosen list's tasks below, checked off with their circle (spec R-12),
/// more than six scroll (spec R-16). No text Open button, only the small icon (spec R-20).
struct TasksDropDown<Dismiss: View>: View {
    var tasks: TaskIndicator
    let count: TaskCount
    @ViewBuilder let dismiss: () -> Dismiss

    var body: some View {
        let groups = tasks.groups
        let selected = tasks.selectedGroup
        let items = groups.count > 1 ? selected?.items ?? [] : tasks.listed
        VStack(spacing: 0) {
            header(groups: groups, selected: selected)
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(items) { task in
                        TaskDropDownRow(task: task) { tasks.complete(task) }
                            .overdueActions(tasks.isOverdueNotice(task) ? tasks : nil, task: task)
                    }
                }
            }
            .scrollIndicators(.never)
            .scrollDisabled(items.count <= IndicatorLayout.taskRows)
            .frame(height: CGFloat(min(items.count, IndicatorLayout.taskRows)) * IndicatorLayout.taskRowHeight)
            .padding(.bottom, 6)
        }
        // The choice lasts until the drop-down closes; next time the soonest list comes first.
        .onDisappear { tasks.chosenListID = nil }
    }

    private func header(groups: [TaskGroup], selected: TaskGroup?) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "checklist")
                .font(.notch(size: 12, weight: .semibold))
                .foregroundStyle(Theme.blue)
            if groups.count > 1, let selected {
                let titles = Dictionary(groups.map { ($0.listID, "\($0.title) \($0.items.count)") }) { first, _ in first }
                CapsulePicker(
                    items: groups.map(\.listID),
                    selection: Binding(get: { selected.listID }, set: { tasks.chosenListID = $0 }),
                    title: { titles[$0] ?? "" }
                )
                .fixedSize()
            } else {
                Text(count.text)
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            dismiss()
        }
        .padding(.horizontal, 12)
        .frame(height: IndicatorLayout.labelHeight - 4 + (groups.count > 1 ? IndicatorLayout.taskPickerExtra : 0))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The drop-down's one open button: a square with an arrow, sized and dimmed like the ×,
/// brightening on hover (spec R-20).
struct OpenModuleButton: View {
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.forward.square")
                .font(.notch(size: 13, weight: .medium))
                .foregroundStyle(Color.white.level(isHovered ? 0.9 : 0.55))
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// The overdue tasks under the closed notch in one thin row: the oldest one, and "+N" for the
/// rest (spec R-26, R-28). Hovering it drops the tasks' list down in its place.
struct OverdueTaskRows: View {
    let tasks: [ReminderItem]

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle")
                .font(.notch(size: 13))
                .foregroundStyle(Theme.red)
            Text(tasks.first?.title ?? "")
                .font(.notch(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 6)
            if let task = tasks.first, let due = ReminderLogic.dueText(for: task, now: Date()) {
                Text("Overdue · \(due)")
                    .font(.notch(size: 11))
                    .foregroundStyle(Theme.red)
                    .lineLimit(1)
                    .fixedSize()
            }
            if tasks.count > 1 {
                Text("+\(tasks.count - 1)")
                    .font(.notch(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .frame(height: 16)
                    .background(Capsule().fill(Theme.red.opacity(0.35)))
                    .fixedSize()
            }
        }
        .padding(.horizontal, 14)
        .frame(height: IndicatorLayout.overdueRowHeight)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tasks.count) overdue task\(tasks.count == 1 ? "" : "s")")
    }
}

private extension View {
    /// Later and X on an overdue task's row in the drop-down (spec R-26).
    @ViewBuilder
    func overdueActions(_ tasks: TaskIndicator?, task: ReminderItem) -> some View {
        if let tasks {
            HStack(spacing: 0) {
                self
                OverdueTaskButtons(task: task, tasks: tasks)
                    .padding(.trailing, 12)
            }
        } else {
            self
        }
    }
}

/// Later (back in an hour) and X (gone until its due date changes) on an overdue task (spec R-26).
private struct OverdueTaskButtons: View {
    let task: ReminderItem
    let tasks: TaskIndicator

    var body: some View {
        HStack(spacing: 8) {
            Button { withAnimation(Motion.quick) { tasks.remindLater(task) } } label: {
                Image(systemName: "clock")
                    .font(.notch(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.level(0.6))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.notch)
            .help("Remind me in an hour")
            .accessibilityLabel("Later")
            Button { withAnimation(Motion.quick) { tasks.dismissOverdue(task) } } label: {
                Image(systemName: "xmark")
                    .font(.notch(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.level(0.55))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.notch)
            .help("Don't show this overdue task under the notch")
            .accessibilityLabel("Dismiss")
        }
    }
}

/// One task in the counter's drop-down: its circle checks it off.
struct TaskDropDownRow: View {
    let task: ReminderItem
    let complete: () -> Void

    @State private var isChecked = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                isChecked = true
                complete()
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.notch(size: 13))
                    .foregroundStyle(isChecked ? Theme.blue : Color.white.level(0.6))
            }
            .buttonStyle(.notch)
            .help("Complete")
            .accessibilityLabel("Complete \(task.title)")
            Text(task.title)
                .font(.notch(size: 12))
                .foregroundStyle(isChecked ? Color.white.level(0.4) : .white)
                .strikethrough(isChecked)
                .lineLimit(1)
            Spacer(minLength: 6)
            if let due = ReminderLogic.dueText(for: task, now: Date()) {
                DuePill(text: due, urgency: ReminderLogic.urgency(of: task, now: Date()), isDone: isChecked)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: IndicatorLayout.taskRowHeight)
    }
}
