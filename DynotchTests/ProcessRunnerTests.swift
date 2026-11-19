@testable import Dynotch
import Foundation
import Testing

/// Command-line tools run with a time limit (stability review).
struct ProcessRunnerTests {
    @Test func outputAndStatusComeBack() throws {
        let result = try #require(ProcessRunner.run("/bin/echo", ["hello"]))
        #expect(result.succeeded)
        #expect(String(bytes: result.output, encoding: .utf8) == "hello\n")
    }

    @Test func aHangingToolIsStopped() throws {
        let started = Date()
        let result = try #require(ProcessRunner.run("/bin/sleep", ["10"], timeout: 0.5))
        #expect(result.timedOut)
        #expect(!result.succeeded)
        #expect(Date().timeIntervalSince(started) < 5)
    }

    @Test func aLargeErrorOutputDoesNotStallTheTool() throws {
        let result = try #require(ProcessRunner.run("/bin/sh", ["-c", "head -c 200000 /dev/zero >&2; echo done"], timeout: 10))
        #expect(result.succeeded)
        #expect(result.errors.count == 200_000)
    }

    @Test func aMissingToolGivesNil() {
        #expect(ProcessRunner.run("/no/such/tool", []) == nil)
    }
}
