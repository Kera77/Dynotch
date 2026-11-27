import Testing
@testable import Wingmate

struct AppInfoTests {
    @Test func versionIsNotEmpty() {
        #expect(!AppInfo.version.isEmpty)
    }

    @Test func buildIsNotEmpty() {
        #expect(!AppInfo.build.isEmpty)
    }
}
