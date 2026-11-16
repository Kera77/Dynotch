import AppKit
import Combine
import SwiftUI

/// A number next to a menu bar icon (open reminders, spec R-7).
struct Badge {
    let changes: ObservableObjectPublisher
    let value: @MainActor () -> Int?
}

/// Menu bar icon of a feature that drops a popover panel down below it
/// (calculator: spec SZ-6…SZ-8, notes: spec J-8).
@MainActor
final class MenuBarPopoverController: NSObject {
    private let feature: FeatureID
    private let panelSize: NSSize
    private let settings: AppSettings
    private let makeContent: (MenuBarPanelState) -> AnyView
    private let badge: Badge?
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
        makeContent: @escaping (MenuBarPanelState) -> AnyView
    ) {
        self.feature = feature
        self.panelSize = panelSize
        self.settings = settings
        self.badge = badge
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
        updateStatusItem()
    }

    private func updateBadge() {
        guard let button = statusItem?.button, let badge else { return }
        let title = badge.value().map { " \($0)" } ?? ""
        if button.title != title { button.title = title }
    }

    /// The icon is shown only while the feature is enabled.
    private func updateStatusItem() {
        let enabled = settings.isEnabled(feature)
        if enabled, statusItem == nil {
            let length = badge == nil ? NSStatusItem.squareLength : NSStatusItem.variableLength
            let item = NSStatusBar.system.statusItem(withLength: length)
            item.button?.image = NSImage(systemSymbolName: feature.symbolName, accessibilityDescription: feature.title)
            item.button?.imagePosition = .imageLeading
            item.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
            item.button?.toolTip = feature.title
            item.button?.target = self
            item.button?.action = #selector(togglePanel)
            statusItem = item
            updateBadge()
        } else if !enabled, let item = statusItem {
            closePanel()
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    @objc private func togglePanel() {
        if panel?.isVisible == true {
            closePanel()
        } else {
            showPanel()
        }
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
        panel.makeKeyAndOrderFront(nil)

        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.clickedOutside() }
            }
        }
    }

    /// A click in another app closes the panel, unless it is pinned.
    private func clickedOutside() {
        if !state.isPinned { closePanel() }
    }

    private func closePanel() {
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
        panel.contentView = FirstMouseHostingView(rootView: makeContent(state))
        return panel
    }
}

/// Borderless panel that can take keyboard focus without activating the app.
final class MenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
