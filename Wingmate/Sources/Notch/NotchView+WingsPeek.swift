import SwiftUI

// MARK: - Small notices beside the notch in Wings mode (spec PV-13, PV-37…PV-39)

/// What stands beside the closed notch in Wings mode instead of dropping down under it.
enum WingsPeek {
    case notification(AppNotification)
    case device(DeviceEvent)
    case notice(StickyNotice)
    /// The announced meeting (spec PV-67).
    case meeting(CalendarEvent)
    /// A new track (spec PV-68).
    case music(MusicIndicator.Glance)
}

extension NotchView {
    /// The small notice shown beside the closed notch, in the order the closed notch shows them.
    var wingsPeek: WingsPeek? {
        guard settings.noticesBeside, !model.isExpanded, !model.isScreenShared, hud.display == nil, calls.call == nil
        else { return nil }
        if let peek = notifications.peek { return .notification(peek) }
        if let event = devices.current { return .device(event) }
        if showsScreenshotPeek { return nil }
        // The announced meeting stands in the notch's line too (spec PV-67).
        if let event = calendarIndicator.announcement { return .meeting(event) }
        // A new track, for a moment (spec PV-68).
        if musicIndicator.isAnnouncing, let glance = musicIndicator.glance { return .music(glance) }
        return shownNotice.map(WingsPeek.notice)
    }

    /// A sticky notice or the announced meeting beside the notch, in place of the closed notch's row.
    var wingsNoticePeek: WingsPeek? {
        switch wingsPeek {
        case .notice, .meeting, .music: wingsPeek
        default: nil
        }
    }

    /// A device notice: beside the notch in Wings mode, else under it (spec DV-6, PV-37).
    @ViewBuilder func devicePeek(_ event: DeviceEvent) -> some View {
        if settings.noticesBeside {
            wingsPeekView(.device(event)).transition(.wingsSpreadIn)
        } else {
            DevicePeekView(event: event, notchHeight: geometry.notchSize.height) { devices.perform($0) }
                .frame(width: geometry.devicePeekSize(for: event).width, height: geometry.devicePeekSize(for: event).height)
                .transition(.opacity)
        }
    }

    /// Each side as wide as its own content: the notch stays in place (spec PV-38).
    func wingsPeekView(_ peek: WingsPeek) -> some View {
        WingsView(
            notchWidth: geometry.notchSize.width, sides: model.peekSides, openFully: {}, measured: peekMeasured,
            left: { wingsPeekLeft(peek) },
            right: { wingsPeekRight(peek) }
        )
        .frame(width: geometry.wingsSize(model.peekSides).width, height: geometry.notchSize.height)
    }

    private func peekMeasured(_ needs: WingsSides) {
        let old = model.wingsLasting.peekNeeds
        guard abs(old.left - needs.left) > 1 || abs(old.right - needs.right) > 1 else { return }
        withAnimation(Self.quickAnimation) { model.wingsLasting.peekNeeds = needs }
    }

    /// The icon and who it is from.
    @ViewBuilder private func wingsPeekLeft(_ peek: WingsPeek) -> some View {
        switch peek {
        case .notification(let notification):
            HStack(spacing: 6) {
                AppIconView(app: notifications.catalog.app(for: notification.appIdentifier), size: 16)
                WingText(notifications.content(for: notification).sender, bold: true)
                let count = notifications.unseen.count
                if count > 1 { WingText("+\(count - 1)", dim: true) }
            }
        case .device(let event):
            HStack(spacing: 6) {
                Image(systemName: event.symbol)
                    .font(.notch(size: 13, weight: .medium))
                    .foregroundStyle(event.isConnected ? Theme.green : Color.white.level(0.6))
                WingText(event.name, bold: true)
            }
        case .notice(let notice) where notice.download != nil:
            // Only the icon: the notice stays about as wide as the notch (spec PV-57).
            Image(systemName: "arrow.down.circle.fill")
                .font(.notch(size: 14, weight: .semibold))
                .foregroundStyle(Theme.blue)
                .accessibilityLabel("Download")
        case .meeting(let event):
            meetingWingLeft(event)
        case .music(let glance):
            HStack(spacing: 6) {
                MusicArtwork(image: glance.artwork, cornerRadius: AppleStyle.corner(3)).frame(width: 16, height: 16)
                WingText(glance.title, bold: true)
            }
        case .notice(let notice):
            HStack(spacing: 6) {
                NoticeIcon(notice: notice)
                WingText(notice.source, bold: true)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: openNotice)
        }
    }

    /// The notice itself, from the notch's edge outwards.
    @ViewBuilder private func wingsPeekRight(_ peek: WingsPeek) -> some View {
        switch peek {
        case .notification(let notification):
            HStack(spacing: 6) {
                // Runs once to its end; hovered, it starts again (spec PV-38).
                WingsMarquee(text: Self.peekLine(notifications.content(for: notification).detail), dim: true, repeats: false)
                    .id("\(notification.id)-\(model.wingsLasting.peekHovers)")
                // Deletes it from Wingmate, not from the Notification Centre (spec PV-55).
                Button(action: dismissNotice) {
                    // The usual X, never a bin (spec PV-62).
                    Image(systemName: "xmark.circle.fill")
                        .font(.notch(size: 13))
                        .foregroundStyle(Color.white.level(0.55))
                        .contentShape(Circle())
                }
                .buttonStyle(.notch)
                .help("Delete (or swipe up with two fingers)")
                .accessibilityLabel("Delete")
            }
        case .device(let event):
            deviceWingRight(event)
        case .notice(let notice) where notice.download != nil:
            Image(systemName: "checkmark.circle.fill")
                .font(.notch(size: 14, weight: .semibold))
                .foregroundStyle(Theme.green)
                .accessibilityLabel("Finished")
        case .notice(let notice):
            noticeWingRight(notice)
        case .meeting(let event):
            meetingWingRight(event)
        case .music(let glance):
            WingsMarquee(text: glance.artist, dim: true, repeats: false).id(glance.trackID)
        }
    }

    /// The camera (or calendar) in the phase's colour, and the meeting's name (spec PV-67).
    private func meetingWingLeft(_ event: CalendarEvent) -> some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let phase = CalendarAgenda.status(of: event, now: context.date, leadTime: calendar.leadTime).phase
            HStack(spacing: 6) {
                Image(systemName: event.meetingURL != nil ? "video.fill" : "calendar")
                    .font(.notch(size: 13, weight: .semibold))
                    .foregroundStyle(NotchIndicatorView.color(for: phase))
                WingText(event.title, bold: true)
            }
        }
    }

    /// Join (nearest the notch), when and the X, which puts the name away as a swipe up does
    /// (spec PV-67, PV-74, K-8f).
    private func meetingWingRight(_ event: CalendarEvent) -> some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let status = CalendarAgenda.status(of: event, now: context.date, leadTime: calendar.leadTime)
            HStack(spacing: 6) {
                if event.meetingURL != nil {
                    WingButton(title: "Join", symbol: "video.fill", prominent: true) { joinedMeeting(event) }
                }
                Text(IndicatorLayout.meetingTimeText(event, phase: status.phase == .ongoing ? "in progress" : "starting"))
                    .font(.notch(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(CalendarStyle.eventTime)
                    .lineLimit(1)
                    .fixedSize()
                Button(action: dismissNotice) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.notch(size: 13))
                        .foregroundStyle(Color.white.level(0.55))
                        .contentShape(Circle())
                }
                .buttonStyle(.notch)
                .help("Dismiss (or swipe up with two fingers)")
                .accessibilityLabel("Dismiss")
            }
        }
    }

    private func deviceWingRight(_ event: DeviceEvent) -> some View {
        let peek = DevicePeekView(event: event, notchHeight: geometry.notchSize.height) { devices.perform($0) }
        return HStack(spacing: 8) {
            peek.statusLine
            ForEach(event.levels) { level in peek.levelView(level) }
            ForEach(Array(event.actions.enumerated()), id: \.offset) { _, action in
                WingButton(title: Self.title(of: action), symbol: nil, prominent: Self.isProminent(action)) {
                    devices.perform(action)
                }
            }
        }
    }

    private func noticeWingRight(_ notice: StickyNotice) -> some View {
        let detail = [notice.detail, notice.date.formatted(date: .omitted, time: .shortened)].filter { !$0.isEmpty }
        return HStack(spacing: 6) {
            Group {
                WingText(notice.title, bold: true)
                    // A question waits for an answer (spec CQ-2).
                    .foregroundStyle(notice.isQuestion ? Color.orange : .white)
                    .fixedSize()
                WingsMarquee(text: detail.joined(separator: " · "), dim: true, repeats: false)
                    .id("\(notice.date.timeIntervalSince1970)-\(model.wingsLasting.peekHovers)")
            }
            .contentShape(Rectangle())
            // A click brings forward the app the work ran in (spec CN-6).
            .onTapGesture(perform: openNotice)
            // What's new has no X: it goes with its Got it (spec WN-7).
            if notice.whatsNew == nil {
                Button {
                    dismissNotice()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.notch(size: 13))
                        .foregroundStyle(Color.white.level(0.55))
                        .contentShape(Circle())
                }
                .buttonStyle(.notch)
                .help("Dismiss (or swipe up with two fingers)")
                .accessibilityLabel("Dismiss")
            }
        }
    }

    /// The first line of a notification, whole: the marquee shows what does not fit.
    static func peekLine(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        return String(line.prefix(300))
    }

    private static func title(of action: DeviceEvent.Action) -> String {
        switch action {
        case .open: "Open"
        case .eject: "Eject"
        case .useForAudio: "Use for audio"
        case .displaySettings: "Displays…"
        case .bluetoothButton(let title, _): title
        }
    }

    private static func isProminent(_ action: DeviceEvent.Action) -> Bool {
        if case .bluetoothButton = action { return true }
        return false
    }
}

// MARK: - The controller's side (spec PV-37, PV-39)

extension NotchController {
    /// A pill floats a little below the top edge: its zones reach that much further (spec D-7).
    var pillGap: CGFloat {
        settings.externalStyle == .pill && !model.geometry.hasPhysicalNotch ? NotchView.pillGap : 0
    }

    func reachingDown(_ zone: CGRect) -> CGRect {
        CGRect(x: zone.minX, y: zone.minY - pillGap, width: zone.width, height: zone.height + pillGap)
    }

    /// The small notice beside the closed notch in Wings mode, the shape's area.
    var wingsPeekZone: CGRect {
        let geometry = model.geometry
        let sides = model.peekSides
        return reachingDown(geometry.keepOpenZone(for: geometry.wingsSize(sides)).offsetBy(dx: sides.offset, dy: 0))
    }

    /// Where a device notice stands: beside the notch in Wings mode, else under it.
    var devicePeekZone: CGRect {
        settings.noticesBeside ? wingsPeekZone : model.geometry.keepOpenZone(for: model.geometry.devicePeekSize(for: devices.current))
    }

    /// The pointer on a notice beside the notch: a notification stays while it is there, and its
    /// line starts again (spec PV-38, PV-39).
    func updateWingsPeekHover(at point: CGPoint) {
        let shows = notifications.peek != nil || devices.current != nil || notices.notice != nil
            || calendar.announcement != nil || isAnnouncingTrack
        let inside = settings.noticesBeside && shows && !model.isExpanded && wingsPeekZone.contains(point)
        notifications.holdPeek(inside && notifications.peek != nil, by: ObjectIdentifier(self))
        guard inside != isOverWingsPeek else { return }
        isOverWingsPeek = inside
        if inside { model.wingsLasting.peekHovers += 1 }
    }
}
