import Foundation
import Testing
@testable import Wingmate

/// Spec RF-4, RF-6, H-8.
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

    @MainActor @Test func onlyANewerVersionCountsAsAnUpdate() throws {
        let defaults = try #require(UserDefaults(suiteName: "RefactorSafetyTests-\(UUID().uuidString)"))
        let updates = UpdateService(defaults: defaults)
        #expect(updates.versionUpdatedFrom(current: "0.110.0") == nil)
        #expect(updates.versionUpdatedFrom(current: "0.111.0") == "0.110.0")
        // Back on the older one by hand: not an update.
        #expect(updates.versionUpdatedFrom(current: "0.110.0") == nil)
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
