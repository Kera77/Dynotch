import Testing
@testable import Wingmate

struct FeatureNavigationTests {
    private let list: [FeatureID] = [.home, .info]

    @Test func stepsForwardAndBack() {
        #expect(FeatureID.neighbor(of: .home, in: list, direction: .next) == .info)
        #expect(FeatureID.neighbor(of: .info, in: list, direction: .previous) == .home)
    }

    @Test func doesNotWrapAround() {
        #expect(FeatureID.neighbor(of: .info, in: list, direction: .next) == nil)
        #expect(FeatureID.neighbor(of: .home, in: list, direction: .previous) == nil)
    }
}
