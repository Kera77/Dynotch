import ApplicationServices
import Foundation

@_silgen_name("_AXUIElementCreateWithRemoteToken")
private func axElementWithRemoteToken(_ data: CFData) -> Unmanaged<AXUIElement>?

/// An app's windows for Accessibility, including those on another Space, which `AXWindows`
/// leaves out: those are found by their remote token (the way window switchers do it).
enum AXWindows {
    /// How many window tokens to try when the hint no longer works.
    private static let tokenRange: Range<UInt64> = 0..<1000

    /// - Parameter hint: a token that found a window before; tried first.
    /// - Returns: the windows and, if one came from a token, that token.
    nonisolated static func all(pid: pid_t, hint: UInt64?) -> ([AXUIElement], UInt64?) {
        let app = AXUIElementCreateApplication(pid)
        let listed = (AXRead.value(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
        if !listed.isEmpty { return (listed, nil) }
        if let hint, let window = window(pid: pid, token: hint) { return ([window], hint) }
        for token in tokenRange {
            if let window = window(pid: pid, token: token) { return ([window], token) }
        }
        return ([], nil)
    }

    private nonisolated static func window(pid: pid_t, token: UInt64) -> AXUIElement? {
        var data = Data(count: 20)
        withUnsafeBytes(of: pid) { data.replaceSubrange(0..<4, with: $0) }
        withUnsafeBytes(of: Int32(0x636f_636f)) { data.replaceSubrange(8..<12, with: $0) }
        withUnsafeBytes(of: token) { data.replaceSubrange(12..<20, with: $0) }
        guard let element = axElementWithRemoteToken(data as CFData)?.takeRetainedValue(),
              AXRead.string(element, kAXRoleAttribute) == (kAXWindowRole as String)
        else { return nil }
        return element
    }
}
