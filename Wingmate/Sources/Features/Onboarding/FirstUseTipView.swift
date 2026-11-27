import SwiftUI

/// A short tip at the bottom of a module, or of one of its tabs, the first time it opens, with
/// a ×; it goes with the module and never comes back (spec OB-26…OB-28, OB-37).
struct FirstUseTipView: View {
    let feature: FeatureID
    let notificationsTab: NotificationsTab
    let trayFolder: UUID?
    let active: Bool
    @AppStorage("clipboardTab") private var clipboardTab = ClipboardTab.history
    @State private var tip: FirstUseTip?

    /// The open tab of a module with tabs (spec OB-37).
    private var tab: String? {
        switch feature {
        case .notifications: OnboardingTips.tab(notificationsTab)
        case .tools: ToolsSettings.shared.tab.rawValue
        case .clipboard: clipboardTab.rawValue
        case .tray: OnboardingTips.trayTab(trayFolder)
        default: nil
        }
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 12, style: .continuous) }

    var body: some View {
        Group {
            if let tip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(.yellow).accessibilityHidden(true)
                    Text(tip.text)
                        .font(.caption)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
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
                .padding(.vertical, 8)
                .background(shape.fill(Color.black.opacity(0.85)))
                .overlay(shape.stroke(Color.white.opacity(0.12)))
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: TipKey(feature: feature, tab: tab, active: active)) {
            // A tip shows only while its module is open (spec OB-26).
            guard active, !OnboardingController.isRunning else {
                tip = nil
                return
            }
            let next = OnboardingProgress(defaults: .standard).takeTip(for: feature, tab: tab)
            withAnimation(Motion.quick) { tip = next }
        }
    }
}

private struct TipKey: Hashable {
    let feature: FeatureID
    let tab: String?
    let active: Bool
}
