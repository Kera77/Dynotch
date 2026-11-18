import AppKit
import SwiftUI

/// A scrolling capture (spec SH-4): after the area is picked, a frame marks it and you scroll
/// by hand; Dynotch takes a picture a few times a second and joins them. Done (or the shortcut)
/// finishes, Esc cancels.
@MainActor
final class ScrollCapture {
    private let rect: CGRect
    private let screen: NSScreen
    private var frameWindow: NSWindow?
    private var controls: NSPanel?
    private var timer: Timer?
    private var first: CGImage?
    private var last: (image: CGImage, rows: [Double])?
    private var additions: [(image: CGImage, rows: Int)] = []
    private var isCapturing = false
    private var continuation: CheckedContinuation<CGImage?, Never>?
    private var escape: Any?

    init(rect: CGRect, screen: NSScreen) {
        self.rect = rect
        self.screen = screen
    }

    func run() async -> CGImage? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            start()
        }
    }

    /// Finishes from outside, e.g. the shortcut pressed again.
    func finish() { stop(keeping: true) }

    private func start() {
        showFrame()
        showControls()
        escape = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            MainActor.assumeIsolated { self?.stop(keeping: false) }
        }
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.grab() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        grab()
    }

    private func grab() {
        guard !isCapturing else { return }
        isCapturing = true
        Task { [weak self, rect, screen] in
            let image = await ScreenCapture.capture(rect, on: screen)
            guard let self else { return }
            self.isCapturing = false
            if let image { self.add(image) }
        }
    }

    private func add(_ image: CGImage) {
        let rows = ScrollStitcher.rowSignature(of: image)
        guard let last else {
            first = image
            self.last = (image, rows)
            return
        }
        guard let moved = ScrollStitcher.offset(previous: last.rows, next: rows), moved > 0 else { return }
        additions.append((image, moved))
        self.last = (image, rows)
    }

    private func stop(keeping: Bool) {
        guard let continuation else { return }
        self.continuation = nil
        timer?.invalidate()
        timer = nil
        escape.map(NSEvent.removeMonitor)
        escape = nil
        frameWindow?.orderOut(nil)
        controls?.orderOut(nil)
        let result = keeping ? first.flatMap { ScrollStitcher.join($0, additions: additions) } : nil
        DiagnosticsLog.append("screenshots", "scrolling capture: \(additions.count) steps, kept=\(keeping)")
        continuation.resume(returning: result)
    }

    private func showFrame() {
        let window = NSWindow(contentRect: rect.insetBy(dx: -3, dy: -3), styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.sharingType = .none
        window.contentView = NSHostingView(rootView: RoundedRectangle(cornerRadius: 3).stroke(Theme.blue, lineWidth: 2))
        window.orderFrontRegardless()
        frameWindow = window
    }

    private func showControls() {
        let size = CGSize(width: 250, height: 40)
        let below = CGPoint(x: rect.midX - size.width / 2, y: rect.minY - size.height - 10)
        let origin = below.y > screen.visibleFrame.minY ? below : CGPoint(x: below.x, y: rect.maxY + 10)
        let panel = NSPanel(contentRect: CGRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.sharingType = .none
        panel.contentView = NSHostingView(rootView: ScrollCaptureControls(
            done: { [weak self] in self?.stop(keeping: true) }, cancel: { [weak self] in self?.stop(keeping: false) }
        ))
        panel.orderFrontRegardless()
        controls = panel
    }
}

private struct ScrollCaptureControls: View {
    let done: () -> Void
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.and.down").foregroundStyle(Theme.blue)
            Text("Scroll, then Done").font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
            Spacer(minLength: 4)
            Button("Cancel", action: cancel).buttonStyle(.plain).foregroundStyle(Color.white.opacity(0.7))
            Button("Done", action: done).buttonStyle(.plain).fontWeight(.semibold).foregroundStyle(Theme.blue)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12)
        .frame(width: 250, height: 40)
        .background(Capsule().fill(Color.black.opacity(0.85)))
    }
}
