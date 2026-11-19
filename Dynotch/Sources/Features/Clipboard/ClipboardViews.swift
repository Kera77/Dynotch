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
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            if tab == .saved {
                TextField("Add a saved text, then Enter", text: $newSaved)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.08)))
                    .onSubmit {
                        store.addSaved(text: newSaved)
                        newSaved = ""
                    }
            }
            ScrollView(.vertical) {
                LazyVStack(spacing: 4) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                        row(item, number: index + 1)
                    }
                }
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
    }

    private func row(_ item: ClipItem, number: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.4))
                .frame(width: 18)
            ClipContent(store: store, item: item, lines: 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                store.toggleSaved(item)
            } label: {
                Image(systemName: store.isSaved(item) ? "star.fill" : "star")
                    .foregroundStyle(store.isSaved(item) ? Color.yellow : Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help(store.isSaved(item) ? "Remove from saved" : "Save")
            Button {
                store.remove(item, from: tab)
            } label: {
                Image(systemName: "trash").foregroundStyle(Color.white.opacity(0.45))
            }
            .buttonStyle(.plain)
            .help("Remove")
            .accessibilityLabel("Remove")
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.07)))
        // A code just copied, opened by the smart opening (spec SO-5).
        .overlay {
            if tab == .history, store.highlighted == item.id {
                RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.blue, lineWidth: 1.5)
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
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            if picker.items.isEmpty {
                Text(picker.tab == .history ? "Nothing copied yet" : "No saved items yet")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.5))
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
                                .font(.system(size: 11))
                                .frame(width: 130, height: 76, alignment: .topLeading)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(index == picker.selection ? 0.22 : 0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(index == picker.selection ? Theme.blue : .clear, lineWidth: 2)
                                )
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(index == picker.selection ? Color.white : Color.white.opacity(0.45))
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
