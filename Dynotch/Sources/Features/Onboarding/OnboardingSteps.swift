import SwiftUI

extension OnboardingStep {
    var title: String {
        switch self {
        case .welcome: "Your notch, now useful"
        case .openClose: "Open and close"
        case .moving: "Move between modules"
        case .modules: "Choose your modules"
        case .beside: "Beside the closed notch"
        case .power: "Power moves"
        case .look: "Make it yours"
        case .permissions: "Permissions"
        case .ready: "You're ready"
        }
    }

    /// At most two sentences (spec OB-9).
    var text: String {
        switch self {
        case .welcome:
            "Wingmate puts your calendar, notifications, tools and AI right in the notch. This tour takes about two minutes."
        case .openClose:
            "Move the pointer up to the notch to open it. Move away and it closes."
        case .moving:
            "Every module has its own page in the open notch. Here is how to move between them."
        case .modules:
            "Pick what lives in your notch. You can change this any time in Settings › Modules."
        case .beside:
            "The closed notch shows what matters, right beside it."
        case .power:
            "A few shortcuts that make Wingmate fast."
        case .look:
            "Pick a look for the open notch."
        case .permissions:
            "Wingmate only asks for what your modules need. Nothing here is required."
        case .ready:
            "Settings live behind the gear icon at the right of the notch's top row; the switch beside it holds "
                + "quick toggles like Keep Awake."
        }
    }

    var symbol: String {
        switch self {
        case .welcome: "sparkles"
        case .openClose: "cursorarrow.motionlines"
        case .moving: "hand.draw"
        case .modules: "square.grid.2x2"
        case .beside: "rectangle.topthird.inset.filled"
        case .power: "bolt.fill"
        case .look: "paintpalette"
        case .permissions: "lock.shield"
        case .ready: "gearshape"
        }
    }
}

/// The controls of one step (spec OB-17…OB-22).
struct OnboardingStepContent: View {
    let controller: OnboardingController
    let step: OnboardingStep

    var body: some View {
        switch step {
        case .welcome: welcomeHints
        case .openClose: openCloseHints
        case .moving: movingHints
        case .modules: OnboardingModulesStep(settings: controller.settings)
        case .beside: OnboardingBesideStep(settings: controller.settings)
        case .power: OnboardingPowerStep(settings: controller.settings, switcher: controller.switcher)
        case .look: OnboardingLookStep(settings: controller.settings)
        case .permissions: OnboardingPermissionsStep(permissions: controller.neededPermissions)
        case .ready: OnboardingReadyStep()
        }
    }

    /// Open and close, told instead of practised (spec OB-36).
    private var openCloseHints: some View {
        VStack(alignment: .leading, spacing: 8) {
            OnboardingRow(
                symbol: "cursorarrow.motionlines", title: "Hover to open", text: "Move the pointer up to the notch; no click needed."
            )
            OnboardingRow(
                symbol: "arrow.down.right.and.arrow.up.left", title: "Move away to close", text: "The notch folds back by itself."
            )
            OnboardingRow(
                symbol: "lock", title: "Keep it open", text: "The lock in the top row holds the notch open until you click it again."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 30)
    }

    /// Moving between modules, told instead of practised (spec OB-36).
    private var movingHints: some View {
        VStack(alignment: .leading, spacing: 8) {
            OnboardingRow(
                symbol: "hand.draw", title: "Swipe sideways",
                text: "Two fingers on the trackpad move to the next or previous module; over a row of tabs, to the next tab."
            )
            OnboardingRow(
                symbol: "square.grid.2x2", title: "Click an icon", text: "The top row of the open notch has an icon for every module."
            )
            OnboardingRow(symbol: "command", title: "Use the keyboard", text: "⌘1–9 picks a module, ← and → step through them.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 30)
    }

    private var welcomeHints: some View {
        VStack(alignment: .leading, spacing: 8) {
            OnboardingRow(
                symbol: "cursorarrow.motionlines", title: "Hover to open", text: "No clicking: the notch opens under the pointer."
            )
            OnboardingRow(symbol: "hand.draw", title: "Swipe to switch", text: "Two fingers sideways move between modules.")
            OnboardingRow(symbol: "square.grid.2x2", title: "Pick your modules", text: "Calendar, notifications, clipboard, AI and more.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 30)
    }
}

/// An icon, a bold title and one line, as used across the tour.
struct OnboardingRow<Trailing: View>: View {
    let symbol: String
    let title: String
    let text: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Theme.blue)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

extension OnboardingRow where Trailing == EmptyView {
    init(symbol: String, title: String, text: String) {
        self.init(symbol: symbol, title: title, text: text) { EmptyView() }
    }
}
