import SwiftUI

/// The tour's card: a picture, a title and at most two sentences, the step's own controls,
/// dots and Back / Next / Skip tour (spec OB-9).
struct OnboardingView: View {
    let controller: OnboardingController
    @Bindable var model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CardContainer(design: controller.settings.design, onSize: controller.fit) {
            Group {
                if model.showsSkipNote {
                    skipNote
                } else if model.step.isPractice {
                    PracticeCard(controller: controller, model: model)
                } else {
                    fullCard
                }
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.spring, value: model.step)
    }

    /// Title and buttons stay on screen; only the step's content scrolls (spec OB-30).
    private var fullCard: some View {
        VStack(spacing: 12) {
            OnboardingHeader(step: model.step)
            FittingScroll(maxHeight: min(CardPanel.maxHeight - 250, 600)) {
                OnboardingStepContent(controller: controller, step: model.step)
            }
            .id(model.step)
            .transition(.opacity)
            OnboardingFooter(controller: controller, step: model.step)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 14)
        .frame(width: 520)
    }

    private var skipNote: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.counterclockwise.circle").font(.system(size: 30)).foregroundStyle(.secondary)
            Text("You can replay the tour in Settings › General.")
                .font(.callout)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .frame(width: 380)
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

/// The small card shown while the real notch is practised on (spec OB-15, OB-16).
struct PracticeCard: View {
    let controller: OnboardingController
    let model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: model.practiceDone ? "checkmark.circle.fill" : model.step.symbol)
                    .font(.system(size: 22))
                    .foregroundStyle(model.practiceDone ? Theme.green : Theme.blue)
                    .contentTransition(.symbolEffect(.replace))
                Text(model.practiceDone ? "Nice!" : model.step.title).font(.headline)
                Spacer()
                OnboardingDots(step: model.step)
            }
            Text(instruction)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Skip tour") { controller.skip() }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button("Back") { controller.back() }
                Button("Next") { controller.next() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 14)
        .frame(width: 380)
    }

    private var instruction: String {
        if model.step == .openClose, model.practiceOpened, !model.practiceDone {
            return "Now move the pointer away: the notch closes by itself."
        }
        return model.step.text
    }
}
