import SwiftUI

/// The modules under the closed notch (spec MS-1): see-through blurred circles with clear white
/// icons; a click opens the notch on that module.
struct ModuleStripView: View {
    let features: [FeatureID]
    let open: (FeatureID) -> Void

    @State private var hovered: FeatureID?

    var body: some View {
        HStack(spacing: NotchGeometry.stripSpacing) {
            ForEach(features) { feature in
                Button {
                    open(feature)
                } label: {
                    Image(systemName: feature.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
                        .frame(width: NotchGeometry.stripIconSize, height: NotchGeometry.stripIconSize)
                        .background(Circle().fill(.ultraThinMaterial))
                        .background(Circle().fill(Color.black.opacity(hovered == feature ? 0.35 : 0.15)))
                        .overlay(Circle().stroke(Color.white.opacity(hovered == feature ? 0.5 : 0.22), lineWidth: 1))
                        .scaleEffect(hovered == feature ? 1.1 : 1)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(feature.title)
                .onHover { inside in
                    withAnimation(.easeOut(duration: 0.12)) {
                        if inside {
                            hovered = feature
                        } else if hovered == feature {
                            hovered = nil
                        }
                    }
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
