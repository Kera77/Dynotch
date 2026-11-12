import Testing
@testable import Dynotch

struct AppInfoTests {
    @Test func versionIsNotEmpty() {
        #expect(!AppInfo.version.isEmpty)
    }

    @Test func buildIsNotEmpty() {
        #expect(!AppInfo.build.isEmpty)
    }
}
