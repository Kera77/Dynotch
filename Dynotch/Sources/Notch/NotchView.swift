import SwiftUI

struct NotchView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var settings: AppSettings

    private var geometry: NotchGeometry { model.geometry }
    private var size: CGSize { model.isExpanded ? geometry.expandedSize : geometry.notchSize }
    private var cornerRadius: CGFloat { model.isExpanded ? 24 : 10 }

    var body: some View {
        ZStack(alignment: .top) {
            shape
                .fill(.black)
                .frame(width: size.width, height: size.height)

            if model.isExpanded {
                expandedContent
                    .frame(width: geometry.expandedSize.width, height: geometry.expandedSize.height)
                    .clipShape(shape)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            style: .continuous
        )
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            menuBar
            featureContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(x: model.bounceOffset)
        }
    }

    // MARK: - Menu bar (spec M-1…M-3)

    private var sideWidth: CGFloat {
        (geometry.expandedSize.width - geometry.notchSize.width) / 2
    }

    private var menuBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(settings.activeFeatures) { feature in
                    MenuBarButton(feature: feature, isSelected: feature == model.currentFeature) {
                        withAnimation(NotchController.animation) { model.select(feature) }
                    }
                }
            }
            .padding(.leading, 18)
            .frame(width: sideWidth, alignment: .leading)

            Color.clear.frame(width: geometry.notchSize.width)

            // Right side of the notch: reserved for status (e.g. the volume/brightness HUD).
            Color.clear.frame(width: sideWidth)
        }
        .frame(height: max(geometry.notchSize.height, 28))
    }

    // MARK: - Content

    private var featureContent: some View {
        ZStack {
            switch model.currentFeature {
            case .home:
                HomeFeatureView()
            case .info:
                InfoFeatureView(geometry: geometry, screenName: model.screenName)
            }
        }
        .id(model.currentFeature)
        .transition(slideTransition)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var slideTransition: AnyTransition {
        let forward = model.lastDirection == .next
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }
}

private struct MenuBarButton: View {
    let feature: FeatureID
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: feature.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 22)
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.45))
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.16) : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(feature.title)
    }
}
