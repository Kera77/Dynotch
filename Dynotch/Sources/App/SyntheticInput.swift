import AppKit

/// Key presses Dynotch sends to the app in front, and the pasteboard around them (spec RF-5, RF-18).
@MainActor
enum SyntheticInput {
    enum Key {
        static let letterV: CGKeyCode = 0x09
        static let letterK: CGKeyCode = 0x28
        static let returnKey: CGKeyCode = 0x24
        static let escape: CGKeyCode = 0x35
    }

    /// Marks a copy no clipboard manager keeps (nspasteboard.org); Dynotch's own skips it too.
    nonisolated static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    static func press(_ key: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }

    /// ⌘V.
    static func paste() {
        press(Key.letterV, flags: .maskCommand)
    }

    /// Puts text on the pasteboard. `transient`: only to be pasted by Dynotch, not kept in any
    /// clipboard history. Text the user is to paste by hand is not transient.
    static func put(_ text: String, transient: Bool) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
        if transient { board.setData(Data(), forType: transientType) }
    }

    /// Everything on the pasteboard (every item, every type: text, images, files), to put back
    /// after a paste (spec RF-5).
    @MainActor
    struct Snapshot {
        fileprivate let items: [[NSPasteboard.PasteboardType: Data]]

        var isEmpty: Bool { items.isEmpty }

        static func take() -> Snapshot {
            let items = (NSPasteboard.general.pasteboardItems ?? []).map { item in
                Dictionary(item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }) { first, _ in first }
            }
            return Snapshot(items: items.filter { !$0.isEmpty })
        }

        /// Puts it back, marked transient so clipboard managers do not list it a second time.
        func restore() {
            guard !items.isEmpty else { return }
            let board = NSPasteboard.general
            board.clearContents()
            let restored = items.enumerated().map { index, types in
                let item = NSPasteboardItem()
                for (type, data) in types { item.setData(data, forType: type) }
                if index == 0 { item.setData(Data(), forType: SyntheticInput.transientType) }
                return item
            }
            board.writeObjects(restored)
        }
    }
}
