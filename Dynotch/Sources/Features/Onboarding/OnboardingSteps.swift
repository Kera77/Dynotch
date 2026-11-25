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
            "Open the notch, then swipe with two fingers or click an icon in its top row."
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
            "Settings live behind the gear icon at the right of the notch's top row."
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
        case .welcome, .openClose, .moving: welcomeHints
        case .modules: OnboardingModulesStep(settings: controller.settings)
        case .beside: OnboardingBesideStep(settings: controller.settings)
        case .power: OnboardingPowerStep(settings: controller.settings, switcher: controller.switcher)
        case .look: OnboardingLookStep(settings: controller.settings)
        case .permissions: OnboardingPermissionsStep(permissions: controller.neededPermissions)
        case .ready: OnboardingReadyStep()
        }
    }

    private var welcomeHints: some View {
        VStack(alignment: .leading, spacing: 8) {
            OnboardingRow(
                symbol: "cursorarrow.motionlines", title: "Hover to open", text: "No clicking: the notch opens under the pointer."
            )
            OnboardingRow(symbol: "hand.draw", title: "Swipe to switch", text: "Two fingers sideways move between modules.")
            OnboardingRow(symbol: "square.grid.2x2", title: "Pick your modules", text: "Calendar, notifications, clipboard, AI and more.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
