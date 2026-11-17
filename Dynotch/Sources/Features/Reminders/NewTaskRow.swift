import SwiftUI

/// "New task" at the end of the selected list's tasks: Enter adds it to that list and leaves the
/// field ready for the next one (spec R-6b). Dates and "@List" are recognised as in quick add.
struct NewTaskRow: View {
    @ObservedObject var store: RemindersStore

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var color: Color {
        store.selectedList?.color.color ?? RemindersView.blue
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 17, height: 17)
                .overlay(Circle().stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [2, 2])))
            TextField("New task", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .focused($isFocused)
                .onSubmit(add)
        }
        .padding(.vertical, 3)
        .padding(.leading, 6)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    private func add() {
        guard store.add(text) else { return }
        text = ""
        isFocused = true
    }
}
