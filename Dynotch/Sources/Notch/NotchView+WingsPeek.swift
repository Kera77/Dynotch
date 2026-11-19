import SwiftUI

// MARK: - Small notices beside the notch in Wings mode (spec PV-13, PV-37…PV-39)

/// What stands beside the closed notch in Wings mode instead of dropping down under it.
enum WingsPeek {
    case notification(AppNotification)
    case device(DeviceEvent)
    case notice(StickyNotice)
}

extension NotchView {
    /// The small notice shown beside the closed notch, in the order the closed notch shows them.
    var wingsPeek: WingsPeek? {
        guard settings.hoverPreview, !model.isExpanded, !model.isScreenShared, hud.display == nil, calls.call == nil
        else { return nil }
        if let peek = notifications.peek { return .notification(peek) }
        if let event = devices.current { return .device(event) }
        if showsScreenshotPeek { return nil }
        return shownNotice.map(WingsPeek.notice)
    }

    /// A sticky notice beside the notch, in place of the closed notch's row.
    var wingsNoticePeek: WingsPeek? {
        if case .notice = wingsPeek { return wingsPeek }
        return nil
    }

    /// A device notice: beside the notch in Wings mode, else under it (spec DV-6, PV-37).
    @ViewBuilder func devicePeek(_ event: DeviceEvent) -> some View {
        if settings.hoverPreview {
            wingsPeekView(.device(event)).transition(.wingsSpread)
        } else {
            DevicePeekView(event: event, notchHeight: geometry.notchSize.height) { devices.perform($0) }
                .frame(width: geometry.devicePeekSize.width, height: geometry.devicePeekSize.height)
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
            // Runs once to its end; hovered, it starts again (spec PV-38).
            WingsMarquee(text: Self.peekLine(notifications.content(for: notification).detail), dim: true, repeats: false)
                .id("\(notification.id)-\(model.wingsLasting.peekHovers)")
        case .device(let event):
            deviceWingRight(event)
        case .notice(let notice):
            noticeWingRight(notice)
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
            Button {
                withAnimation(Self.quickAnimation) { notices.dismiss() }
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
        settings.hoverPreview ? wingsPeekZone : model.geometry.keepOpenZone(for: model.geometry.devicePeekSize)
    }

    /// The pointer on a notice beside the notch: a notification stays while it is there, and its
    /// line starts again (spec PV-38, PV-39).
    func updateWingsPeekHover(at point: CGPoint) {
        let shows = notifications.peek != nil || devices.current != nil || notices.notice != nil
        let inside = settings.hoverPreview && shows && !model.isExpanded && wingsPeekZone.contains(point)
        notifications.holdPeek(inside && notifications.peek != nil, by: ObjectIdentifier(self))
        guard inside != isOverWingsPeek else { return }
        isOverWingsPeek = inside
        if inside { model.wingsLasting.peekHovers += 1 }
    }
}
