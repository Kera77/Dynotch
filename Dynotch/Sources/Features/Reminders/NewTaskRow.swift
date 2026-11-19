import SwiftUI

/// "New task" at the end of the selected list's tasks: Enter adds it to that list and leaves the
/// field ready for the next one (spec R-6b). Dates and "@List" are recognised as in quick add.
struct NewTaskRow: View {
    @ObservedObject var store: RemindersStore
    /// The list new tasks go to (spec R-15).
    var listID: String?

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var color: Color {
        (listID.flatMap { id in store.lists.first { $0.id == id } } ?? store.selectedList)?.color.color ?? RemindersView.blue
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.notch(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 17, height: 17)
                .overlay(Circle().stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [2, 2])))
            TextField("New task", text: $text)
                .textFieldStyle(.plain)
                .font(.notch(size: 13, weight: .medium))
                .focused($isFocused)
                .onSubmit(add)
        }
        .padding(.vertical, 3)
        .padding(.leading, 6)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    private func add() {
        guard store.add(text, into: listID) else { return }
        text = ""
        isFocused = true
    }
}

/// The due date as a pill coloured by how near it is (spec R-9).
struct DuePill: View {
    let text: String
    let urgency: DueUrgency?
    var isDone = false

    private var colour: Color {
        guard !isDone else { return .white.level(0.4) }
        switch urgency {
        case .overdue: return Theme.red
        case .today: return .orange
        case .tomorrow: return Theme.blue
        case .later, nil: return .white.level(0.55)
        }
    }

    var body: some View {
        Text(text)
            .font(.notch(size: 10, weight: .semibold))
            .foregroundStyle(colour)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(colour.opacity(0.16)))
    }
}
