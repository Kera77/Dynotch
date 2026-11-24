@testable import Dynotch
import Foundation
import Testing

/// Spec RF-4, RF-6, RF-21, H-8.
struct RefactorSafetyTests {
    @Test func appleScriptStringsEscapeBackslashesAndQuotes() {
        #expect(AppleScriptRunner.quotedString(#"a "b" \c"#) == #""a \"b\" \\c""#)
    }

    @Test func shellWordsAreSingleQuoted() {
        #expect(AppleScriptRunner.shellQuoted("it's; rm -rf ~") == #"'it'\''s; rm -rf ~'"#)
    }

    @Test func terminalScriptQuotesEveryWord() {
        let script = AppleScriptRunner.terminalScript(running: ["/bin/claude", "--resume", "x; touch /tmp/p"], in: "/a b")
        #expect(script.contains(#"do script "cd '/a b' && '/bin/claude' '--resume' 'x; touch /tmp/p'""#))
    }

    @Test func rollbackURLNamesTheTag() {
        #expect(UpdateLogic.release(version: "0.110.0")?.absoluteString
            == "https://api.github.com/repos/Kera77/Dynotch/releases/tags/v0.110.0")
        #expect(UpdateLogic.release(version: "0.1/../x") == nil)
    }

    @MainActor @Test func rollbackVersionIsKeptAfterAnUpdateOnly() throws {
        let defaults = try #require(UserDefaults(suiteName: "RefactorSafetyTests-\(UUID().uuidString)"))
        let updates = UpdateService(defaults: defaults)
        _ = updates.versionUpdatedFrom(current: "0.110.0")
        #expect(updates.rollbackVersion == nil)
        #expect(updates.versionUpdatedFrom(current: "0.111.0") == "0.110.0")
        #expect(defaults.string(forKey: "previousVersion") == "0.110.0")
        // Back on the older one: nothing to go back to.
        #expect(updates.versionUpdatedFrom(current: "0.110.0") == nil)
        #expect(defaults.string(forKey: "previousVersion") == nil)
    }

    @Test func escapeMustBeHeldThreeSeconds() {
        let start = Date()
        #expect(!KeyboardLockRules.isHeldLongEnough(since: start, now: start.addingTimeInterval(2.9)))
        #expect(KeyboardLockRules.isHeldLongEnough(since: start, now: start.addingTimeInterval(3)))
    }

    @MainActor @Test func featureSwitchTicksFirmerThanOpening() {
        #expect(Haptics.Kind.featureSwitch.actuation > Haptics.Kind.open.actuation)
    }
}
