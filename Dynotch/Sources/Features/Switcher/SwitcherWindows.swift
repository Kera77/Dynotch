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
        /// Only windows mostly hidden behind others; minimized, hidden and other Spaces' count
        /// as hidden (spec AS-14).
        var onlyCovered = false
        /// The share of a window that must be covered.
        var coverThreshold = 0.5
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
        // Front to back: what lies above each window (spec AS-14).
        let covers = coveringRects(info, ownPID: ownPID)
        for (index, entry) in info.enumerated() {
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
            if options.onlyCovered, onScreen, !isMinimized,
               coverage(of: bounds, by: covers.prefix(index).compactMap { $0 }) < options.coverThreshold {
                continue
            }
            if options.groupsByApp, !seenApps.insert(pid).inserted { continue }
            result.append(SwitcherItem(
                windowID: id, pid: pid, bundleID: app.bundleID, appName: app.name,
                title: entry[kCGWindowName as String] as? String ?? "", bounds: bounds, isMinimized: isMinimized
            ))
        }
        return result
    }

    /// For each entry, its frame if it is a visible normal window that can cover the ones below.
    nonisolated static func coveringRects(_ info: [[String: Any]], ownPID: pid_t) -> [CGRect?] {
        info.map { entry in
            guard entry[kCGWindowLayer as String] as? Int ?? 0 == 0,
                  entry[kCGWindowIsOnscreen as String] as? Bool ?? true,
                  entry[kCGWindowOwnerPID as String] as? pid_t != ownPID,
                  let boundsDictionary = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
            else { return nil }
            return bounds
        }
    }

    /// The share of `rect` under the other rectangles, measured on a grid of points.
    nonisolated static func coverage(of rect: CGRect, by others: [CGRect]) -> Double {
        let overlapping = others.filter { $0.intersects(rect) }
        guard !overlapping.isEmpty, rect.width > 0, rect.height > 0 else { return 0 }
        let steps = 20
        var covered = 0
        for row in 0..<steps {
            for column in 0..<steps {
                let point = CGPoint(
                    x: rect.minX + (CGFloat(column) + 0.5) * rect.width / CGFloat(steps),
                    y: rect.minY + (CGFloat(row) + 0.5) * rect.height / CGFloat(steps)
                )
                if overlapping.contains(where: { $0.contains(point) }) { covered += 1 }
            }
        }
        return Double(covered) / Double(steps * steps)
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
