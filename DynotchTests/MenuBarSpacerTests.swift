@testable import Dynotch
import Foundation
import Testing

/// Spaces in the menu bar (spec MB-1…MB-6, MB-13, MB-14).
@MainActor
struct MenuBarSpacerTests {
    private let space = CGRect(x: 1000, y: 880, width: 16, height: 24)

    @Test func spaceWithAnIconLeftOfItIsNotAlone() {
        let icon = CGRect(x: 960, y: 880, width: 30, height: 24)
        #expect(MenuBarSpacerService.hasIcon(leftOf: space, among: [icon], screenMinX: 0))
    }

    @Test func iconsRightOfItOrOnAnotherScreenDoNotCount() {
        let right = CGRect(x: 1030, y: 880, width: 30, height: 24)
        let otherScreen = CGRect(x: -200, y: 880, width: 30, height: 24)
        #expect(!MenuBarSpacerService.hasIcon(leftOf: space, among: [right, otherScreen], screenMinX: 0))
    }

    @Test func hiddenSpaceMeasuresFromItsRightEdge() {
        let hidden = CGRect(x: 1016, y: 880, width: 0, height: 24)
        let icon = CGRect(x: 960, y: 880, width: 30, height: 24)
        #expect(MenuBarSpacerService.hasIcon(leftOf: hidden, among: [icon], screenMinX: 0))
    }

    @Test func spaceSavedBeforeKeepsItsStyleAndShows() throws {
        let json = #"[{"id":"9F1C2B3A-1111-2222-3333-444455556666","style":"Line","width":"Large"}]"#
        let spacers = try JSONDecoder().decode([MenuBarSpacer].self, from: Data(json.utf8))
        #expect(spacers.first?.style == .line)
        #expect(spacers.first?.width == .large)
        #expect(spacers.first?.hidesWhenAlone == false)
    }

    @MainActor @Test func spacesAreKept() {
        let defaults = UserDefaults(suiteName: "MenuBarSpacerTests-\(UUID().uuidString)") ?? .standard
        let service = MenuBarSpacerService(defaults: defaults)
        let first = service.add()
        service.add()
        service.setStyle(.line, of: first.id)
        service.setWidth(.large, of: first.id)
        let reopened = MenuBarSpacerService(defaults: defaults)
        #expect(reopened.spacers.count == 2)
        #expect(reopened.spacers.first?.style == .line)
        #expect(reopened.spacers.first?.width == .large)
        reopened.remove(first.id)
        #expect(MenuBarSpacerService(defaults: defaults).spacers.count == 1)
    }
}
