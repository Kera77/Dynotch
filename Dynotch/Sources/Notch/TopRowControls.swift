import SwiftUI

/// The small controls right of the notch in its top row (spec M-11): their order and which are
/// shown. Settings always stays, or there would be no way back to it.
enum TopRowControl: String, CaseIterable, Identifiable, Sendable {
    case tablet
    case followMouse
    case keyboardLock
    case pin
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tablet: "iPad as a display"
        case .followMouse: "Focus follows the mouse"
        case .keyboardLock: "Keyboard lock"
        case .pin: "Pin the notch open"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .tablet: "ipad.landscape"
        case .followMouse: "arrow.up.square.fill"
        case .keyboardLock: "keyboard.fill"
        case .pin: "lock.fill"
        case .settings: "gearshape.fill"
        }
    }

    var canHide: Bool { self != .settings }
}

/// The order and the hidden controls, kept in the defaults (spec M-11).
@MainActor
@Observable
final class TopRowLayout {
    static let shared = TopRowLayout()

    private(set) var order: [TopRowControl]
    private(set) var hidden: Set<TopRowControl>

    private let defaults: UserDefaults
    private static let orderKey = "topRowOrder"
    private static let hiddenKey = "topRowHidden"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        order = Self.normalized(defaults.stringArray(forKey: Self.orderKey) ?? [])
        hidden = Set((defaults.stringArray(forKey: Self.hiddenKey) ?? []).compactMap(TopRowControl.init(rawValue:)))
            .filter(\.canHide)
    }

    var visible: [TopRowControl] { order.filter { !hidden.contains($0) } }

    func isShown(_ control: TopRowControl) -> Bool { !hidden.contains(control) }

    func setShown(_ control: TopRowControl, _ shown: Bool) {
        guard control.canHide else { return }
        if shown { hidden.remove(control) } else { hidden.insert(control) }
        defaults.set(hidden.map(\.rawValue).sorted(), forKey: Self.hiddenKey)
    }

    /// Moves a control to the place of another one.
    func move(_ control: TopRowControl, to target: TopRowControl) {
        guard control != target, let from = order.firstIndex(of: control), let index = order.firstIndex(of: target) else { return }
        order.remove(at: from)
        order.insert(control, at: index)
        save()
    }

    /// Moves a control among the shown ones to the shown position `index`.
    func move(_ control: TopRowControl, toVisibleIndex index: Int) {
        let shown = visible
        guard shown.indices.contains(index) else { return }
        move(control, to: shown[index])
    }

    private func save() {
        defaults.set(order.map(\.rawValue), forKey: Self.orderKey)
    }

    /// The stored order with unknown names dropped and new controls added at their usual place.
    nonisolated static func normalized(_ stored: [String]) -> [TopRowControl] {
        var result: [TopRowControl] = []
        for name in stored {
            if let control = TopRowControl(rawValue: name), !result.contains(control) { result.append(control) }
        }
        for control in TopRowControl.allCases where !result.contains(control) {
            let after = TopRowControl.allCases.prefix { $0 != control }.last { result.contains($0) }
            let index = after.flatMap { result.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
            result.insert(control, at: index)
        }
        return result
    }
}

/// Settings rows: drag to reorder, switch to show (spec M-11).
struct TopRowSettingsRows: View {
    var layout = TopRowLayout.shared
    @State private var dragged: TopRowControl?

    var body: some View {
        ForEach(layout.order) { control in
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Drag to reorder")
                Toggle(isOn: Binding(get: { layout.isShown(control) }, set: { layout.setShown(control, $0) })) {
                    Label(control.title, systemImage: control.symbol)
                }
                .disabled(!control.canHide)
            }
            .opacity(dragged == control ? 0.4 : 1)
            .onDrag {
                dragged = control
                let binding = $dragged
                ReorderDragEnd.watch { binding.wrappedValue = nil }
                return NSItemProvider(object: control.rawValue as NSString)
            }
            .onDrop(of: [.text], delegate: TopRowDropDelegate(target: control, layout: layout, dragged: $dragged))
        }
    }
}

private struct TopRowDropDelegate: DropDelegate {
    let target: TopRowControl
    let layout: TopRowLayout
    @Binding var dragged: TopRowControl?

    func dropEntered(info: DropInfo) {
        guard let dragged else { return }
        withAnimation(Motion.quick) { layout.move(dragged, to: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        ReorderDragEnd.finish { dragged = nil }
        return true
    }
}
