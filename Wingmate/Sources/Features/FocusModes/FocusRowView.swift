import AppKit
import QuartzCore

/// A row of the Focus list (spec FC-5, FC-6, FC-9, FC-10): a Focus (tick, its coloured icon, its
/// name and a chevron), one of its lengths, or a plain command. Every row is drawn by Wingmate, so
/// the whole list highlights alike: a faint grey that follows the pointer through the row's own
/// tracking area. The highlight is a layer switched on and flushed at once, so it never waits for
/// the menu's late highlight or a redraw (spec FC-10).
@MainActor
final class FocusRowView: NSView {
    enum Kind {
        /// A Focus: a click drops its lengths down under it and the list stays open.
        case focus(icon: NSImage?, isOn: Bool)
        /// A length under the opened Focus: a click closes the list.
        case length
        /// "Turn off …", "Focus Settings…": a click closes the list.
        case command
    }

    static let height: CGFloat = 24
    private static let font = NSFont.menuFont(ofSize: 0)
    private static let focusTextX: CGFloat = 52
    /// The round icon badge of a Focus row (spec FC-12).
    static let badgeSide: CGFloat = 20
    private static let lengthTextX: CGFloat = 62
    private static let commandTextX: CGFloat = 18

    /// The one highlighted row of the open list.
    private(set) static weak var hovered: FocusRowView?

    private let title: String
    private let kind: Kind
    private let action: () -> Void
    private let highlight = Highlight()
    private lazy var canvas = Canvas(row: self)
    var isExpanded = false { didSet { canvas.needsDisplay = true } }
    var isHovered: Bool { Self.hovered === self }

    /// Wide enough for the longest title, the icon and the chevron.
    static func width(for titles: [String]) -> CGFloat {
        let widest = titles.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return max(220, ceil(widest) + lengthTextX + 40)
    }

    init(title: String, kind: Kind, width: CGFloat, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.action = action
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.height))
        autoresizingMask = [.width]
        wantsLayer = true
        highlight.frame = bounds.insetBy(dx: 5, dy: 0)
        highlight.autoresizingMask = [.width, .height]
        highlight.wantsLayer = true
        highlight.layer?.cornerRadius = 5
        highlight.isHidden = true
        addSubview(highlight)
        canvas.frame = bounds
        canvas.autoresizingMask = [.width, .height]
        addSubview(canvas)
        setAccessibilityRole(.menuItem)
        if case .focus(_, true) = kind {
            setAccessibilityLabel("\(title), on")
        } else {
            setAccessibilityLabel(title)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Highlights this row (or none) and puts it on screen straight away (spec FC-10).
    static func hover(_ row: FocusRowView?) {
        guard hovered !== row else { return }
        let previous = hovered
        hovered = row
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previous?.showHighlight(false)
        row?.showHighlight(true)
        CATransaction.commit()
        CATransaction.flush()
    }

    /// The row under the pointer, after rows moved under a still pointer (lengths dropping down).
    static func syncHover(in window: NSWindow?) {
        guard let window, let content = window.contentView else { return }
        var view = content.hitTest(window.convertPoint(fromScreen: NSEvent.mouseLocation))
        while let current = view, !(current is FocusRowView) { view = current.superview }
        hover(view as? FocusRowView)
    }

    private func showHighlight(_ isOn: Bool) {
        highlight.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.1).cgColor
        highlight.isHidden = !isOn
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) { Self.hover(self) }
    override func mouseMoved(with event: NSEvent) { Self.hover(self) }
    override func mouseExited(with event: NSEvent) {
        if isHovered { Self.hover(nil) }
    }

    private var closesMenu: Bool {
        if case .focus = kind { return false }
        return true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil, isHovered { Self.hovered = nil }
    }

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        press()
    }

    override func accessibilityPerformPress() -> Bool {
        press()
        return true
    }

    private func press() {
        guard closesMenu else { return action() }
        // As with a native item, the choice runs once the list has closed.
        enclosingMenuItem?.menu?.cancelTracking()
        let action = action
        DispatchQueue.main.async { action() }
    }

    /// The row's tick, icon, title and chevron, drawn above the highlight layer.
    fileprivate func drawContent() {
        let textX: CGFloat
        switch kind {
        case let .focus(icon, isOn):
            textX = Self.focusTextX
            if isOn { drawSymbol("checkmark", color: .labelColor, size: 11, centeredAt: 18) }
            if let icon { drawIcon(icon) }
            drawSymbol(
                isExpanded ? "chevron.down" : "chevron.right",
                color: .secondaryLabelColor, size: 9, centeredAt: bounds.width - 20
            )
        case .length:
            textX = Self.lengthTextX
        case .command:
            textX = Self.commandTextX
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: NSColor.labelColor]
        let textSize = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(
            with: NSRect(x: textX, y: (bounds.height - textSize.height) / 2, width: bounds.width - textX - 30, height: textSize.height),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes
        )
    }

    private func drawIcon(_ icon: NSImage) {
        let side = Self.badgeSide
        let scale = min(side / max(icon.size.width, 1), side / max(icon.size.height, 1), 1)
        let size = NSSize(width: icon.size.width * scale, height: icon.size.height * scale)
        icon.draw(in: NSRect(x: 37 - size.width / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height))
    }

    /// The symbol tinted through its own palette, so only its shape is coloured (a fill over the
    /// row would paint the whole symbol rectangle on a highlighted row).
    private func drawSymbol(_ name: String, color: NSColor, size: CGFloat, centeredAt x: CGFloat) {
        let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
        else { return }
        symbol.draw(in: NSRect(
            x: x - symbol.size.width / 2, y: (bounds.height - symbol.size.height) / 2,
            width: symbol.size.width, height: symbol.size.height
        ))
    }
}

/// Draws the row's content above its highlight (spec FC-10).
@MainActor
private final class Canvas: NSView {
    private unowned let row: FocusRowView

    init(row: FocusRowView) {
        self.row = row
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) { row.drawContent() }
}

/// The row's faint grey highlight; clicks go through it to the row.
@MainActor
private final class Highlight: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
