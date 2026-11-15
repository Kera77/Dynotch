import AppKit
import Combine
import SwiftUI

/// Menu bar icon that drops the calculator down below it (spec SZ-6…SZ-8).
@MainActor
final class CalculatorMenuBarController: NSObject {
    private static let panelSize = NSSize(width: 400, height: 290)

    private let settings: AppSettings
    private let store: CalculatorStore
    private let pin = PinState()
    private var statusItem: NSStatusItem?
    private var panel: MenuBarPanel?
    private var outsideClickMonitor: Any?
    private var settingsObserver: AnyCancellable?

    init(settings: AppSettings, store: CalculatorStore) {
        self.settings = settings
        self.store = store
    }

    func start() {
        settingsObserver = settings.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.updateStatusItem() }
            }
        }
        updateStatusItem()
    }

    /// The icon is shown only while the calculator feature is enabled.
    private func updateStatusItem() {
        let enabled = settings.isEnabled(.calculator)
        if enabled, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(
                systemSymbolName: FeatureID.calculator.symbolName,
                accessibilityDescription: FeatureID.calculator.title
            )
            item.button?.target = self
            item.button?.action = #selector(togglePanel)
            statusItem = item
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
        let size = Self.panelSize
        let originX = min(max(buttonFrame.midX - size.width / 2, screenFrame.minX + 8), screenFrame.maxX - size.width - 8)
        panel.setFrame(NSRect(x: originX, y: buttonFrame.minY - size.height, width: size.width, height: size.height), display: true)
        panel.makeKeyAndOrderFront(nil)

        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.clickedOutside() }
            }
        }
    }

    /// A click in another app closes the panel, unless it is pinned.
    private func clickedOutside() {
        if !pin.isPinned { closePanel() }
    }

    private func closePanel() {
        panel?.orderOut(nil)
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    private func makePanel() -> MenuBarPanel {
        let panel = MenuBarPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
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
        panel.contentView = FirstMouseHostingView(rootView: CalculatorMenuBarView(store: store, pin: pin))
        return panel
    }
}

/// Borderless panel that can take keyboard focus without activating the app.
final class MenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Content of the menu bar panel: notch-like black sheet with the notepad.
private struct CalculatorMenuBarView: View {
    @ObservedObject var store: CalculatorStore
    @ObservedObject var pin: PinState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: FeatureID.calculator.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PinButton.activeColor)
                Text(FeatureID.calculator.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                PinButton(isPinned: pin.isPinned) { pin.isPinned.toggle() }
                    .background(Capsule(style: .continuous).fill(Color.white.opacity(0.1)))
            }
            .padding(.horizontal, 14)
            .frame(height: 40)

            CalculatorEditor(text: $store.text)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
}
