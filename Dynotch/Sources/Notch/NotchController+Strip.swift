import AppKit
import SwiftUI

// MARK: - Module strip (spec MS-1…MS-4)

extension NotchController {
    /// The strip may show: turned on, nothing else at the notch.
    private var stripAvailable: Bool {
        settings.moduleStrip && !model.isExpanded && notifications.peek == nil && !callIsShown
            && !model.isHiddenForFullScreen && ModuleStripChoice.features(from: settings.listedFeatures).count > 1
    }

    /// The bottom part of the notch where resting shows the strip (spec MS-2).
    var stripBand: CGRect {
        let notch = model.geometry.notchRect
        return CGRect(x: notch.minX, y: notch.minY - pillGap, width: notch.width, height: notch.height * settings.moduleStripBand)
    }

    /// The strip itself, where the pointer may go to pick a module.
    private var stripArea: CGRect {
        model.geometry.moduleStripRect(count: ModuleStripChoice.features(from: settings.listedFeatures).count)
            .offsetBy(dx: 0, dy: -pillGap)
            .insetBy(dx: -6, dy: -6)
    }

    /// The pointer outside the zone that opens the notch: shows, keeps or hides the strip.
    /// - Returns: true while the pointer is on the band or the strip.
    func handleStrip(at point: CGPoint) -> Bool {
        guard stripAvailable else {
            hideStrip()
            return false
        }
        if model.isShowingStrip {
            let isOn = stripArea.contains(point) || stripBand.contains(point)
            panel.ignoresMouseEvents = !stripArea.contains(point)
            if !isOn { hideStrip() }
            return isOn
        }
        guard stripBand.contains(point) else {
            stripTask?.cancel()
            stripTask = nil
            return false
        }
        guard stripTask == nil else { return true }
        let delay = settings.moduleStripDelay
        stripTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.stripTask = nil
            // Still resting on the band: show the modules.
            guard self.stripAvailable, self.stripBand.contains(NSEvent.mouseLocation) else { return }
            self.model.stripOrigin = NSEvent.mouseLocation.x - self.model.geometry.notchRect.midX
            self.model.setStripShown(true)
            self.startHoverTimer()
        }
        return true
    }

    func hideStrip() {
        stripTask?.cancel()
        stripTask = nil
        guard model.isShowingStrip else { return }
        withAnimation(NotchView.quickAnimation) { model.setStripShown(false) }
        if !model.isExpanded {
            panel.ignoresMouseEvents = true
            if model.hoveredIndicator == nil, model.hoveredBadge == nil, !model.badgesUnfolded { stopHoverTimer() }
        }
    }

    /// A click on a module in the strip opens the notch on it (spec MS-3).
    func openFromStrip(_ feature: FeatureID) {
        hideStrip()
        expand()
        withAnimation(Self.animation) { model.select(feature) }
    }
}

// MARK: - Smart opening (spec SO-1…SO-4)

extension NotchController {
    /// Opening by hover: the module the moment calls for, if a rule applies.
    func applySmartOpening() {
        let now = Date()
        let isOn = settings.isSmartRuleOn
        var context = SmartContext(
            meeting: settings.isEnabled(.calendar) ? calendar.indicatorEvents.first?.id : nil,
            reminder: settings.isEnabled(.reminders) ? SmartOpening.dueReminder(in: reminders.open, now: now)?.id : nil,
            clipboard: settings.isEnabled(.calculator) ? ClipboardWatcher.shared.recentCalculation(now: now) : nil,
            battery: battery.warnings.first?.id,
            usage: settings.isEnabled(.claudeUsage) ? claudeUsage.peak?.utilization : nil
        )
        if isOn(.code), settings.isEnabled(.clipboard) { context.code = ClipboardWatcher.shared.recentCode(now: now) }
        // Downloads is only looked at with its rule on: the first look asks for access (spec SO-6).
        if isOn(.download), settings.isEnabled(.tray) { context.download = SmartOpening.recentDownload(now: now) }
        if settings.isEnabled(.calendar) { context.morning = SmartOpening.morningKey(now: now) }
        guard let choice = SmartOpening.choose(context, isOn: isOn, used: model.smartUsed),
              settings.isEnabled(choice.feature)
        else { return }
        model.smartUsed.insert(choice.key)
        prepare(choice, context: context)
        model.select(choice.feature)
    }

    /// What the chosen module gets ready with: the calculation, the code, the file or today.
    private func prepare(_ choice: SmartOpening.Choice, context: SmartContext) {
        switch choice.feature {
        case .calculator:
            guard let copied = context.clipboard else { return }
            // The copied calculation on a line of its own, with its result (spec SO-2).
            let text = calculator.text
            calculator.text = text.isEmpty || text.hasSuffix("\n") ? text + copied.text : text + "\n" + copied.text
        case .clipboard:
            if let code = context.code { clipboard.highlight(code.text) }
        case .tray:
            if let file = context.download { tray.add([file]) }
        case .calendar:
            if choice.key.hasPrefix("morning:") { calendar.selectedDay = calendar.today }
        default:
            break
        }
    }
}
