import Foundation

/// Where the settings open (spec C-2).
enum SettingsPresentation: String, CaseIterable, Sendable {
    /// Inside the opened notch panel.
    case notch
    /// In a separate window.
    case window
}

/// The look of the open notch and the menu bar panels (spec D-1).
enum NotchDesign: String, CaseIterable, Sendable {
    /// Black, like the notch itself.
    case black
    /// Liquid glass (macOS 26 and later; black before).
    case glass
    /// Black at the top, turning into glass downwards.
    case blend

    var title: String {
        switch self {
        case .black: "Black"
        case .glass: "Liquid glass"
        case .blend: "Black to glass"
        }
    }
}

/// How the notch looks on a display without a physical notch (spec D-7).
enum ExternalNotchStyle: String, CaseIterable, Sendable {
    /// Joined to the top edge, like a notch.
    case notch
    /// A capsule floating a little below the top edge.
    case pill

    var title: String {
        switch self {
        case .notch: "Notch"
        case .pill: "Pill"
        }
    }
}
