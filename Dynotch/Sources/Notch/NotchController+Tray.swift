import AppKit
import SwiftUI

/// Notices a drag that carries files, from the drag pasteboard (spec FT-1).
@MainActor
final class FileDragWatcher {
    static let shared = FileDragWatcher()

    private var countAtPress = NSPasteboard(name: .drag).changeCount
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.countAtPress = NSPasteboard(name: .drag).changeCount }
        }
    }

    /// The left button is down and a drag with files started after it went down.
    var isDraggingFiles: Bool {
        guard NSEvent.pressedMouseButtons & 1 == 1 else { return false }
        let board = NSPasteboard(name: .drag)
        return board.changeCount != countAtPress && board.types?.contains(.fileURL) == true
    }
}

// MARK: - File tray (spec FT-1…FT-3)

extension NotchController {
    /// Files dragged onto the closed notch open it as a drop zone.
    func handleFileDrag(at point: CGPoint) -> Bool {
        guard !model.isExpanded, !callIsShown, !model.isHiddenForFullScreen, FileDragWatcher.shared.isDraggingFiles,
              hoverZone.insetBy(dx: -20, dy: -10).contains(point)
        else { return false }
        hideStrip()
        expand()
        withAnimation(Self.animation) { model.setDropZone(true) }
        return true
    }

    /// "Keep in Tray": the tray module shows them, if it is on (spec FT-2).
    func keepInTray(_ urls: [URL]) {
        tray.add(urls)
        withAnimation(Self.animation) { model.setDropZone(false) }
        if settings.isEnabled(.tray) {
            withAnimation(Self.animation) { model.select(.tray) }
        } else {
            collapse()
        }
    }

    /// "AirDrop": the system's AirDrop window, as usual (spec FT-3).
    func sendWithAirDrop(_ urls: [URL]) {
        collapse()
        guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else {
            DiagnosticsLog.append("tray", "AirDrop not available")
            return
        }
        service.perform(withItems: urls)
    }

    /// The drag left without a drop: the drop zone goes.
    func endDropZoneIfDragEnded() {
        guard model.isShowingDropZone, !FileDragWatcher.shared.isDraggingFiles, NSEvent.pressedMouseButtons == 0 else { return }
        collapse()
    }
}

// MARK: - Clipboard picker (spec CB-3)

extension NotchController {
    func showClipboardPicker() {
        guard !callIsShown else { return }
        hideStrip()
        if !model.isExpanded { expand() }
        isHeldOpen = true
        withAnimation(Self.animation) { model.setClipboardPicker(true) }
    }

    func hideClipboardPicker() {
        withAnimation(Self.animation) { model.setClipboardPicker(false) }
        collapse()
    }
}

// MARK: - Device notices (spec DV-4, DV-6)

extension NotchController {
    /// Over a device notice: its buttons take clicks; without buttons the batteries open.
    func handleDevicePeek(at point: CGPoint) -> Bool {
        guard !model.isExpanded, notifications.peek == nil, let event = devices.current,
              model.geometry.keepOpenZone(for: model.geometry.peekSize).contains(point)
        else {
            if devices.current != nil, !model.isExpanded, model.hoveredIndicator == nil, model.hoveredBadge == nil {
                panel.ignoresMouseEvents = true
            }
            return false
        }
        if event.actions.isEmpty, event.category == .bluetooth, settings.isEnabled(.battery) {
            devices.dismiss()
            expand()
            withAnimation(Self.animation) { model.select(.battery) }
        } else {
            panel.ignoresMouseEvents = false
            startHoverTimer()
        }
        return true
    }
}

// MARK: - Beeper badge (spec BP-12)

extension NotchController {
    /// A click on Beeper's badge: the notch opens on the Beeper tab instead of the app.
    func openBeeperTab() {
        setHoveredBadge(nil)
        if !model.isExpanded { expand() }
        withAnimation(Self.animation) {
            model.notificationsTab = .beeper
            model.select(.notifications)
        }
    }
}
