@testable import Dynotch
import Testing

struct AppInfoTests {
    @Test func versionIsNotEmpty() {
        #expect(!AppInfo.version.isEmpty)
    }

    @Test func buildIsNotEmpty() {
        #expect(!AppInfo.build.isEmpty)
    }
}
