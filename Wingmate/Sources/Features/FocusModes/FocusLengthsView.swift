import AppKit
import QuartzCore

/// The lengths of the opened Focus (spec FC-5, FC-10): one menu item that holds their rows and
/// grows from nothing to its full height, so the lengths drop down under the Focus and the rest of
/// the list slides down with them; folding runs the same movement backwards.
@MainActor
final class FocusLengthsView: NSView {
    static let duration: TimeInterval = 0.2

    let fullHeight: CGFloat
    private var timer: Timer?
    private var completion: (() -> Void)?

    override var isFlipped: Bool { true }

    init(rows: [FocusRowView], width: CGFloat) {
        fullHeight = CGFloat(rows.count) * FocusRowView.height
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 0))
        autoresizingMask = [.width]
        clipsToBounds = true
        setAccessibilityRole(.group)
        // Pinned to the top, so a growing frame reveals them from the Focus downwards.
        for (index, row) in rows.enumerated() {
            row.frame.origin = NSPoint(x: 0, y: CGFloat(index) * FocusRowView.height)
            row.autoresizingMask = [.width, .maxYMargin]
            addSubview(row)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func unfold() { animate(to: fullHeight, then: nil) }

    func fold(then completion: @escaping () -> Void) { animate(to: 0, then: completion) }

    /// The eased height `progress` (0…1) of the way between `start` and `target`: easing out on
    /// the way down, easing in on the way back up, so folding is unfolding reversed.
    nonisolated static func height(from start: CGFloat, to target: CGFloat, progress: Double) -> CGFloat {
        let time = min(max(progress, 0), 1)
        let eased = target > start ? 1 - pow(1 - time, 3) : pow(time, 3)
        return start + (target - start) * CGFloat(eased)
    }

    private func animate(to target: CGFloat, then completion: (() -> Void)?) {
        timer?.invalidate()
        self.completion?()
        self.completion = completion
        let start = frame.height
        // A part-way fold or unfold turns around from where it is, at the matching speed.
        let duration = Self.duration * Double(abs(target - start) / max(fullHeight, 1))
        guard !AppleStyle.reducesMotion, duration > 0.01 else {
            return finish(at: target)
        }
        let began = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] timer in
            guard self != nil else { return timer.invalidate() }
            MainActor.assumeIsolated {
                self?.step(from: start, to: target, progress: (CACurrentMediaTime() - began) / duration)
            }
        }
        // Common modes: the menu's tracking loop runs in the event-tracking mode.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func step(from start: CGFloat, to target: CGFloat, progress: Double) {
        if progress >= 1 {
            finish(at: target)
        } else {
            setHeight(Self.height(from: start, to: target, progress: progress))
        }
    }

    private func finish(at height: CGFloat) {
        timer?.invalidate()
        timer = nil
        setHeight(height)
        let completion = completion
        self.completion = nil
        completion?()
    }

    private func setHeight(_ height: CGFloat) {
        setFrameSize(NSSize(width: frame.width, height: height))
        // The menu lays its items out again and moves the rows below.
        if let item = enclosingMenuItem { item.menu?.itemChanged(item) }
        FocusRowView.syncHover(in: window)
    }
}
