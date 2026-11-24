import AppKit

// MARK: - Widths of the recording and of the unfolded items (spec SH-5c, PV-69)

extension IndicatorItem {
    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    /// Width of the item's icon left of the notch.
    var iconWidth: CGFloat {
        if case .recording(let since) = self { return IndicatorLayout.recordingWidth(since: since) }
        return IndicatorLayout.iconWidth
    }

    var isMeeting: Bool {
        if case .meeting = self { return true }
        return false
    }
}

extension IndicatorLayout {
    /// The dot and "12:34" (or "1:02:03" after an hour) with room to spare, so the notch never
    /// cuts the time (spec SH-5c).
    static func recordingWidth(since: Date, now: Date = Date()) -> CGFloat {
        let sample = now.timeIntervalSince(since) >= 3600 ? "0:00:00" : "00:00"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let text = (sample as NSString).size(withAttributes: [.font: font]).width
        return 18 + 4 + ceil(text) + 4
    }
}

// MARK: - Unfolded beside the notch (spec PV-69)

extension IndicatorLayout {
    /// "10:00–10:30 · starting", the name (at most 200 pt), Join and the X right of the countdown.
    static func meetingUnfoldWidth(for event: CalendarEvent) -> CGFloat {
        let title = min(textWidth(event.title, size: 12, weight: .semibold), 200)
        let time = textWidth(meetingTimeText(event, phase: "in progress"), size: 11, weight: .regular)
        let join: CGFloat = event.meetingURL != nil ? 44 + 6 : 0
        return 6 + title + 6 + time + 6 + join + 15 + 6
    }

    /// The name and the X right of the ring.
    static func batteryUnfoldWidth(for device: BatteryDevice) -> CGFloat {
        6 + min(textWidth(device.name, size: 12, weight: .semibold), 180) + 6 + 15 + 6
    }

    static func meetingTimeText(_ event: CalendarEvent, phase: String) -> String {
        let start = event.start.formatted(date: .omitted, time: .shortened)
        let end = event.end.formatted(date: .omitted, time: .shortened)
        return "\(start)–\(end) · \(phase)"
    }

    static func textWidth(_ text: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width)
    }
}

// MARK: - Unfolding beside the notch (spec PV-58, PV-69)

extension IndicatorItem {
    /// Beside the notch the hovered AI ring, countdown or low battery unfolds to the right
    /// instead of dropping down (spec PV-58, PV-69).
    /// The Tools' controls widen sideways in Wings mode as well (spec TM-19): `toolsBeside`.
    static func unfoldingUsage(_ items: [IndicatorItem], hovered: Int?, wings: Bool, toolsBeside: Bool? = nil) -> [IndicatorItem] {
        guard let hovered, items.indices.contains(hovered) else { return items }
        var unfolded = items
        switch items[hovered] {
        case .usage(let limits, false) where wings: unfolded[hovered] = .usage(limits, unfolded: true)
        case .meeting(let event, false) where wings: unfolded[hovered] = .meeting(event, unfolded: true)
        case .battery(let device, false) where wings: unfolded[hovered] = .battery(device, unfolded: true)
        // The Tools' controls (spec TM-19).
        case .tools(var glance) where (toolsBeside ?? wings) && !glance.unfolded && !glance.controls.isEmpty:
            glance.unfolded = true
            unfolded[hovered] = .tools(glance)
        default: return items
        }
        return unfolded
    }
}

// MARK: - The Tools (spec TM-3, QT-5)

extension IndicatorLayout {
    /// The icon and the time ("4:59" or "1:04:59"), "+N", and the microphone and cup icons.
    static func toolsWidth(_ glance: ToolsGlance) -> CGFloat {
        var width: CGFloat = 4
        if let clock = glance.clock {
            let sample = clock.seconds(at: Date()) >= 3600 ? "0:00:00" : "00:00"
            let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
            width += 13 + 4 + ceil((sample as NSString).size(withAttributes: [.font: font]).width) + 4
            if glance.more > 0 { width += textWidth("+\(glance.more)", size: 10, weight: .semibold) + 4 }
        }
        if glance.micMuted { width += 16 }
        if glance.awake { width += 16 }
        return width + 2
    }

    /// The hover controls right of the time, and the arrow that opens the module (spec TM-19).
    static func toolsUnfoldWidth(_ glance: ToolsGlance) -> CGFloat {
        CGFloat(glance.controls.count + 1) * (toolsControlSize + toolsControlSpacing) + 4
    }

    static let toolsControlSize: CGFloat = 20
    static let toolsControlSpacing: CGFloat = 4
}
