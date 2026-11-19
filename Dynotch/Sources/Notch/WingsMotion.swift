import SwiftUI

// MARK: - Spreading open (spec PV-11)

extension EnvironmentValues {
    /// How far the wings have spread out of the notch: 0 inside it, 1 fully out (spec PV-11).
    @Entry var wingsSpread: CGFloat = 1
}

/// Carries the transition's progress to the wings frame by frame, so both sides slide out of
/// the notch's middle while it widens, and slide back in when it closes (spec PV-11).
private struct WingsSpreadEffect: ViewModifier, Animatable {
    var spread: CGFloat

    nonisolated var animatableData: CGFloat {
        get { spread }
        set { spread = newValue }
    }

    func body(content: Content) -> some View {
        content.environment(\.wingsSpread, spread)
    }
}

extension AnyTransition {
    /// The wings slide out to both sides of the notch and back in (spec PV-11).
    static var wingsSpread: AnyTransition {
        .modifier(active: WingsSpreadEffect(spread: 0), identity: WingsSpreadEffect(spread: 1))
    }

    /// The wings' spread in Wings mode, a fade otherwise.
    static func wingsOr(_ wings: Bool) -> AnyTransition {
        wings ? .wingsSpread : .opacity
    }
}

extension View {
    /// One side of the wings, `towardsNotch` points along x when the wings are still inside the
    /// notch (positive for the left side, negative for the right).
    func wingSpread(_ spread: CGFloat, towardsNotch distance: CGFloat) -> some View {
        let moves = !AppleStyle.reducesMotion
        return offset(x: moves ? (1 - spread) * distance : 0)
            .opacity(Double(max(0, min(1, spread * 1.4 - 0.2))))
    }
}

// MARK: - A notification in the wings (spec PV-13)

/// A new notification beside the notch instead of under it: the app and who wrote at the left,
/// the first line at the right. A swipe up puts it away, a swipe down opens it.
struct WingsPeekView: View {
    let app: NotificationApp
    let content: NotificationContent
    let notchWidth: CGFloat
    var newCount = 1

    /// The width each side gets (the notch widens by twice this, at most to 2/3 of the display).
    static let side: CGFloat = 230

    @Environment(\.wingsSpread) private var spread

    var body: some View {
        GeometryReader { proxy in
            let side = max((proxy.size.width - notchWidth) / 2, 0)
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    AppIconView(app: app, size: 16)
                    WingText(content.sender, bold: true)
                    if newCount > 1 { WingText("+\(newCount - 1)", dim: true) }
                }
                .padding(.horizontal, WingsView<EmptyView, EmptyView>.padding)
                .frame(width: side, alignment: .leading)
                .wingSpread(spread, towardsNotch: side / 2)
                Color.clear.frame(width: notchWidth)
                WingText(FeaturePreview.line(of: content.detail, fallback: app.name), dim: true)
                    .padding(.horizontal, WingsView<EmptyView, EmptyView>.padding)
                    .frame(width: side, alignment: .leading)
                    .wingSpread(spread, towardsNotch: -side / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }
}

// MARK: - Dropping files on the wings (spec PV-14)

/// Files dragged onto the notch in Wings mode: the tray at the left, AirDrop at the right, at the
/// notch's own height, without the panel dropping down.
struct WingsDropView: View {
    let notchWidth: CGFloat
    let keep: ([URL]) -> Void
    let airDrop: ([URL]) -> Void

    /// The width each side gets.
    static let side: CGFloat = 170

    @State private var overKeep = false
    @State private var overAirDrop = false
    @Environment(\.wingsSpread) private var spread

    var body: some View {
        GeometryReader { proxy in
            let side = max((proxy.size.width - notchWidth) / 2, 0)
            HStack(spacing: 0) {
                target(title: "Keep in Tray", symbol: "tray.and.arrow.down.fill", isOver: overKeep)
                    .frame(width: side)
                    .dropDestination(for: URL.self) { urls, _ in
                        keep(urls)
                        return true
                    } isTargeted: { overKeep = $0 }
                    .wingSpread(spread, towardsNotch: side / 2)
                Color.clear.frame(width: notchWidth)
                target(title: "AirDrop", symbol: "dot.radiowaves.left.and.right", isOver: overAirDrop)
                    .frame(width: side)
                    .dropDestination(for: URL.self) { urls, _ in
                        airDrop(urls)
                        return true
                    } isTargeted: { overAirDrop = $0 }
                    .wingSpread(spread, towardsNotch: -side / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func target(title: String, symbol: String, isOver: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.notch(size: 12, weight: .semibold))
            Text(title).font(.notch(size: 12, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(Color.white.level(isOver ? 1 : 0.8))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous)
                .fill(Color.white.level(isOver ? 0.2 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous)
                .strokeBorder(Color.white.level(isOver ? 0.7 : 0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .animation(Motion.hover, value: isOver)
    }
}
