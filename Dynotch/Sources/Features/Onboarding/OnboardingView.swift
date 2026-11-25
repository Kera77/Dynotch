import SwiftUI

/// The tour's page in the notch: a picture, a title and at most two sentences, the step's own
/// controls, dots and Back / Next / Skip tour (spec OB-9, OB-36).
struct OnboardingView: View {
    let controller: OnboardingController
    @Bindable var model: OnboardingModel
    let notchHeight: CGFloat
    /// The tallest the panel may be, for the step's scrolling part.
    let maxHeight: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let width: CGFloat = 560
    /// Title, text, buttons and paddings around the scrolling part.
    private static let chrome: CGFloat = 230

    var body: some View {
        Group {
            if model.showsSkipNote {
                skipNote
            } else {
                fullPage
            }
        }
        .padding(.top, notchHeight + 12)
        .padding(.bottom, 14)
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { controller.fit($0) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.spring, value: model.step)
    }

    /// Title and buttons stay in sight; only the step's content scrolls (spec OB-30, OB-36).
    private var fullPage: some View {
        VStack(spacing: 12) {
            OnboardingHeader(step: model.step)
            FittingScroll(maxHeight: min(maxHeight - notchHeight - Self.chrome, 600)) {
                OnboardingStepContent(controller: controller, step: model.step)
            }
            .id(model.step)
            .transition(.opacity)
            OnboardingFooter(controller: controller, step: model.step)
        }
        .padding(.horizontal, 20)
    }

    private var skipNote: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.counterclockwise.circle").font(.system(size: 30)).foregroundStyle(.secondary)
            Text("You can replay the tour in Settings › General.")
                .font(.callout)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

/// A scroll area exactly as tall as its content, up to `maxHeight` (spec OB-30).
struct FittingScroll<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 0

    var body: some View {
        ScrollView {
            content
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(max(height, 1), max(maxHeight, 120)))
    }
}

/// The step's picture, title and text.
struct OnboardingHeader: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: step.symbol)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.blue)
                .symbolEffect(.pulse, options: .repeating)
                .frame(height: 38)
                .accessibilityHidden(true)
            Text(step.title)
                .font(.title2.weight(.semibold))
            Text(step.text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Dots, Skip tour, Back and Next (Done on the last step).
struct OnboardingFooter: View {
    let controller: OnboardingController
    let step: OnboardingStep

    var body: some View {
        HStack(spacing: 10) {
            if step != .welcome && !step.isLast {
                Button("Skip tour") { controller.skip() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            OnboardingDots(step: step)
            Spacer()
            if step != .welcome {
                Button("Back") { controller.back() }
            }
            if step == .welcome {
                Button("Skip tour") { controller.skip() }
                Button("Start tour") { controller.next() }.keyboardShortcut(.defaultAction)
            } else {
                Button(step.isLast ? "Done" : "Next") { controller.next() }.keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
    }
}

/// Where the tour stands.
struct OnboardingDots: View {
    let step: OnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { item in
                Circle()
                    .fill(item == step ? Color.white : Color.white.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")
    }
}
