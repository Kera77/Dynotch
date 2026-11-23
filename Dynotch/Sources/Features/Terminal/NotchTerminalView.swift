import AppKit
import SwiftTerm

/// SwiftTerm's terminal in the notch's look: SF Mono on black, Option as Meta (spec TE-1, TE-2).
final class NotchTerminalView: LocalProcessTerminalView {
    static let scrollback = 10_000
    var onInput: (() -> Void)?

    /// ⌘K: the lines scrolled away go, as in Terminal.
    func clearScrollback() {
        let terminal = getTerminal()
        terminal.changeHistorySize(0)
        terminal.changeHistorySize(Self.scrollback)
    }

    func configure(fontSize: CGFloat) {
        font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        nativeBackgroundColor = .black
        nativeForegroundColor = NSColor(white: 0.92, alpha: 1)
        optionAsMetaKey = true
    }

    override func send(source: TerminalView, data: ArraySlice<UInt8>) {
        onInput?()
        super.send(source: source, data: data)
    }
}

/// Holds the shown tab's terminal in the panel, takes the module's ⌘ keys and pastes the paths
/// of files dropped on it (spec TE-2, TE-4, TE-7). One terminal view moves between the panels
/// of the displays, so the shell is the same everywhere.
final class TerminalContainerView: NSView {
    weak var store: TerminalStore?
    private(set) weak var terminal: NotchTerminalView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show(_ view: NotchTerminalView, focus: Bool) {
        if view.superview !== self {
            subviews.forEach { $0.removeFromSuperview() }
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            addSubview(view)
        }
        terminal = view
        if focus { takeFocus() }
    }

    func takeFocus() {
        guard let terminal, let window, window.firstResponder !== terminal else { return }
        window.makeFirstResponder(terminal)
    }

    override func layout() {
        super.layout()
        terminal?.frame = bounds
    }

    // MARK: - ⌘ keys (spec TE-2, TE-4)

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let terminal, let store, window?.firstResponder === terminal,
              event.modifierFlags.contains(.command) else { return super.performKeyEquivalent(with: event) }
        let key = event.charactersIgnoringModifiers ?? ""
        if edits(key, in: terminal) || tabs(key, shift: event.modifierFlags.contains(.shift), in: store) { return true }
        return super.performKeyEquivalent(with: event)
    }

    /// ⌘C ⌘V ⌘A ⌘K, as in Terminal.
    private func edits(_ key: String, in terminal: NotchTerminalView) -> Bool {
        switch key {
        case "c": terminal.copy(self)
        case "v": terminal.paste(self)
        case "a": terminal.selectAll(nil)
        case "k":
            terminal.clearScrollback()
            terminal.send(txt: "\u{0C}")
        default: return false
        }
        return true
    }

    /// Tabs and the font size.
    private func tabs(_ key: String, shift: Bool, in store: TerminalStore) -> Bool {
        switch key {
        case "t": store.newSession()
        case "w": store.closeSelected()
        case "=", "+": store.setFontSize(store.fontSize + 1)
        case "-": store.setFontSize(store.fontSize - 1)
        case "0": store.setFontSize(nil)
        case "{", "[" where shift: store.step(by: -1)
        case "}", "]" where shift: store.step(by: 1)
        default:
            guard let digit = Int(key), (1...9).contains(digit) else { return false }
            store.select(index: digit - 1)
        }
        return true
    }

    // MARK: - Dropped files (spec TE-7)

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        terminal == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        guard let terminal, let urls, !urls.isEmpty else { return false }
        terminal.send(txt: TerminalPaths.quoted(urls.map(\.path)) + " ")
        window?.makeKeyAndOrderFront(nil)
        takeFocus()
        return true
    }
}

enum TerminalPaths {
    /// Paths as the shell reads them: each in single quotes, separated by spaces (spec TE-7).
    static func quoted(_ paths: [String]) -> String {
        paths.map { "'" + $0.replacingOccurrences(of: "'", with: #"'\''"#) + "'" }.joined(separator: " ")
    }
}
