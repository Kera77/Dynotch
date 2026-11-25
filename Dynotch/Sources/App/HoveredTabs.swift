import Foundation

/// The tab picker under the pointer (spec S-6): every `CapsulePicker` reports its hover here, so a
/// swipe over any module's tab row steps its tabs without per-module code.
@MainActor
final class HoveredTabs {
    static let shared = HoveredTabs()

    private var owner: UUID?
    private var stepper: ((Int) -> Bool)?

    /// The picker `id` is under the pointer; `step` moves its selection, false at either end.
    func enter(_ id: UUID, step: @escaping (Int) -> Bool) {
        owner = id
        stepper = step
    }

    /// The pointer left the picker, or the picker went away.
    func leave(_ id: UUID) {
        guard owner == id else { return }
        owner = nil
        stepper = nil
    }

    /// Steps the hovered picker by `offset`; false when none is hovered or it is at its end.
    func step(by offset: Int) -> Bool {
        stepper?(offset) ?? false
    }
}
