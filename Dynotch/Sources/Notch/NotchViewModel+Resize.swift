import CoreGraphics

// MARK: - Resizing modules (spec RS-1…RS-4)

extension NotchViewModel {
    /// The open module can be resized: the setting is on, and a resizable module shows by itself
    /// (not the settings, a notification, the preview or a drop zone).
    var canResize: Bool {
        settings.resizableModules && isExpanded && !isPreview && !isShowingSettings && !isShowingToggles && !isShowingNotifications
            && !isShowingOverlayPage && ModuleSizes.resizable.contains(currentFeature)
    }

    /// The full calendar and the large notes and reminders keep a size of their own (spec RS-3);
    /// tabs do not (spec RS-7).
    var moduleVariant: String? {
        isLarge ? "large" : nil
    }

    /// The whole module's size is kept under its host, not per tab (spec RS-7).
    var sizedFeature: FeatureID { settings.hostFeature(of: currentFeature) }

    /// The size this module was resized to on this display, within today's bounds. Before RS-7 the
    /// tabs kept their own: the larger of those stands in until the module is resized again.
    var savedModuleSize: CGSize? {
        access(keyPath: \.savedModuleSize)
        if let size = moduleSizes.size(of: sizedFeature, variant: moduleVariant, on: screenName) { return clampedModuleSize(size) }
        let tabs = settings.mergedTabs(for: currentFeature) ?? []
        let older = tabs.compactMap { moduleSizes.size(of: $0, variant: moduleVariant, on: screenName) }
        guard !older.isEmpty else { return nil }
        return clampedModuleSize(older.reduce(CGSize.zero) { CGSize(width: max($0.width, $1.width), height: max($0.height, $1.height)) })
    }

    var hasResizedModule: Bool {
        resizingSize != nil || savedModuleSize != nil
    }

    func clampedModuleSize(_ size: CGSize) -> CGSize {
        homeWidth(ModuleSizes.clamped(size, min: normalOpenSize, max: geometry.maxModuleSize))
    }

    /// The Home's width follows its tiles; only its height is resized (spec HT-39).
    private func homeWidth(_ size: CGSize) -> CGSize {
        guard sizedFeature == .home, !isLarge else { return size }
        return CGSize(width: homeSize.width, height: size.height)
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
        let saved = size == normalOpenSize ? nil : size
        withMutation(keyPath: \.savedModuleSize) {
            moduleSizes.set(saved, of: sizedFeature, variant: moduleVariant, on: screenName)
            for tab in settings.mergedTabs(for: currentFeature) ?? [] where tab != sizedFeature {
                moduleSizes.set(nil, of: tab, variant: moduleVariant, on: screenName)
            }
        }
        resizingSize = nil
    }

    /// Back to the module's normal size (spec RS-1).
    func resetModuleSize() {
        resizingSize = nil
        withMutation(keyPath: \.savedModuleSize) {
            for feature in Set([sizedFeature] + (settings.mergedTabs(for: currentFeature) ?? [])) {
                moduleSizes.set(nil, of: feature, variant: moduleVariant, on: screenName)
            }
        }
    }

    // MARK: - Normal sizes (spec RS-1, RS-7)

    /// Size of the panel while it is open, without a resized module (spec RS-1).
    var normalOpenSize: CGSize {
        // Room at the bottom for the reply field, or the "open to reply" button.
        if isShowingNotifications {
            let size = geometry.notificationSize(count: notifications.count, hasReply: true)
            return CGSize(width: size.width, height: notificationsHeight ?? size.height)
        }
        if isShowingSwitcher { return switcherSize }
        if editor != nil { return geometry.maxModuleSize }
        // The tour, as tall as its step (spec OB-36).
        if showsTour {
            let measured = OnboardingController.shared?.model.contentHeight ?? 0
            let height = max(measured, geometry.notchSize.height + 200)
            return CGSize(width: max(geometry.expandedSize.width, OnboardingView.width), height: min(height, geometry.maxModuleSize.height))
        }
        if !whatsNew.isEmpty {
            let height = geometry.notchSize.height + WhatsNewPage.height(for: whatsNew)
            return CGSize(width: geometry.expandedSize.width, height: min(height, geometry.maxModuleSize.height))
        }
        // Files over the wings: they stay at the notch's height (spec PV-14).
        if isShowingDropZone, isPreview { return geometry.previewSize(side: WingsDropView.side) }
        if isShowingOverlayPage {
            return CGSize(width: geometry.expandedSize.width, height: geometry.notchSize.height + (isShowingDropZone ? 150 : 170))
        }
        if isPreview { return geometry.wingsSize(wingsSides) }
        // Settings first: over the wide chat tabs they got that lower panel and pushed the top row
        // out of sight (spec C-11).
        if isShowingSettings { return geometry.settingsSize }
        // The quick toggles alone: the usual module size (spec QT-6).
        if isShowingToggles { return geometry.expandedSize }
        // One size for the whole module: the largest its tabs need (spec RS-7).
        let tabs = settings.mergedTabs(for: currentFeature) ?? [currentFeature]
        return tabs.map(tabSize).reduce(CGSize.zero) { CGSize(width: max($0.width, $1.width), height: max($0.height, $1.height)) }
    }

    /// What one tab (or a module without tabs) needs.
    private func tabSize(_ feature: FeatureID) -> CGSize {
        switch feature {
        case .notifications:
            // Room for the tab picker above a card (spec UM-8c); the Beeper tab's wide list sets
            // the size of every tab (spec BP-1, RS-7).
            let own = isLarge ? geometry.largeSize : geometry.notificationsModuleSize
            guard beeperListOpen else { return own }
            return CGSize(width: max(own.width, geometry.chatPanelSize.width), height: max(own.height, geometry.chatPanelSize.height))
        case .claudeUsage, .claudeSessions: return mergedAIWidth(geometry.usageSize)
        case .claudeChat: return isChatTall ? geometry.chatSize : mergedAIWidth(geometry.expandedSize)
        case .notes where isLarge, .reminders where isLarge: return geometry.mediumSize
        // The stats' tiles and process list need the room (spec SY-1).
        case .stats: return geometry.mediumSize
        // Room for the paths and sizes (spec TT-1).
        case .cleaner: return isLarge ? geometry.largeSize : geometry.mediumSize
        case .tools: return geometry.toolsSize
        case .home where !isLarge: return homeSize
        default: return isLarge ? geometry.largeSize : geometry.expandedSize
        }
    }

    /// As wide as the widest row of tiles, at least three columns (spec HT-39).
    var homeSize: CGSize {
        let columns = HomeLayout.shown(HomeTileSettings.shared.slots).columns
        let width = HomeLayout.panelWidth(columns: columns, normalWidth: geometry.expandedSize.width)
        return CGSize(width: width, height: geometry.expandedSize.height)
    }

    /// Merged, the AI tabs sit in the header beside the chat list, which needs the medium width (spec MG-2).
    private func mergedAIWidth(_ size: CGSize) -> CGSize {
        settings.isMerged(.claudeUsage) ? CGSize(width: max(size.width, geometry.mediumSize.width), height: size.height) : size
    }
}
