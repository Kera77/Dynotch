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
