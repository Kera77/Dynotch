import CoreGraphics

// MARK: - Resizing modules (spec RS-1…RS-4)

extension NotchViewModel {
    /// The open module can be resized: the setting is on, and a resizable module shows by itself
    /// (not the settings, a notification, the preview or a drop zone).
    var canResize: Bool {
        settings.resizableModules && isExpanded && !isPreview && !isShowingSettings && !isShowingNotifications
            && !isShowingOverlayPage && ModuleSizes.resizable.contains(currentFeature)
    }

    /// The full calendar, the large notes and reminders, and the wide chat tabs keep a size of
    /// their own (spec RS-3).
    var moduleVariant: String? {
        if currentFeature == .notifications, notificationsTab.isWide { return "wide" }
        return isLarge ? "large" : nil
    }

    /// The size this module was resized to on this display, within today's bounds.
    var savedModuleSize: CGSize? {
        moduleSizes.size(of: currentFeature, variant: moduleVariant, on: screenName).map(clampedModuleSize)
    }

    var hasResizedModule: Bool {
        resizingSize != nil || savedModuleSize != nil
    }

    func clampedModuleSize(_ size: CGSize) -> CGSize {
        ModuleSizes.clamped(size, min: normalOpenSize, max: geometry.maxModuleSize)
    }

    /// Follows the drag of the resize handle, without animation.
    func resize(to size: CGSize) {
        guard canResize else { return }
        let clamped = clampedModuleSize(size)
        if clamped != resizingSize { resizingSize = clamped }
    }

    /// Keeps the size the drag ended at (spec RS-3).
    func endResize() {
        guard let size = resizingSize else { return }
        moduleSizes.set(size == normalOpenSize ? nil : size, of: currentFeature, variant: moduleVariant, on: screenName)
        resizingSize = nil
    }

    /// Back to the module's normal size (spec RS-1).
    func resetModuleSize() {
        resizingSize = nil
        moduleSizes.set(nil, of: currentFeature, variant: moduleVariant, on: screenName)
        objectWillChange.send()
    }
}
