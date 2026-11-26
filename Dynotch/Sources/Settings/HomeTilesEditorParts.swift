import AppKit
import SwiftUI

/// A tile in the small Home: icon, name; × on hover, a red minus while dragged out (spec HT-22, HT-31).
struct PreviewTile: View {
    let tile: HomeTile
    let isRemoving: Bool
    let remove: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: tile.feature.symbolName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(tile.title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).fill(Color.secondary.opacity(0.22)))
        .opacity(isRemoving ? 0.4 : 1)
        .overlay {
            if isRemoving {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Drop outside the Home to remove \(tile.title)")
            }
        }
        .overlay(alignment: .topTrailing) {
            if isHovered, !isRemoving {
                Button(action: remove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(3)
                .help("Remove \(tile.title) from the Home")
                .accessibilityLabel("Remove \(tile.title)")
            }
        }
        .animation(Motion.quick, value: isRemoving)
        .onHover { isHovered = $0 }
    }
}

/// A tile in the catalog: name, size and a + that turns green on hover; ticked and dimmed when on the
/// Home (spec HT-21, HT-32).
struct CatalogChip: View {
    let tile: HomeTile
    let isAdded: Bool
    let add: () -> Void

    @State private var isPlusHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Text(tile.title)
                .lineLimit(1)
            Text(tile.size.label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if isAdded {
                Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            } else {
                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(isPlusHovered ? Color.green : Color.secondary)
                        .frame(width: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isPlusHovered = $0 }
                .animation(Motion.quick, value: isPlusHovered)
                .help("Add \(tile.title) to the Home")
                .accessibilityLabel("Add \(tile.title) to the Home")
            }
        }
        .font(.caption)
        .padding(.leading, 8)
        .padding(.trailing, 5)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous).fill(Color.secondary.opacity(0.14)))
        .opacity(isAdded ? 0.55 : 1)
        .help(isAdded ? "\(tile.title) is on the Home" : "Drag onto the Home, click + or double-click to add")
    }
}

/// Over the catalog while a Home tile is dragged out: dropping removes it (spec HT-31).
struct RemoveBanner: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
            .fill(Color.red.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .overlay {
                Label("Drop to remove", systemImage: "minus.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.red)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}

/// Chains the catalog's scrolling to the settings' (spec HT-33): while the editor's block is not
/// fully in view the settings scroll, and stop where it fits; then the catalog scrolls to its end,
/// and only then the settings go on. Also reports the settings' visible height.
struct ScrollChain: NSViewRepresentable {
    let viewport: (CGFloat) -> Void

    func makeNSView(context: Context) -> ChainView {
        let view = ChainView()
        view.viewport = viewport
        return view
    }

    func updateNSView(_ view: ChainView, context: Context) {
        view.viewport = viewport
    }

    static func dismantleNSView(_ view: ChainView, coordinator: ()) {
        view.stop()
    }
}

/// Lives inside the catalog's scroll view; watches the scroll events of its window.
final class ChainView: NSView {
    var viewport: ((CGFloat) -> Void)?
    private var monitor: Any?
    private var lastHeight: CGFloat = 0

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stop()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated { self?.route(event) ?? true } ? event : nil
        }
        reportHeight()
    }

    override func layout() {
        super.layout()
        reportHeight()
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private var inner: NSScrollView? { enclosingScrollView }
    private var outer: NSScrollView? { inner?.superview?.enclosingScrollView }

    private func reportHeight() {
        guard let height = outer?.contentView.bounds.height, abs(height - lastHeight) > 0.5 else { return }
        lastHeight = height
        let viewport = viewport
        DispatchQueue.main.async { viewport?(height) }
    }

    /// True: the event goes on as usual; false: it was handed to one of the scroll views here.
    private func route(_ event: NSEvent) -> Bool {
        guard let inner, let outer, event.window === window, event.scrollingDeltaY != 0,
              abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX)
        else { return true }
        let visible = outer.contentView.convert(outer.contentView.bounds, to: nil)
        guard visible.contains(event.locationInWindow) else { return true }
        let block = inner.convert(inner.bounds, to: nil)
        let fits = block.minY >= visible.minY - 1 && block.maxY <= visible.maxY + 1
        let pageDown = event.scrollingDeltaY < 0
        let innerCanMove = pageDown ? !Self.isAtEnd(inner) : !Self.isAtStart(inner)
        if fits, innerCanMove {
            inner.scrollWheel(with: event)
            return false
        }
        let overInner = block.contains(event.locationInWindow)
        // Not yet in view, or at the catalog's end: the settings scroll.
        guard pageDown, !Self.isAtEnd(inner), block.minY < visible.minY else {
            if overInner { outer.scrollWheel(with: event) }
            return !overInner
        }
        outer.scrollWheel(with: event)
        stopWhereItFits(outer: outer, inner: inner)
        return false
    }

    /// Scrolled past the place where the block fits: back to it, so the settings stop there.
    private func stopWhereItFits(outer: NSScrollView, inner: NSScrollView) {
        let visible = outer.contentView.convert(outer.contentView.bounds, to: nil)
        let block = inner.convert(inner.bounds, to: nil)
        let overshoot = block.minY - visible.minY
        guard overshoot > 0 else { return }
        let clip = outer.contentView
        var origin = clip.bounds.origin
        origin.y += (outer.documentView?.isFlipped ?? true) ? -overshoot : overshoot
        clip.scroll(to: origin)
        outer.reflectScrolledClipView(clip)
    }

    private static func isAtStart(_ scrollView: NSScrollView) -> Bool {
        guard let document = scrollView.documentView else { return true }
        let shown = scrollView.contentView.documentVisibleRect
        return document.isFlipped ? shown.minY <= document.bounds.minY + 1 : shown.maxY >= document.bounds.maxY - 1
    }

    private static func isAtEnd(_ scrollView: NSScrollView) -> Bool {
        guard let document = scrollView.documentView else { return true }
        let shown = scrollView.contentView.documentVisibleRect
        return document.isFlipped ? shown.maxY >= document.bounds.maxY - 1 : shown.minY <= document.bounds.minY + 1
    }
}
