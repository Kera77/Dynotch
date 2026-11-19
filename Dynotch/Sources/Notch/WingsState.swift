import SwiftUI

/// What the Wings' content asks of the panel (spec PV-16…PV-18).
struct WingsState: Equatable, Sendable {
    /// Stats: the wings reach the display's edges to list every device (spec PV-16).
    var isWide = false
    /// Reminders: the task drop-down hangs under the wings (spec PV-18).
    var dropHeight: CGFloat = 0
    /// Notifications: the app the pointer is on; nil: the newest (spec PV-17).
    var hoveredApp: String?
    /// Widened: the furthest the pointer went from the notch's middle.
    var furthest: CGFloat = 0
    /// The pointer is on the drop-down.
    var isOnDrop = false

    mutating func closeDrop() {
        dropHeight = 0
        isOnDrop = false
    }
}

extension NotchGeometry {
    /// The Wings' size: as wide as the content wants (spec PV-8), the display's width while
    /// widened (spec PV-16), taller by a drop-down under it (spec PV-18).
    func wingsSize(side: CGFloat, state: WingsState) -> CGSize {
        let base = previewSize(side: side)
        let width = state.isWide ? maxModuleSize.width : base.width
        return CGSize(width: width, height: base.height + state.dropHeight)
    }

    /// How much content one side holds before the wings would pass two thirds of the display (spec PV-4).
    var wingsMaxContent: CGFloat {
        max((screenFrame.width * 2 / 3 - notchSize.width) / 2 - 2 * WingsLayout.padding, 0)
    }
}

extension View {
    /// The wings at the notch's height with a drop-down under them (spec PV-18).
    func wingsFrame<Drop: View>(_ size: CGSize, drop: CGFloat, @ViewBuilder dropDown: () -> Drop) -> some View {
        frame(width: size.width, height: size.height - drop)
            .frame(height: size.height, alignment: .top)
            .overlay(alignment: .bottom) { dropDown() }
    }
}

enum WingsLayout {
    /// The same inset as the wings' own (spec PV-8).
    static let padding: CGFloat = 14
}

/// A line that runs from right to left when it does not fit (spec PV-20): it waits a second,
/// runs to its end, rests two seconds, then starts again. With Reduce motion it ends in "…".
struct WingsMarquee: View {
    let text: String
    var bold = false
    var dim = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var natural: CGFloat = 0
    @State private var shown: CGFloat = 0
    @State private var offset: CGFloat = 0

    /// Points per second.
    private static let speed: Double = 32

    var body: some View {
        if reduceMotion {
            WingText(text, bold: bold, dim: dim)
        } else {
            WingText(text, bold: bold, dim: dim)
                .fixedSize()
                .readWidth($natural)
                .offset(x: offset)
                .frame(minWidth: 0, idealWidth: natural, maxWidth: max(natural, 1), alignment: .leading)
                .readWidth($shown)
                .clipped()
                .task(id: "\(text)|\(Int(natural))|\(Int(shown))") { await run() }
        }
    }

    private func run() async {
        offset = 0
        let overflow = natural - shown
        guard overflow > 2, shown > 0 else { return }
        let duration = Double(overflow) / Self.speed
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: duration)) { offset = -overflow }
            try? await Task.sleep(for: .seconds(duration + 2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { offset = 0 }
            try? await Task.sleep(for: .seconds(0.25))
        }
    }
}
