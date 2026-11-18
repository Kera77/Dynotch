import SwiftUI

/// The iPad-like resize handle at the open module's bottom right corner (spec RS-1): resting the
/// pointer in the corner shows an arc along it; dragging the arc resizes the module (the notch
/// stays centred, so it grows to both sides), and the button beside it restores the normal size.
struct ResizeCorner: View {
    @ObservedObject var model: NotchViewModel
    /// The panel's bottom corner radius, which the arc follows.
    let radius: CGFloat

    @State private var isShown = false
    @State private var isHovering = false
    @State private var showTask: Task<Void, Never>?
    @State private var startSize: CGSize?

    /// The corner that shows the handle; small, so it stays clear of the module's own buttons.
    static let hotCorner: CGFloat = 16
    static let showDelay: Duration = .milliseconds(400)

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if isShown, model.hasResizedModule {
                resetButton
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            handle
        }
        .onHover(perform: hover)
        .animation(Motion.hover, value: isShown)
        .animation(Motion.hover, value: model.hasResizedModule)
        .onDisappear { showTask?.cancel() }
    }

    private var handle: some View {
        let side = isShown ? radius + 12 : Self.hotCorner
        return ZStack(alignment: .bottomTrailing) {
            Color.clear
            if isShown {
                CornerArc(radius: radius, inset: 5)
                    .stroke(Color.white.opacity(startSize == nil ? 0.75 : 0.95), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: radius, height: radius)
                    .transition(.opacity)
            }
        }
        .frame(width: side, height: side, alignment: .bottomTrailing)
        .contentShape(Rectangle())
        .gesture(drag)
        .help("Drag to resize")
        .accessibilityLabel("Resize")
    }

    private var resetButton: some View {
        Button {
            withAnimation(NotchController.animation) { model.resetModuleSize() }
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.white.opacity(0.18)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Back to the normal size")
        .accessibilityLabel("Back to the normal size")
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                let start = startSize ?? model.openSize
                if startSize == nil {
                    startSize = start
                    isShown = true
                }
                // Centred under the notch: the corner follows the pointer when the width grows twice.
                model.resize(to: CGSize(
                    width: start.width + 2 * value.translation.width,
                    height: start.height + value.translation.height
                ))
            }
            .onEnded { _ in
                model.endResize()
                startSize = nil
                if !isHovering { isShown = false }
            }
    }

    private func hover(_ inside: Bool) {
        isHovering = inside
        showTask?.cancel()
        if inside {
            showTask = Task { @MainActor in
                try? await Task.sleep(for: Self.showDelay)
                guard !Task.isCancelled else { return }
                isShown = true
            }
        } else if startSize == nil {
            isShown = false
        }
    }
}

/// A quarter circle along the bottom right corner, `inset` inside the panel's edge.
struct CornerArc: Shape {
    let radius: CGFloat
    let inset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.maxX - radius, y: rect.maxY - radius)
        path.addArc(center: center, radius: radius - inset, startAngle: .degrees(5), endAngle: .degrees(85), clockwise: false)
        return path
    }
}
