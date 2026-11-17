import AppKit
import ApplicationServices
import Contacts
import CoreBluetooth
import EventKit

/// The macOS permissions Dynotch uses, in one place (spec C-8).
enum Permission: String, CaseIterable, Identifiable, Sendable {
    case fullDiskAccess
    case accessibility
    case calendar
    case reminders
    case contacts
    case bluetooth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullDiskAccess: "Full Disk Access"
        case .accessibility: "Accessibility"
        case .calendar: "Calendars"
        case .reminders: "Reminders"
        case .contacts: "Contacts"
        case .bluetooth: "Bluetooth"
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
        }
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
