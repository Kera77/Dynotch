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
    /// "3 tasks due today", Open, and the × that hides the counter for a while (spec R-11).
    func tasksLabel(_ count: TaskCount, item: IndicatorItem) -> some View {
        VStack(spacing: 0) {
            tasksHeader(count, item: item)
            // The tasks themselves, checked off with their circle (spec R-12); more than six
            // scroll (spec R-16).
            let tasks = taskItems()
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        TaskDropDownRow(task: task) { completeTask(task) }
                    }
                }
            }
            .scrollIndicators(.never)
            .scrollDisabled(tasks.count <= IndicatorLayout.taskRows)
            .frame(height: CGFloat(min(tasks.count, IndicatorLayout.taskRows)) * IndicatorLayout.taskRowHeight)
            .padding(.bottom, 6)
        }
    }

    private func tasksHeader(_ count: TaskCount, item: IndicatorItem) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "checklist")
                .font(.notch(size: 12, weight: .semibold))
                .foregroundStyle(Theme.blue)
            Text(count.text)
                .font(.notch(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Open", action: openTasks)
                .buttonStyle(.notch)
                .font(.notch(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .frame(height: 18)
                .background(Capsule().fill(Color.white.level(0.16)))
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
