import SwiftUI

/// What the Wings' content asks of the panel (spec PV-31…PV-35).
struct WingsState: Equatable, Sendable {
    /// Stats: the left wing widens to show every device (spec PV-31).
    var isWide = false
    /// Notifications: the app the pointer is on; nil: the newest (spec PV-32).
    var hoveredApp: String?
    /// Notifications: the pointer last moved towards the left (spec PV-32).
    var stepsLeft = false
    /// Clipboard: the item the pointer is on (spec PV-35).
    var hoveredClip: String?
    /// Clipboard: counts the pointer's comings and goings, so a late fold-back knows it is stale (spec PV-46).
    var clipMoves = 0
    /// Something was hovered: the wings only widen until they close or the module changes (spec PV-40).
    var holdsWidth = false
}

/// What outlives one opening of the Wings (spec PV-24, PV-33).
struct WingsLasting: Equatable, Sendable {
    /// What each side needs, margins included.
    var needs = WingsSides(left: 200, right: 200)
    /// Reminders ticked in the Wings, waiting to be completed (a click on the ring unticks them).
    var ticked: [String: UUID] = [:]
    /// Reminders completed from the Wings: hidden until Reminders drops them.
    var done: Set<String> = []
    /// What each side of a small notice beside the closed notch needs (spec PV-37, PV-38).
    var peekNeeds = WingsSides(left: 160, right: 230)
    /// Counts the pointer coming onto such a notice: its running line starts again (spec PV-38).
    var peekHovers = 0
}

/// The width of each wing, content and margins included (spec PV-24).
struct WingsSides: Equatable, Sendable {
    var left: CGFloat
    var right: CGFloat

    /// How far the black shape's middle moves from the notch's middle.
    var offset: CGFloat { (right - left) / 2 }
}

extension NotchGeometry {
    /// The narrowest a wing gets: its margins.
    static var wingsMinSide: CGFloat { 2 * WingsLayout.padding }

    /// Each side as wide as its content wants, at most to two thirds of the display; the left
    /// side widened for every device reaches the display's edge (spec PV-24, PV-31).
    func wingsSides(left: CGFloat, right: CGFloat, wideLeft: Bool = false) -> WingsSides {
        let notchFrame = notchRect
        let twoThirds = max((screenFrame.width * 2 / 3 - notchSize.width) / 2, Self.wingsMinSide)
        let leftLimit = wideLeft ? max(notchFrame.minX - screenFrame.minX, twoThirds) : twoThirds
        return WingsSides(
            left: min(max(left, Self.wingsMinSide), leftLimit),
            right: min(max(right, Self.wingsMinSide), twoThirds)
        )
    }

    /// The Wings' size at the notch's height (spec PV-24).
    func wingsSize(_ sides: WingsSides) -> CGSize {
        CGSize(width: notchSize.width + sides.left + sides.right, height: notchSize.height)
    }
}

// MARK: - DyNotch Wings sides (spec PV-24)

extension NotchViewModel {
    /// Each wing's width as shown.
    var wingsSides: WingsSides {
        geometry.wingsSides(left: wingsLasting.needs.left, right: wingsLasting.needs.right, wideLeft: wings.isWide)
    }

    /// Each side of a small notice beside the closed notch (spec PV-37, PV-38).
    var peekSides: WingsSides {
        geometry.wingsSides(left: wingsLasting.peekNeeds.left, right: wingsLasting.peekNeeds.right)
    }

    /// How far the open panel's middle moves from the notch's: only the Wings are asymmetric.
    var openOffset: CGFloat {
        isExpanded && isPreview && !isShowingDropZone ? wingsSides.offset : 0
    }

    /// The open panel on the display, the Wings' asymmetry included.
    var openRect: CGRect {
        geometry.rect(for: openSize).offsetBy(dx: openOffset, dy: 0)
    }
}

enum WingsLayout {
    /// The same inset as the wings' own (spec PV-8).
    static let padding: CGFloat = 14
}

/// A line that runs from right to left when it does not fit (spec PV-20, PV-34): it waits a
/// second, runs to its end, rests two seconds, then starts again (or stays at its end). With Reduce motion it ends in "…".
struct WingsMarquee: View {
    let text: String
    var bold = false
    var dim = false
    /// false: runs once and stays at its end (spec PV-34).
    var repeats = true

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
                .frame(
                    // Not measured yet: as wide as the text, never zero, so it always shows (spec PV-51).
                    minWidth: 0, idealWidth: natural > 0 ? natural : nil, maxWidth: natural > 0 ? natural : .infinity,
                    alignment: .leading
                )
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
            guard repeats else { return }
            try? await Task.sleep(for: .seconds(duration + 2))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.quick) { offset = 0 }
            try? await Task.sleep(for: .seconds(0.25))
        }
    }
}
