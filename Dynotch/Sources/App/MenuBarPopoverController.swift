import AppKit
import Combine
import SwiftUI

/// A number next to a menu bar icon (open reminders, spec R-7).
struct Badge {
    let changes: ObservableObjectPublisher
    let value: @MainActor () -> Int?
}

/// An icon that changes with data (Claude usage ring, spec CL-6). Nil image: the feature's symbol.
struct StatusIcon {
    let changes: ObservableObjectPublisher
    let image: @MainActor () -> NSImage?
    let toolTip: @MainActor () -> String?
}

/// Menu bar icon of a feature that drops a popover panel down below it
/// (calculator: spec SZ-6…SZ-8, notes: spec J-8).
@MainActor
final class MenuBarPopoverController: NSObject {
    private let feature: FeatureID
    private let panelSize: NSSize
    private let settings: AppSettings
    private let makeContent: (MenuBarPanelState) -> AnyView
    /// The number drawn into the icon now.
    private var shownBadge: String?
    /// The glass behind the panel, in a window that never takes the keyboard (spec D-6).
    private lazy var glassPanel: GlassPanel = {
        let glass = GlassPanel(level: .statusBar)
        glass.contentView = NSHostingView(rootView: DesignEnvironment(settings: settings, content: PopoverGlassLayer(state: state)))
        return glass
    }()
    private let badge: Badge?
    private let icon: StatusIcon?
    private var iconObserver: AnyCancellable?
    private let onOpen: (() -> Void)?
    private let onClose: (() -> Void)?
    private var badgeObserver: AnyCancellable?
    private let state = MenuBarPanelState()
    private var statusItem: NSStatusItem?
    private var panel: MenuBarPanel?
    private var outsideClickMonitor: Any?
    private var settingsObserver: AnyCancellable?

    init(
        feature: FeatureID,
        panelSize: NSSize,
        settings: AppSettings,
        badge: Badge? = nil,
        icon: StatusIcon? = nil,
        onOpen: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        makeContent: @escaping (MenuBarPanelState) -> AnyView
    ) {
        self.onOpen = onOpen
        self.onClose = onClose
        self.feature = feature
        self.panelSize = panelSize
        self.settings = settings
        self.badge = badge
        self.icon = icon
        self.makeContent = makeContent
    }

    func start() {
        settingsObserver = settings.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.updateStatusItem() }
            }
        }
        badgeObserver = badge?.changes.sink { [weak self] in
            // objectWillChange fires before the change; read the value on the next turn.
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.updateBadge() }
            }
        }
        iconObserver = icon?.changes.sink { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.updateIcon() }
            }
        }
        updateStatusItem()
    }

    private func updateIcon() {
        guard let button = statusItem?.button, let icon else { return }
        button.image = icon.image() ?? NSImage(systemSymbolName: feature.symbolName, accessibilityDescription: feature.title)
        button.toolTip = icon.toolTip() ?? feature.title
        // The number is part of the image: draw it again on the new icon.
        shownBadge = nil
        updateBadge()
    }

    private func updateBadge() {
        guard let button = statusItem?.button, let badge else { return }
        // Drawn into the icon, its digits centred between the icon's lines (spec R-7).
        let title = badge.value().map { "\($0)" } ?? ""
        guard title != shownBadge else { return }
        shownBadge = title
        let base = icon?.image() ?? NSImage(systemSymbolName: feature.symbolName, accessibilityDescription: feature.title)
        button.title = ""
        button.image = base.map { BadgeImage.make(icon: $0, text: title) }
    }



    /// The icon is shown only while the feature is enabled.
    private func updateStatusItem() {
        updateIcon()
        let enabled = settings.isEnabled(feature) && settings.showsInMenuBar(feature)
        if enabled, statusItem == nil {
            let length = badge == nil ? NSStatusItem.squareLength : NSStatusItem.variableLength
            let item = NSStatusBar.system.statusItem(withLength: length)
            item.button?.image = NSImage(systemSymbolName: feature.symbolName, accessibilityDescription: feature.title)
            item.button?.imagePosition = .imageLeading
            item.button?.imageHugsTitle = true
            item.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
            item.button?.toolTip = feature.title
            item.button?.target = self
            item.button?.action = #selector(togglePanel)
            statusItem = item
            updateBadge()
            updateIcon()
        } else if !enabled, let item = statusItem {
            closePanel()
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    /// When the panel was last closed by a click elsewhere.
    private var closedByOutsideClickAt = Date.distantPast

    /// Opens or closes the panel. A click on the icon closes an open panel even when it is
    /// pinned, and unpins it (spec M-8).
    @objc private func togglePanel() {
        let justClosed = Date().timeIntervalSince(closedByOutsideClickAt) < 0.4
        if panel?.isVisible == true || justClosed {
            state.isPinned = false
            closePanel()
        } else {
            showPanel()
        }
    }

    /// The status item's frame on screen.
    private var buttonScreenFrame: NSRect? {
        guard let button = statusItem?.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func showPanel() {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }
        let panel = panel ?? makePanel()
        self.panel = panel

        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? buttonFrame
        let size = panelSize
        let originX = min(max(buttonFrame.midX - size.width / 2, screenFrame.minX + 8), screenFrame.maxX - size.width - 8)
        // The arrow on the panel's top edge points at the icon.
        state.arrowX = buttonFrame.midX - originX
        state.didCopy = false
        let originY = buttonFrame.minY - size.height - 2
        panel.setFrame(NSRect(x: originX, y: originY, width: size.width, height: size.height), display: true)
        glassPanel.setFrame(panel.frame, display: true)
        glassPanel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        panel.addChildWindow(glassPanel, ordered: .below)
        onOpen?()

        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.clickedOutside() }
            }
        }
    }

    /// A click in another app closes the panel, unless it is pinned. Clicks on the icon itself
    /// can arrive here too (status items live outside the app); the icon handles those.
    private func clickedOutside() {
        if let frame = buttonScreenFrame, frame.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) { return }
        guard !state.isPinned else { return }
        closedByOutsideClickAt = Date()
        closePanel()
    }

    private func closePanel() {
        if panel?.isVisible == true { onClose?() }
        if let panel { panel.removeChildWindow(glassPanel) }
        glassPanel.orderOut(nil)
        panel?.orderOut(nil)
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    private func makePanel() -> MenuBarPanel {
        let panel = MenuBarPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = FirstMouseHostingView(rootView: DesignEnvironment(settings: settings, content: makeContent(state)))
        return panel
    }
}

/// Borderless panel that can take keyboard focus without activating the app.
final class MenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// A menu bar icon with a number beside it, the digits' middle on the icon's middle (spec R-7).
enum BadgeImage {
    static func make(icon: NSImage, text: String) -> NSImage {
        guard !text.isEmpty else { return icon }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let textWidth = ceil((text as NSString).size(withAttributes: attributes).width)
        let gap: CGFloat = 3
        let height = max(icon.size.height, ceil(font.ascender - font.descender))
        let size = NSSize(width: icon.size.width + gap + textWidth, height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            icon.draw(in: NSRect(x: 0, y: (height - icon.size.height) / 2, width: icon.size.width, height: icon.size.height))
            // The baseline sits half a cap height below the middle; draw(at:) takes the line's bottom.
            let baseline = Self.baseline(height: height, capHeight: font.capHeight)
            (text as NSString).draw(at: NSPoint(x: icon.size.width + gap, y: baseline + font.descender), withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// The baseline that puts the digits' middle between the icon's two lines. Measured: the
    /// cap-height maths leaves the digits 0.4 pt high, and the lines sit 0.4 pt below the middle.
    static let measuredDrop: CGFloat = 0.8

    static func baseline(height: CGFloat, capHeight: CGFloat) -> CGFloat {
        (height - capHeight) / 2 - measuredDrop
    }
}
