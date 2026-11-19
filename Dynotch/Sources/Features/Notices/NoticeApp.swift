import AppKit
import ApplicationServices

/// Brings forward the app a "finished" notice came from, and the project's window in it when a
/// window's title names the project (spec CN-6, CN-7).
@MainActor
enum NoticeApp {
    static func bringForward(_ bundleID: String, project: String) {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            return
        }
        let raised = project.isEmpty ? false : raiseWindow(of: app.processIdentifier, naming: project)
        app.activate()
        DiagnosticsLog.append("claude-hook", "notice clicked: \(bundleID) window=\(raised)")
    }

    private static func raiseWindow(of pid: pid_t, naming project: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let root = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(root, 0.3)
        let windows = NativeBannerDismisser.children(of: root, attribute: kAXWindowsAttribute)
        let titles = windows.map { NativeBannerDismisser.string(of: $0, kAXTitleAttribute) ?? "" }
        guard let index = window(among: titles, naming: project) else { return false }
        AXUIElementSetAttributeValue(windows[index], kAXMainAttribute as CFString, kCFBooleanTrue)
        return AXUIElementPerformAction(windows[index], kAXRaiseAction as CFString) == .success
    }

    /// The window whose title names the project: as a whole part of the title ("file — Project",
    /// "Project"), otherwise anywhere in it.
    nonisolated static func window(among titles: [String], naming project: String) -> Int? {
        let wanted = project.lowercased()
        let parts = titles.map { title in
            title.lowercased().components(separatedBy: CharacterSet(charactersIn: "—–-·|")).map { $0.trimmingCharacters(in: .whitespaces) }
        }
        if let exact = parts.firstIndex(where: { $0.contains(wanted) }) { return exact }
        return titles.firstIndex { $0.lowercased().contains(wanted) }
    }
}
