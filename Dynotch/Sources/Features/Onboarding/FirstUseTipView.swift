import SwiftUI

/// One faint line at the bottom of a module the first time it opens, with a ×; it goes with
/// the module and never comes back (spec OB-26…OB-28).
struct FirstUseTipView: View {
    let feature: FeatureID
    let active: Bool
    @State private var tip: FirstUseTip?

    var body: some View {
        Group {
            if let tip {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(.yellow).accessibilityHidden(true)
                    Text(tip.text).font(.caption).lineLimit(2)
                    Spacer(minLength: 4)
                    Button {
                        withAnimation(Motion.quick) { self.tip = nil }
                    } label: {
                        Image(systemName: "xmark").font(.caption2.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss tip")
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule(style: .continuous).fill(Color.black.opacity(0.8)))
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12)))
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: TipKey(feature: feature, active: active)) {
            // A tip shows only while its module is open (spec OB-26).
            guard active, !OnboardingController.isRunning else {
                tip = nil
                return
            }
            let next = OnboardingProgress(defaults: .standard).takeTip(for: feature)
            withAnimation(Motion.quick) { tip = next }
        }
    }
}

private struct TipKey: Hashable {
    let feature: FeatureID
    let active: Bool
}
