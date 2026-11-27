import AppKit
import ApplicationServices
import Contacts
import CoreBluetooth
import EventKit

/// The macOS permissions Wingmate uses, in one place (spec C-8).
enum Permission: String, CaseIterable, Identifiable, Sendable {
    case fullDiskAccess
    case accessibility
    case calendar
    case reminders
    case contacts
    case bluetooth
    case screenRecording

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullDiskAccess: "Full Disk Access"
        case .accessibility: "Accessibility"
        case .calendar: "Calendars"
        case .reminders: "Reminders"
        case .contacts: "Contacts"
        case .bluetooth: "Bluetooth"
        case .screenRecording: "Screen Recording"
        }
    }

    /// What it is needed for.
    var purpose: String {
        switch self {
        case .fullDiskAccess: "Reading notifications"
        case .accessibility: "Volume keys, calls, hiding banners, focus follows mouse, pasting"
        case .calendar: "Meetings in the notch"
        case .reminders: "Reminders module"
        case .contacts: "Caller names and texting back"
        case .bluetooth: "Connected devices"
        case .screenRecording: "Screenshots, window previews, hiding the notch while the screen is shared"
        }
    }

    var symbol: String {
        switch self {
        case .fullDiskAccess: "externaldrive.fill"
        case .accessibility: "accessibility"
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .contacts: "person.crop.circle"
        case .bluetooth: "dot.radiowaves.left.and.right"
        case .screenRecording: "rectangle.dashed.badge.record"
        }
    }

    /// The System Settings pane where it is granted.
    var settingsURL: URL? {
        let anchor: String
        switch self {
        case .fullDiskAccess: anchor = "Privacy_AllFiles"
        case .accessibility: anchor = "Privacy_Accessibility"
        case .calendar: anchor = "Privacy_Calendars"
        case .reminders: anchor = "Privacy_Reminders"
        case .contacts: anchor = "Privacy_Contacts"
        case .bluetooth: anchor = "Privacy_Bluetooth"
        case .screenRecording: anchor = "Privacy_ScreenCapture"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?" + anchor)
    }

    /// nil: not asked yet; otherwise granted or not.
    @MainActor
    func isGranted(notificationsReadable: Bool) -> Bool? {
        switch self {
        case .fullDiskAccess:
            return notificationsReadable
        case .accessibility:
            return AXIsProcessTrusted()
        case .calendar:
            return Self.eventKit(EKEventStore.authorizationStatus(for: .event))
        case .reminders:
            return Self.eventKit(EKEventStore.authorizationStatus(for: .reminder))
        case .contacts:
            return Self.contacts()
        case .bluetooth:
            return Self.bluetooth()
        case .screenRecording:
            return CGPreflightScreenCaptureAccess()
        }
    }

    /// The Grant button (spec C-8b): a permission never asked for is asked for with the system's
    /// prompt, since System Settings lists an app only after it asked; otherwise its pane opens.
    @MainActor
    func grant(notificationsReadable: Bool) async {
        if isGranted(notificationsReadable: notificationsReadable) == nil {
            switch self {
            case .contacts:
                _ = try? await CNContactStore().requestAccess(for: .contacts)
                return
            case .calendar:
                _ = try? await EKEventStore().requestFullAccessToEvents()
                return
            case .reminders:
                _ = try? await EKEventStore().requestFullAccessToReminders()
                return
            case .fullDiskAccess, .accessibility, .bluetooth, .screenRecording:
                break
            }
        }
        // The first request adds Wingmate to the list in System Settings.
        if self == .screenRecording, !CGPreflightScreenCaptureAccess() { _ = CGRequestScreenCaptureAccess() }
        if let settingsURL { NSWorkspace.shared.open(settingsURL) }
    }

    /// A module or option in use needs it, so its absence breaks something (spec C-8d).
    @MainActor
    func isNeeded(by settings: AppSettings) -> Bool {
        switch self {
        case .fullDiskAccess: settings.isEnabled(.notifications)
        case .accessibility: true
        case .calendar: settings.isEnabled(.calendar)
        case .reminders: settings.isEnabled(.reminders)
        case .contacts: settings.callsEnabled
        case .bluetooth, .screenRecording: false
        }
    }

    /// The permissions in use that are missing.
    @MainActor
    static func missing(settings: AppSettings, notificationsReadable: Bool) -> [Permission] {
        allCases.filter { $0.isNeeded(by: settings) && $0.isGranted(notificationsReadable: notificationsReadable) == false }
    }

    private static func contacts() -> Bool? {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: nil
        case .authorized, .limited: true
        default: false
        }
    }

    private static func bluetooth() -> Bool? {
        switch CBManager.authorization {
        case .notDetermined: nil
        case .allowedAlways: true
        default: false
        }
    }

    private static func eventKit(_ status: EKAuthorizationStatus) -> Bool? {
        switch status {
        case .notDetermined: nil
        case .fullAccess: true
        default: false
        }
    }
}
