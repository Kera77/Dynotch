import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A long list in the settings: closed until its header row is clicked, then a search field that
/// filters only this list (spec SD-2).
struct CollapsibleListSection<Content: View>: View {
    let title: String
    let count: Int
    var prompt = "Search"
    var footer: String?
    @ViewBuilder let content: (String) -> Content

    @State private var isOpen = false
    @State private var search = ""

    var body: some View {
        Section {
            // The rows appear at once: animating hundreds of them made opening slow; only the
            // chevron turns (spec SD-17).
            Button {
                isOpen.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .animation(Motion.quick, value: isOpen)
                        .frame(width: 14)
                    Text(title).fontWeight(.medium)
                    Spacer()
                    Text("\(count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isOpen ? "Close \(title)" : "Open \(title)")
            if isOpen {
                SettingsSearchField(text: $search, prompt: prompt)
                content(search)
            }
        } footer: {
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// App icons for the settings' lists, each read from disk once (spec SD-17).
@MainActor
enum SettingsAppIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(forFile path: String) -> NSImage {
        if let icon = cache[path] { return icon }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 36, height: 36)
        cache[path] = icon
        return icon
    }
}

/// Whether a name or its detail matches a list's search (spec SD-2).
func settingsSearchMatches(_ search: String, _ texts: String?...) -> Bool {
    search.isEmpty || texts.contains { $0?.localizedCaseInsensitiveContains(search) ?? false }
}

/// The same label on every app, website and module row: an 18 pt icon, the name and a grey
/// detail (spec SD-3).
struct SettingsRowLabel<Icon: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        HStack(spacing: 8) {
            icon().frame(width: 18, height: 18)
            Text(title)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A fixed-width place after a row's switch, there even when empty, so the switches of a list
/// stand in one column (spec SD-10).
struct TrailingSlot<Content: View>: View {
    var width: CGFloat = 20
    @ViewBuilder let content: () -> Content

    var body: some View {
        content().frame(width: width, height: 20)
    }
}

/// The handle at the start of a row that can be dragged to reorder (spec SD-4).
struct DragHandle: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .help("Drag to reorder")
            .accessibilityLabel("Drag to reorder")
    }
}

/// Moves the dragged row over the one under the pointer, as it is dragged (spec SD-4).
@MainActor
struct ReorderDropDelegate<Item: Equatable>: DropDelegate {
    let target: Item
    let items: [Item]
    @Binding var dragged: Item?
    let move: (IndexSet, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged, dragged != target,
              let from = items.firstIndex(of: dragged),
              let targetIndex = items.firstIndex(of: target)
        else { return }
        withAnimation(Motion.quick) {
            move(IndexSet(integer: from), targetIndex > from ? targetIndex + 1 : targetIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        ReorderDragEnd.finish { dragged = nil }
        return true
    }
}

/// Takes a reorder drag let go between rows as a move, not a copy (spec M-16).
struct MoveDropDelegate: DropDelegate {
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { true }
}

/// Ends a row drag once the mouse button is up, wherever it was let go: dropped between rows or
/// outside the list no drop delegate hears it, and the row stayed grey (spec SD-14).
@MainActor
enum ReorderDragEnd {
    private static var task: Task<Void, Never>?

    /// Called when a drag starts; `end` clears the dragged row.
    static func watch(_ end: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            while !Task.isCancelled, NSEvent.pressedMouseButtons & 1 != 0 {
                try? await Task.sleep(for: .milliseconds(40))
            }
            guard !Task.isCancelled else { return }
            finish(end)
        }
    }

    /// Clears the dragged row at once, without the fade that looked like a second animation.
    static func finish(_ end: @MainActor () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { end() }
    }
}

extension View {
    /// Takes a reorder drag let go anywhere in the settings, so the dragged image does not fly
    /// back to where it started (spec SD-14).
    /// Taken as a move, so no green "+" shows beside the pointer (spec M-16).
    func acceptsReorderDrops() -> some View {
        onDrop(of: [.text], delegate: MoveDropDelegate())
    }

    /// A row that can be dragged over the others of `items` to reorder them (spec SD-4).
    func reorderable<Item: Equatable>(
        _ item: Item, in items: [Item], dragged: Binding<Item?>, id: String, move: @escaping (IndexSet, Int) -> Void
    ) -> some View {
        opacity(dragged.wrappedValue == item ? 0.4 : 1)
            .onDrag {
                dragged.wrappedValue = item
                ReorderDragEnd.watch { dragged.wrappedValue = nil }
                return NSItemProvider(object: id as NSString)
            }
            .onDrop(of: [.text], delegate: ReorderDropDelegate(target: item, items: items, dragged: dragged, move: move))
    }
}

/// The first section of a page that needs permissions: one row each, as on the Permissions page
/// (spec SD-8, C-8).
struct AccessSection: View {
    let permissions: [Permission]
    /// Full Disk Access is known from the notifications being readable.
    var notificationsReadable = false
    var footer: String?
    /// A module's own way of asking, where it must hear the answer itself.
    var grants: [Permission: @MainActor () -> Void] = [:]

    @State private var refresh = 0

    var body: some View {
        Section {
            ForEach(permissions) { permission in
                LabeledContent {
                    status(permission)
                } label: {
                    SettingsRowLabel(title: permission.title) {
                        Image(systemName: permission.symbol).foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Access")
        } footer: {
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .id(refresh)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in refresh += 1 }
    }

    @ViewBuilder private func status(_ permission: Permission) -> some View {
        if permission.isGranted(notificationsReadable: notificationsReadable) == true {
            Label("Allowed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .labelStyle(.titleAndIcon)
        } else {
            Button("Grant…") {
                if let grant = grants[permission] { return grant() }
                let readable = notificationsReadable
                Task { await permission.grant(notificationsReadable: readable) }
            }
        }
    }
}

/// A slider with its value beside it, the same width on every page (spec SD-9).
struct SettingsSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    let text: (Double) -> String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                if let step {
                    Slider(value: $value, in: range, step: step).frame(width: 160)
                } else {
                    Slider(value: $value, in: range).frame(width: 160)
                }
                Text(text(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }
}
