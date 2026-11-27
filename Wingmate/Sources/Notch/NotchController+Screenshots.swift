import AppKit
import SwiftUI

// MARK: - Screenshot editor (spec SH-6, SH-7, SH-11)

extension NotchController {
    /// Over the pop-up of a shot just made, the notch opens with the editor.
    func handleScreenshotPeek(at point: CGPoint) -> Bool {
        guard !model.isExpanded, let shot = screenshots.peek, !shot.isVideo,
              model.geometry.keepOpenZone(for: model.geometry.peekSize).contains(point)
        else { return false }
        openScreenshotEditor(shot.url, fromPeek: true)
        return true
    }

    func openScreenshotEditor(_ url: URL, fromPeek: Bool) {
        guard ScreenshotFiles.isEditable(url), let editor = ScreenshotEditor(url: url, tools: screenshots.settings.tools) else {
            NSWorkspace.shared.open(url)
            return
        }
        screenshots.clearPeek()
        hideStrip()
        setHoveredIndicator(nil)
        setHoveredBadge(nil)
        if !model.isExpanded { expand() }
        withAnimation(Self.animation) { model.setEditor(editor, closesNotch: fromPeek || !model.isExpanded) }
        // The editor types text and takes ⌘Z: the panel needs the keyboard.
        panel.allowsKey = true
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != getpid() {
            model.appBeforeEditor = front
        }
        NSApp.activate()
        panel.makeKey()
    }

    func closeScreenshotEditor() {
        let closesNotch = model.editorClosesNotch
        withAnimation(Self.animation) { model.setEditor(nil) }
        if closesNotch { collapse() }
        // The app from before gets the keyboard back for real; otherwise its caret blinks but
        // typing only beeps until it is clicked (spec SH-7b).
        let before = model.appBeforeEditor
        model.appBeforeEditor = nil
        if closesNotch || !model.wantsKeyboard {
            panel.makeFirstResponder(nil)
            panel.allowsKey = model.wantsKeyboard && model.isExpanded
            panel.resignKey()
            if let before, !before.isTerminated {
                before.activate()
            } else {
                NSApp.deactivate()
            }
        }
    }
}
