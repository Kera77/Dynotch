import Carbon.HIToolbox
import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// Behaviours added in 0.29.
@MainActor
struct V029Tests {
    private func makeDefaults() -> UserDefaults {
        let name = "V029Tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// Spec SC-2: without a shortcut the Pin box is shown unticked and does nothing.
    @Test func pinNeedsAShortcut() throws {
        let store = ShortcutStore(defaults: makeDefaults())
        store.setPins(.notes, true)
        #expect(store.pins(.notes))
        #expect(!store.pinsWhenOpened(.notes))
        let shortcut = try #require(KeyShortcut.make(keyCode: UInt16(kVK_ANSI_1), flags: [.option], characters: "1"))
        store.set(shortcut, for: .notes)
        #expect(store.pinsWhenOpened(.notes))
        store.set(nil, for: .notes)
        #expect(!store.pinsWhenOpened(.notes))
    }

    /// Spec M-3: dragging a row in the Modules tab moves it.
    @Test func modulesMoveByDragging() {
        let settings = AppSettings(defaults: makeDefaults())
        let order = settings.featureOrder
        // Down: the dragged row lands after the target.
        settings.moveFeatures(from: IndexSet(integer: 0), to: 3)
        #expect(settings.featureOrder[2] == order[0])
        // Up: the dragged row lands on the target's place.
        settings.moveFeatures(from: IndexSet(integer: 2), to: 0)
        #expect(settings.featureOrder == order)
    }

    /// Spec N-8: the Space switch draws everything into the notch and lets it unfold again.
    @Test func gatheringIsOnlyAState() {
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663, auxiliaryRightWidth: 664, menuBarHeight: 32
        )
        let model = NotchViewModel(settings: AppSettings(defaults: makeDefaults()), geometry: geometry, screenName: "Test")
        #expect(!model.isGathered)
        model.setGathered(true)
        #expect(model.isGathered)
        model.setGathered(false)
        #expect(!model.isGathered)
        #expect(NotchController.gatherTimeout > 1)
    }

    /// Spec N-10: only the left/right dock swipe counts, with its phases.
    @Test func theSpaceSwipeIsRecognised() {
        #expect(SpaceSwipe.isSpaceSwipe(type: 30, hidType: 23, motion: 1))
        // Up and down are Mission Control and App Exposé.
        #expect(!SpaceSwipe.isSpaceSwipe(type: 30, hidType: 23, motion: 2))
        #expect(!SpaceSwipe.isSpaceSwipe(type: 29, hidType: 23, motion: 1))
        #expect(!SpaceSwipe.isSpaceSwipe(type: 30, hidType: 6, motion: 1))
        #expect(SpaceSwipe.phase(fromRaw: 1) == .began)
        #expect(SpaceSwipe.phase(fromRaw: 2) == .changed)
        #expect(SpaceSwipe.phase(fromRaw: 4) == .ended)
        #expect(SpaceSwipe.phase(fromRaw: 8) == .ended)
        #expect(SpaceSwipe.phase(fromRaw: 0) == nil)
    }
}
