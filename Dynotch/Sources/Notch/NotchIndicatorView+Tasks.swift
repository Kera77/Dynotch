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
