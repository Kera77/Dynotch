import SwiftUI

/// The clipboard module in the notch (spec CB-4): the copies or the saved items, searchable;
/// a click pastes into the app in front, the star saves, the bin removes.
struct ClipboardFeatureView: View {
    @ObservedObject var store: ClipboardStore
    /// Closes the notch before pasting, so the app in front gets the keys.
    let close: () -> Void

    @State private var tab = ClipboardTab.history
    @State private var search = ""
    @State private var newSaved = ""
    /// Reordering the saved items (spec CB-8): the dragged row, where it was grabbed, the pointer.
    @State private var dragged: ClipItem.ID?
    @State private var grab: CGFloat = 0
    @State private var pointerY: CGFloat = 0
    /// Each row's height: the places are worked out from the order, never from frames measured a
    /// moment late, which made the row jump back and forth (spec CB-9).
    @State private var rowHeights: [ClipItem.ID: CGFloat] = [:]
    /// False once the drag ends or is cancelled: the row goes back in place (spec CB-9).
    @GestureState private var isDragging = false
    private static let rowSpacing: CGFloat = 4
    private static let listSpace = "ClipboardList"

    /// The saved items can be reordered, not while searching.
    private var canReorder: Bool { tab == .saved && search.isEmpty && store.saved.count > 1 }

    private var shown: [ClipItem] {
        let items = store.items(in: tab)
        guard !search.isEmpty else { return items }
        return items.filter { $0.text.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ClipboardTabs(selected: tab) { tab = $0 }
                SettingsSearchField(text: $search, prompt: "Search")
                    .frame(maxWidth: 220)
                Spacer(minLength: 0)
                if tab == .history, !store.history.isEmpty {
                    Button("Clear") { store.clearHistory() }
                        .buttonStyle(.notch)
                        .font(.notch(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.level(0.6))
                }
            }
            if tab == .saved {
                TextField("Add a saved text, then Enter", text: $newSaved)
                    .textFieldStyle(.plain)
                    .font(.notch(size: 12))
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(RoundedRectangle(cornerRadius: AppleStyle.corner(7), style: .continuous).fill(Color.white.level(0.08)))
                    .onSubmit {
                        store.addSaved(text: newSaved)
                        newSaved = ""
                    }
            }
            ScrollView(.vertical) {
                LazyVStack(spacing: Self.rowSpacing) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                        row(item, number: index + 1)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                                rowHeights[item.id] = $0
                            }
                            .offset(y: dragged == item.id ? dragOffset(item.id) : 0)
                            // The dragged row stays on the pointer; only the others slide.
                            .transaction { if dragged == item.id { $0.animation = nil } }
                            .zIndex(dragged == item.id ? 1 : 0)
                            .simultaneousGesture(reorder(item), isEnabled: canReorder)
                    }
                }
                .coordinateSpace(name: Self.listSpace)
            }
            .scrollIndicators(.never)
            .overlay {
                if shown.isEmpty {
                    EmptyStateView(
                        symbol: tab == .history ? "doc.on.clipboard" : "star",
                        text: tab == .history ? "Copied texts and images appear here." : "Save items with the star, or add a text above."
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .onChange(of: isDragging) { _, dragging in
            if !dragging, dragged != nil { withAnimation(Motion.quick) { dragged = nil } }
        }
    }

    /// The middle of each saved row in the list, from the order and the heights (spec CB-9).
    private var savedMiddles: [ClipItem.ID: CGFloat] {
        var middles: [ClipItem.ID: CGFloat] = [:]
        var top: CGFloat = 0
        for item in store.saved {
            let height = rowHeights[item.id] ?? 0
            middles[item.id] = top + height / 2
            top += height + Self.rowSpacing
        }
        return middles
    }

    /// The dragged row follows the pointer from where it now stands in the list.
    private func dragOffset(_ id: ClipItem.ID) -> CGFloat {
        guard let middle = savedMiddles[id] else { return 0 }
        return pointerY - grab - middle
    }

    /// Dragging a saved row moves it past the rows its middle crosses (spec CB-8).
    private func reorder(_ item: ClipItem) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.listSpace))
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                let middles = savedMiddles
                if dragged == nil {
                    grab = value.startLocation.y - (middles[item.id] ?? value.startLocation.y)
                    pointerY = value.location.y
                    dragged = item.id
                }
                guard dragged == item.id else { return }
                pointerY = value.location.y
                let middle = pointerY - grab
                let saved = store.saved
                guard let from = saved.firstIndex(where: { $0.id == item.id }) else { return }
                // The row whose middle the dragged one has passed, the nearest first.
                let passed = saved.indices.filter { index in
                    guard index != from, let other = middles[saved[index].id] else { return false }
                    return index > from ? middle > other : middle < other
                }
                if let target = from < (passed.max() ?? from) ? passed.max() : passed.min(), target != from {
                    withAnimation(Motion.quick) { store.moveSaved(item.id, to: target) }
                }
            }
            .onEnded { _ in
                withAnimation(Motion.quick) { dragged = nil }
            }
    }

    private func row(_ item: ClipItem, number: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.notch(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.white.level(0.4))
                .frame(width: 18)
            ClipContent(store: store, item: item, lines: 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                store.toggleSaved(item)
            } label: {
                Image(systemName: store.isSaved(item) ? "star.fill" : "star")
                    .foregroundStyle(store.isSaved(item) ? Color.yellow : Color.white.level(0.5))
            }
            .buttonStyle(.notch)
            .help(store.isSaved(item) ? "Remove from saved" : "Save")
            Button {
                store.remove(item, from: tab)
            } label: {
                Image(systemName: "xmark").foregroundStyle(Color.white.level(0.45))
            }
            .buttonStyle(.notch)
            .help("Remove")
            .accessibilityLabel("Remove")
        }
        .font(.notch(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous).fill(Color.white.level(0.07)))
        // A code just copied, opened by the smart opening (spec SO-5).
        .overlay {
            if tab == .history, store.highlighted == item.id {
                RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous).strokeBorder(Theme.blue, lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            close()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { store.paste(item) }
        }
        .help("Click to paste")
        .accessibilityLabel("Click to paste")
    }
}

/// "Clipboard | Saved" chips.
struct ClipboardTabs: View {
    let selected: ClipboardTab
    let select: (ClipboardTab) -> Void

    var body: some View {
        CapsulePicker(items: ClipboardTab.allCases, selection: Binding(get: { selected }, set: select), title: \.title)
    }
}

/// A text (a few lines) or an image's thumbnail.
struct ClipContent: View {
    let store: ClipboardStore
    let item: ClipItem
    let lines: Int

    var body: some View {
        if item.kind == .image, let image = store.image(of: item) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: lines > 2 ? 70 : 40, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: AppleStyle.corner(4), style: .continuous))
        } else {
            Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                .foregroundStyle(.white)
                .lineLimit(lines)
        }
    }
}

/// Shown while the clipboard shortcut is held (spec CB-3): the items side by side with their
/// numbers below; the chosen one is highlighted.
struct ClipboardPickerView: View {
    @ObservedObject var picker: ClipboardPicker
    @ObservedObject var store: ClipboardStore
    let notchHeight: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            Color.clear.frame(height: notchHeight)
            HStack {
                ClipboardTabs(selected: picker.tab) { _ in }
                Spacer()
                Text("←→ choose · ↑↓ \(picker.tab == .history ? "saved" : "clipboard") · release to paste · esc cancels")
                    .font(.notch(size: 10))
                    .foregroundStyle(Color.white.level(0.5))
            }
            .padding(.horizontal, 16)
            if picker.items.isEmpty {
                Text(picker.tab == .history ? "Nothing copied yet" : "No saved items yet")
                    .font(.notch(size: 12))
                    .foregroundStyle(Color.white.level(0.5))
                    .frame(maxHeight: .infinity)
            } else {
                cards
            }
        }
        .padding(.bottom, 10)
    }

    private var cards: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(picker.items.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: 5) {
                            ClipContent(store: store, item: item, lines: 4)
                                .font(.notch(size: 11))
                                .frame(width: 130, height: 76, alignment: .topLeading)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: AppleStyle.corner(10), style: .continuous)
                                        .fill(Color.white.level(index == picker.selection ? 0.22 : 0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppleStyle.corner(10), style: .continuous)
                                        .stroke(index == picker.selection ? Theme.blue : .clear, lineWidth: 2)
                                )
                            Text("\(index + 1)")
                                .font(.notch(size: 11, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(index == picker.selection ? Color.white : Color.white.level(0.45))
                        }
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.never)
            .onChange(of: picker.selection) { _, index in
                guard picker.items.indices.contains(index) else { return }
                withAnimation(Motion.quick) { proxy.scrollTo(picker.items[index].id, anchor: .center) }
            }
        }
    }
}
