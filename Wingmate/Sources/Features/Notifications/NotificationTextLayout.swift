import AppKit

/// Measures message texts, so the pop-up and the hovered card open exactly as far as their text
/// needs (spec E-22, E-23).
enum NotificationTextLayout {
    /// The pop-up's width when it shows messages.
    static let peekWidth: CGFloat = 420
    /// Text width in the pop-up: the width without the icon column and the margins.
    static let peekTextWidth: CGFloat = peekWidth - 2 * 14 - 22
    /// Text width in the hovered card (460 wide): margins, time and the reply arrow.
    static let stackTextWidth: CGFloat = 460 - 50 - 14 - 20 - 40 - 26
    /// The hovered card grows to this at most, then scrolls.
    static let maxStackHeight: CGFloat = 520
    /// The pop-up grows to this at most; the newest messages show.
    static let maxPeekTextHeight: CGFloat = 220

    /// Height of `text` at `fontSize` in `width`, at most `maxLines` lines.
    nonisolated static func height(of text: String, width: CGFloat, fontSize: CGFloat, maxLines: Int? = nil) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize)
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let shown = text.isEmpty ? "—" : text
        let rect = (shown as NSString).boundingRect(
            with: NSSize(width: max(width, 40), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let full = max(ceil(rect.height), lineHeight)
        guard let maxLines else { return full }
        return min(full, CGFloat(maxLines) * lineHeight)
    }

    /// The pop-up's height with messages: the notch, the sender row, the texts, the margins.
    nonisolated static func peekHeight(texts: [String], notchHeight: CGFloat, maxLines: Int) -> CGFloat {
        let textHeight = texts.reduce(CGFloat(0)) { sum, text in
            sum + height(of: text, width: peekTextWidth, fontSize: 12, maxLines: maxLines) + 4
        }
        return notchHeight + 24 + min(textHeight, maxPeekTextHeight) + 10
    }

    /// The hovered card's height: header, every message in full, the reply row; scrolls above the
    /// limit.
    nonisolated static func stackHeight(texts: [String], notchHeight: CGFloat) -> CGFloat {
        let rows = texts.reduce(CGFloat(0)) { sum, text in
            sum + height(of: text, width: stackTextWidth, fontSize: 13) + 12 + 4
        }
        let total = notchHeight + NotchGeometry.notificationHeaderHeight + rows + 10 + NotchGeometry.notificationReplyHeight
        return min(total, maxStackHeight)
    }
}
