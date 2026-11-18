import AppKit
import ApplicationServices

/// One entry of the switcher: a window, or an app when grouped (spec AS-2).
struct SwitcherItem: Identifiable, Equatable, Sendable {
    let windowID: CGWindowID
    let pid: pid_t
    let bundleID: String?
    let appName: String
    let title: String
    let bounds: CGRect
    var isMinimized = false

    var id: CGWindowID { windowID }
    /// The window title, or the app's name when the window has none.
    var label: String { title.isEmpty ? appName : title }
}

/// The windows the switcher lists, in front-to-back order, and switching to one (spec AS-2,
/// AS-3, AS-13).
@MainActor
enum SwitcherWindows {
    struct Options: Sendable {
        var scope = SwitcherScope.currentSpace
        var groupsByApp = false
        var showsMinimized = false
        var showsHidden = false
        /// Only windows on this display (global, top-left origin like the window list).
        var display: CGRect?
        var excluded: [String] = []
    }

    struct AppInfo: Sendable {
        let name: String
        let bundleID: String?
        let isHidden: Bool
    }

    static func list(_ options: Options) -> [SwitcherItem] {
        let flags: CGWindowListOption = options.scope == .currentSpace
            ? [.optionOnScreenOnly, .excludeDesktopElements] : [.optionAll, .excludeDesktopElements]
        let info = CGWindowListCopyWindowInfo(flags, kCGNullWindowID) as? [[String: Any]] ?? []
        var apps: [pid_t: AppInfo] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            apps[app.processIdentifier] = AppInfo(
                name: app.localizedName ?? "", bundleID: app.bundleIdentifier, isHidden: app.isHidden
            )
        }
        var minimized: Set<CGWindowID> = []
        if options.showsMinimized {
            for pid in apps.keys { minimized.formUnion(SkyLightFocus.minimizedWindowIDs(of: pid)) }
        }
        return items(from: info, apps: apps, minimized: minimized, ownPID: getpid(), options: options)
    }

    /// The pure choice: normal windows of regular apps, big enough, not excluded; the other
    /// Spaces' and minimized ones only when asked; grouped per app when asked.
    nonisolated static func items(
        from info: [[String: Any]], apps: [pid_t: AppInfo], minimized: Set<CGWindowID>, ownPID: pid_t, options: Options
    ) -> [SwitcherItem] {
        var result: [SwitcherItem] = []
        var seenApps: Set<pid_t> = []
        for entry in info {
            guard let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  let app = apps[pid], !options.excluded.contains(app.bundleID ?? ""),
                  entry[kCGWindowLayer as String] as? Int ?? 0 == 0,
                  let boundsDictionary = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
                  bounds.width >= 80, bounds.height >= 60
            else { continue }
            let isMinimized = minimized.contains(id)
            let onScreen = entry[kCGWindowIsOnscreen as String] as? Bool ?? true
            if app.isHidden, !options.showsHidden { continue }
            if isMinimized, !options.showsMinimized { continue }
            // Off screen and not minimized: another Space, only with "All apps".
            if !onScreen, !isMinimized, options.scope == .currentSpace { continue }
            if let display = options.display, !isMinimized, !display.intersects(bounds) { continue }
            if options.groupsByApp, !seenApps.insert(pid).inserted { continue }
            result.append(SwitcherItem(
                windowID: id, pid: pid, bundleID: app.bundleID, appName: app.name,
                title: entry[kCGWindowName as String] as? String ?? "", bounds: bounds, isMinimized: isMinimized
            ))
        }
        return result
    }

    /// Brings the window forward and its app to the front; a minimized window comes back first.
    static func activate(_ item: SwitcherItem) {
        guard let app = NSRunningApplication(processIdentifier: item.pid) else { return }
        if app.isHidden { app.unhide() }
        if let window = SkyLightFocus.axWindow(pid: item.pid, windowID: item.windowID) {
            if item.isMinimized { AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse) }
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
        app.activate()
    }

    /// The quick actions while the switcher is open (spec AS-10).
    static func close(_ item: SwitcherItem) {
        guard let window = SkyLightFocus.axWindow(pid: item.pid, windowID: item.windowID) else { return }
        var button: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &button) == .success,
              let button, CFGetTypeID(button) == AXUIElementGetTypeID()
        else { return }
        AXUIElementPerformAction(unsafeBitCast(button, to: AXUIElement.self), kAXPressAction as CFString)
    }

    static func minimize(_ item: SwitcherItem) {
        guard let window = SkyLightFocus.axWindow(pid: item.pid, windowID: item.windowID) else { return }
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    static func quit(_ item: SwitcherItem) {
        NSRunningApplication(processIdentifier: item.pid)?.terminate()
    }

    static func hide(_ item: SwitcherItem) {
        NSRunningApplication(processIdentifier: item.pid)?.hide()
    }
}
