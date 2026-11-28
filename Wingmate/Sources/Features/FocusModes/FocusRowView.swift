import AppKit

/// A row of the Focus list (spec FC-5, FC-6, FC-9): a Focus (tick, its coloured icon, its name
/// and a chevron), one of its lengths, or a plain command. Every row is drawn by Wingmate, so the
/// whole list highlights alike: a faint grey, following the menu's own highlight at once.
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
    private static let focusTextX: CGFloat = 46
    private static let lengthTextX: CGFloat = 62
    private static let commandTextX: CGFloat = 18

    private let title: String
    private let kind: Kind
    private let action: () -> Void
    var isExpanded = false { didSet { needsDisplay = true } }

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
        setAccessibilityRole(.menuItem)
        if case .focus(_, true) = kind {
            setAccessibilityLabel("\(title), on")
        } else {
            setAccessibilityLabel(title)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private var closesMenu: Bool {
        if case .focus = kind { return false }
        return true
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

    override func draw(_ dirtyRect: NSRect) {
        // The menu sets the highlight as the pointer moves and redraws the row straight away.
        if enclosingMenuItem?.isHighlighted == true {
            NSColor.labelColor.withAlphaComponent(0.1).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0), xRadius: 5, yRadius: 5).fill()
        }
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
        let side: CGFloat = 16
        let scale = min(side / max(icon.size.width, 1), side / max(icon.size.height, 1), 1)
        let size = NSSize(width: icon.size.width * scale, height: icon.size.height * scale)
        icon.draw(in: NSRect(x: 34 - size.width / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height))
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
