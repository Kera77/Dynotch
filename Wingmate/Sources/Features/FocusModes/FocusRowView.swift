import AppKit

/// A Focus row of the Focus list (spec FC-5, FC-6): tick, the Focus's coloured icon, its name and
/// a chevron. A click drops its lengths down under it; the list stays open, because a menu item
/// with its own view handles the click itself.
@MainActor
final class FocusRowView: NSView {
    static let height: CGFloat = 24
    private static let font = NSFont.menuFont(ofSize: 0)
    private static let textX: CGFloat = 46

    private let title: String
    private let icon: NSImage?
    private let isOn: Bool
    private let action: () -> Void
    private var isHovered = false { didSet { needsDisplay = true } }
    var isExpanded = false { didSet { needsDisplay = true } }

    /// Wide enough for the longest name, the icon and the chevron.
    static func width(for titles: [String]) -> CGFloat {
        let widest = titles.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return max(220, ceil(widest) + textX + 40)
    }

    init(title: String, icon: NSImage?, isOn: Bool, width: CGFloat, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isOn = isOn
        self.action = action
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.height))
        autoresizingMask = [.width]
        setAccessibilityRole(.menuItem)
        setAccessibilityLabel(isOn ? "\(title), on" : title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        action()
    }

    override func accessibilityPerformPress() -> Bool {
        action()
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = isHovered
        if highlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0), xRadius: 5, yRadius: 5).fill()
        }
        let textColor: NSColor = highlighted ? .white : .labelColor
        if isOn { drawSymbol("checkmark", color: textColor, size: 11, centeredAt: 18) }
        if let icon {
            let side: CGFloat = 16
            let scale = min(side / max(icon.size.width, 1), side / max(icon.size.height, 1), 1)
            let size = NSSize(width: icon.size.width * scale, height: icon.size.height * scale)
            icon.draw(in: NSRect(x: 34 - size.width / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height))
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: textColor]
        let textSize = (title as NSString).size(withAttributes: attributes)
        let textWidth = bounds.width - Self.textX - 30
        (title as NSString).draw(
            with: NSRect(x: Self.textX, y: (bounds.height - textSize.height) / 2, width: textWidth, height: textSize.height),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes
        )
        let chevron = isExpanded ? "chevron.down" : "chevron.right"
        drawSymbol(chevron, color: highlighted ? .white : .secondaryLabelColor, size: 9, centeredAt: bounds.width - 20)
    }

    private func drawSymbol(_ name: String, color: NSColor, size: CGFloat, centeredAt x: CGFloat) {
        let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .semibold)
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
        else { return }
        let rect = NSRect(
            x: x - symbol.size.width / 2, y: (bounds.height - symbol.size.height) / 2,
            width: symbol.size.width, height: symbol.size.height
        )
        NSGraphicsContext.saveGraphicsState()
        symbol.draw(in: rect)
        color.set()
        rect.fill(using: .sourceAtop)
        NSGraphicsContext.restoreGraphicsState()
    }
}
