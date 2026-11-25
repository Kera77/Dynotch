import AppKit

/// Dynotch has no visible menu bar, but text fields only get Cut, Copy, Paste, Select All and
/// Undo through the main menu's key equivalents: this invisible menu provides them.
@MainActor
enum EditMenu {
    static func make() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu(title: "Wingmate")
        main.addItem(appItem)

        let edit = NSMenu(title: "Edit")
        edit.addItem(item("Undo", #selector(UndoManager.undo), "z"))
        edit.addItem(item("Redo", #selector(UndoManager.redo), "z", [.command, .shift]))
        edit.addItem(.separator())
        edit.addItem(item("Cut", #selector(NSText.cut(_:)), "x"))
        edit.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        edit.addItem(item("Paste", #selector(NSText.paste(_:)), "v"))
        edit.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
        let editItem = NSMenuItem()
        editItem.submenu = edit
        main.addItem(editItem)
        return main
    }

    private static func item(
        _ title: String, _ action: Selector, _ key: String, _ modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }
}
