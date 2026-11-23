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
        .foregroundStyle(.white)
        .frame(width: width, height: IndicatorLayout.capsuleHeight)
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count.text)
        .accessibilityAddTraits(.isButton)
    }
}

extension NotchIndicatorView {
    /// The counted tasks under their header (spec R-12, R-17).
    @ViewBuilder
    func tasksLabel(_ count: TaskCount, item: IndicatorItem) -> some View {
        if let tasks = taskIndicator {
            TasksDropDown(tasks: tasks, count: count) {
                dismissButton(for: item, help: "Hide for a while; it comes back sooner when a task is added")
            }
        }
    }
}

/// The tasks counter's drop-down: the count, or the lists side by side when the tasks are in
/// several (spec R-17); the chosen list's tasks below, checked off with their circle (spec R-12),
/// more than six scroll (spec R-16). No Open button: a click on the counter opens the module.
struct TasksDropDown<Dismiss: View>: View {
    @ObservedObject var tasks: TaskIndicator
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
