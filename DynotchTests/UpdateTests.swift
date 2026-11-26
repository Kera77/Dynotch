@testable import Dynotch
import Foundation
import Testing

@MainActor
struct UpdateTests {
    @Test func versionsCompareByNumber() {
        #expect(UpdateLogic.isNewer("0.27.0", than: "0.26.0"))
        #expect(UpdateLogic.isNewer("1.10.0", than: "1.9.3"))
        #expect(UpdateLogic.isNewer("v0.27.1", than: "0.27"))
        #expect(!UpdateLogic.isNewer("0.27.0", than: "0.27.0"))
        #expect(!UpdateLogic.isNewer("0.26.9", than: "0.27.0"))
        #expect(!UpdateLogic.isNewer("0.27", than: "0.27.0"))
    }

    @Test func theReleaseIsReadFromGitHubsAnswer() throws {
        let json = """
        {"tag_name":"v0.27.0","draft":false,"prerelease":false,"assets":[
          {"name":"Dynotch.zip","browser_download_url":"https://x/Dynotch.zip"},
          {"name":"Dynotch-0.27.0.zip","browser_download_url":"https://x/Dynotch-0.27.0.zip"},
          {"name":"SHA256SUMS.txt","browser_download_url":"https://x/SHA256SUMS.txt"}]}
        """
        let release = try #require(UpdateLogic.release(fromJSON: Data(json.utf8)))
        #expect(release.version == "0.27.0")
        #expect(release.archive.absoluteString == "https://x/Dynotch-0.27.0.zip")
        #expect(release.checksums?.absoluteString == "https://x/SHA256SUMS.txt")

        let draft = json.replacingOccurrences(of: #""draft":false"#, with: #""draft":true"#)
        #expect(UpdateLogic.release(fromJSON: Data(draft.utf8)) == nil)
        let noArchive = #"{"tag_name":"v1.0.0","assets":[]}"#
        #expect(UpdateLogic.release(fromJSON: Data(noArchive.utf8)) == nil)
    }

    @Test func theBetaChannelTakesTheNewestReleaseTestBuildsIncluded() throws {
        func entry(_ version: String, prerelease: Bool, draft: Bool = false) -> String {
            """
            {"tag_name":"v\(version)","draft":\(draft),"prerelease":\(prerelease),"assets":[
              {"name":"Dynotch-\(version).zip","browser_download_url":"https://x/Dynotch-\(version).zip"}]}
            """
        }
        let list = "[" + [entry("1.7.2", prerelease: false), entry("1.7.4", prerelease: true),
                          entry("1.7.3", prerelease: true), entry("1.7.5", prerelease: true, draft: true)]
            .joined(separator: ",") + "]"
        let newest = try #require(UpdateLogic.newestRelease(fromListJSON: Data(list.utf8)))
        #expect(newest.version == "1.7.4")
        // Everyone else never gets a test build (spec U-1, U-8).
        #expect(UpdateLogic.release(fromJSON: Data(entry("1.7.4", prerelease: true).utf8)) == nil)
        #expect(UpdateLogic.newestRelease(fromListJSON: Data("[]".utf8)) == nil)
    }

    @Test func testBuildsAreTheOnesWithANonZeroLastNumber() {
        #expect(UpdateLogic.isTestBuild("1.7.3"))
        #expect(UpdateLogic.isTestBuild("v1.8.1"))
        #expect(!UpdateLogic.isTestBuild("1.8.0"))
        #expect(!UpdateLogic.isTestBuild("1.8"))
    }

    @Test func checksumsAreLookedUpByFileName() {
        let sums = """
        aaa111  ./Dynotch-0.27.0.dmg
        BBB222  ./Dynotch-0.27.0.zip
        ccc333 *Dynotch.zip
        """
        #expect(UpdateLogic.expectedHash(forFile: "Dynotch-0.27.0.zip", inChecksums: sums) == "bbb222")
        #expect(UpdateLogic.expectedHash(forFile: "Dynotch.zip", inChecksums: sums) == "ccc333")
        #expect(UpdateLogic.expectedHash(forFile: "missing.zip", inChecksums: sums) == nil)
        #expect(UpdateLogic.sha256(of: Data("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func onlyAnInstalledCopyReplacesItself() {
        #expect(UpdateLogic.canReplace(appAt: "/Applications/Dynotch.app"))
        #expect(UpdateLogic.canReplace(appAt: "/Users/x/Applications/Dynotch.app"))
        #expect(!UpdateLogic.canReplace(appAt: "/Users/x/Library/Developer/Xcode/DerivedData/D/Build/Products/Debug/Dynotch.app"))
        #expect(!UpdateLogic.canReplace(appAt: "/usr/bin/xctest"))
        // The swap keeps the old copy until the new one is in place.
        let script = UpdateLogic.installScript
        #expect(script.contains("\"$3.previous\""))
        #expect(script.contains("/usr/bin/open \"$3\""))
    }

    @Test func anUpdateIsReportedOnceAfterwards() {
        let name = "UpdateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let service = UpdateService(defaults: defaults)
        #expect(service.installsAutomatically)
        #expect(service.versionUpdatedFrom(current: "0.26.0") == nil)
        #expect(service.versionUpdatedFrom(current: "0.27.0") == "0.26.0")
        #expect(service.versionUpdatedFrom(current: "0.27.0") == nil)
        service.installsAutomatically = false
        #expect(!UpdateService(defaults: defaults).installsAutomatically)
    }
}
