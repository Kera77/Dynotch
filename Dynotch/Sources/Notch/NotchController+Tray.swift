import AppKit
import SwiftUI

/// Notices a drag that carries files, from the drag pasteboard (spec FT-1).
@MainActor
final class FileDragWatcher {
    static let shared = FileDragWatcher()

    private var countAtPress = NSPasteboard(name: .drag).changeCount
    private var monitor: Any?
    private var timer: Timer?
    private var observers: [() -> Void] = []

    /// Called while a button is held, a few times a second: a drag sends no mouse events to
    /// other apps' monitors, so the notches look at the pointer themselves (spec FT-1).
    func observe(_ tick: @escaping () -> Void) {
        observers.append(tick)
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.pressed() }
        }
    }

    private func pressed() {
        countAtPress = NSPasteboard(name: .drag).changeCount
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        observers.forEach { $0() }
        if NSEvent.pressedMouseButtons & 1 == 0 {
            timer?.invalidate()
            timer = nil
            // Once more after the release, so a drop zone left without a drop closes.
            observers.forEach { $0() }
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
        // In Wings mode the notch only spreads to the sides: tray left, AirDrop right (spec PV-14).
        expand(preview: settings.hoverPreview)
        DiagnosticsLog.append("tray", "drop zone")
        withAnimation(Self.animation) { model.setDropZone(true) }
        return true
    }

    /// "Keep in Tray": the tray module shows them, if it is on (spec FT-2).
    func keepInTray(_ urls: [URL]) {
        // The drop finishes first; changing the panel inside it left the system's drag hanging.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            tray.add(urls)
            let inWings = model.isPreview
            withAnimation(Self.animation) { model.setDropZone(false) }
            if settings.isEnabled(.tray) {
                // Dropped on the wings: the wings show the tray (spec PV-14).
                withAnimation(Self.animation) {
                    model.select(.tray)
                    if inWings { model.setPreview(true) }
                }
            } else {
                collapse()
            }
        }
    }

    /// "AirDrop": the system's AirDrop window, as usual (spec FT-3).
    /// Opened only after the drop has finished: opened inside it, the drag never ended and Finder
    /// drags and Space switching stayed stuck afterwards (spec FT-3b).
    func sendWithAirDrop(_ urls: [URL]) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.collapse()
            guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else {
                DiagnosticsLog.append("tray", "AirDrop not available")
                return
            }
            // Its window shows only for the app in front.
            NSApp.activate(ignoringOtherApps: true)
            service.perform(withItems: urls)
            DiagnosticsLog.append("tray", "AirDrop opened")
        }
    }

    /// While a file is dragged: open the drop zone over the notch, or close it when the drag ends.
    func fileDragTick() {
        if model.isShowingDropZone {
            endDropZoneIfDragEnded()
        } else if model.isExpanded {
            showDropZoneOverOpenNotch()
        } else {
            _ = handleFileDrag(at: NSEvent.mouseLocation)
        }
    }

    /// The hover opened the notch before the drag was recognised: files over it still get the
    /// drop zone, except over the tray module, which takes them itself (spec FT-13); the wings
    /// always get it (spec PV-14).
    func showDropZoneOverOpenNotch() {
        guard model.isExpanded, !model.isShowingDropZone, !model.isShowingClipboardPicker,
              model.currentFeature != .tray || model.isPreview,
              FileDragWatcher.shared.isDraggingFiles, keepOpenZone.contains(NSEvent.mouseLocation)
        else { return }
        DiagnosticsLog.append("tray", "drop zone over the open notch")
        withAnimation(Self.animation) { model.setDropZone(true) }
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
        // In the open notch the items drop down under the module, which keeps the keyboard, so
        // the choice is pasted into it (spec CB-3c).
        let inline = model.isExpanded && !model.isShowingOverlayPage && !model.isPreview
        if !model.isExpanded { expand() }
        if !inline { isHeldOpen = true }
        withAnimation(Self.animation) { model.setClipboardPicker(true, inline: inline) }
    }

    func hideClipboardPicker() {
        if model.isClipboardInline {
            withAnimation(Self.animation) { model.setClipboardPicker(false) }
            return
        }
        withAnimation(Self.animation) { model.setClipboardPicker(false) }
        collapse()
    }
}

// MARK: - Device notices (spec DV-4, DV-6)

extension NotchController {
    /// Over a device notice: its buttons take clicks; without buttons the batteries open.
    func handleDevicePeek(at point: CGPoint) -> Bool {
        guard !model.isExpanded, notifications.peek == nil, let event = devices.current,
              model.geometry.keepOpenZone(for: model.geometry.devicePeekSize).contains(point)
        else {
            deviceHoverTask?.cancel()
            deviceHoverTask = nil
            if devices.current != nil, !model.isExpanded, model.hoveredIndicator == nil, model.hoveredBadge == nil {
                panel.ignoresMouseEvents = true
            }
            return false
        }
        if event.actions.isEmpty, event.category == .bluetooth, settings.isEnabled(.battery) {
            // Resting half a second opens the batteries; a flick before that only hides it (spec DV-14).
            panel.ignoresMouseEvents = false
            guard deviceHoverTask == nil else { return true }
            deviceHoverTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled else { return }
                self.deviceHoverTask = nil
                guard self.devices.current?.id == event.id, !self.model.isExpanded,
                      self.model.geometry.keepOpenZone(for: self.model.geometry.devicePeekSize).contains(NSEvent.mouseLocation)
                else { return }
                self.devices.dismiss()
                self.expand()
                withAnimation(Self.animation) { self.model.select(.battery) }
            }
        } else {
            panel.ignoresMouseEvents = false
            startHoverTimer()
        }
        return true
    }
}

// MARK: - Chat badges (spec BP-12, GC-5)

extension NotchController {
    /// A click on Beeper's or Google Chat's badge: the notch opens on its tab instead of the app.
    func openChatTab(_ tab: NotificationsTab) {
        setHoveredBadge(nil)
        if !model.isExpanded { expand() }
        withAnimation(Self.animation) {
            model.notificationsTab = tab
            model.select(.notifications)
        }
    }
}

// MARK: - Mission Control (spec N-19)

extension NotchController {
    /// Out of the way while Mission Control shows the Spaces along the top.
    func setHiddenForMissionControl(_ hidden: Bool) {
        guard model.isHiddenForMissionControl != hidden else { return }
        model.isHiddenForMissionControl = hidden
        if hidden { collapse() }
        // Back on, the pointer logic decides about clicks again.
        if hidden { panel.ignoresMouseEvents = true }
    }
}

// MARK: - Screen sharing (spec N-21)

extension NotchController {
    /// While the screen is shared nothing pops up beside or under the notch; a notification
    /// already shown goes.
    func setScreenShared(_ shared: Bool) {
        guard model.isScreenShared != shared else { return }
        notifications.isScreenShared = shared
        if shared {
            notifications.clearPeek()
            setHoveredIndicator(nil)
            setHoveredBadge(nil)
        }
        withAnimation(Self.animation) { model.isScreenShared = shared }
    }
}

// MARK: - Window switcher (spec AS-6)

extension NotchController {
    func showSwitcher(_ switcher: SwitcherController) {
        guard !callIsShown else { return }
        hideStrip()
        let settings = switcher.settings
        let room = CGSize(width: model.geometry.windowSize.width, height: model.geometry.windowSize.height)
        let size = SwitcherLayout.size(
            count: switcher.items.count, style: settings.style, scale: settings.size.scale,
            notchHeight: model.geometry.notchSize.height, room: room
        )
        if !model.isExpanded { expand(animation: Self.switcherAnimation) }
        isHeldOpen = true
        withAnimation(Self.switcherAnimation) { model.setSwitcher(true, size: size) }
    }

    func hideSwitcher() {
        withAnimation(Self.animation) { model.setSwitcher(false) }
        collapse()
    }
}
