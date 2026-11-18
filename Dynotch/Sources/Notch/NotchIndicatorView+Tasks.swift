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
                .font(.system(size: 11, weight: .semibold))
            Text("\(count.count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Color.white.opacity(count.isToday ? 0.95 : 0.6))
        .frame(width: width, height: IndicatorLayout.capsuleHeight)
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count.text)
        .accessibilityAddTraits(.isButton)
    }
}

extension NotchIndicatorView {
    /// "3 tasks due today", Open, and the × that hides the counter for a while (spec R-11).
    func tasksLabel(_ count: TaskCount, item: IndicatorItem) -> some View {
        VStack(spacing: 0) {
            tasksHeader(count, item: item)
            // The tasks themselves, checked off with their circle (spec R-12).
            VStack(spacing: 0) {
                ForEach(taskItems().prefix(IndicatorLayout.taskRows)) { task in
                    TaskDropDownRow(task: task) { completeTask(task) }
                }
            }
            .padding(.bottom, 6)
        }
    }

    private func tasksHeader(_ count: TaskCount, item: IndicatorItem) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "checklist")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.blue)
            Text(count.text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Open", action: openTasks)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .frame(height: 18)
                .background(Capsule().fill(Color.white.opacity(0.16)))
            dismissButton(for: item, help: "Hide for a while; it comes back sooner when a task is added")
        }
        .padding(.horizontal, 12)
        .frame(height: IndicatorLayout.labelHeight - 4)
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
                    .font(.system(size: 13))
                    .foregroundStyle(isChecked ? Theme.blue : Color.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Complete")
            .accessibilityLabel("Complete \(task.title)")
            Text(task.title)
                .font(.system(size: 12))
                .foregroundStyle(isChecked ? Color.white.opacity(0.4) : .white)
                .strikethrough(isChecked)
                .lineLimit(1)
            Spacer(minLength: 6)
            if let due = ReminderLogic.dueText(for: task, now: Date()) {
                DuePill(text: due, urgency: ReminderLogic.urgency(of: task, now: Date()), isDone: isChecked)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 22)
    }
}
