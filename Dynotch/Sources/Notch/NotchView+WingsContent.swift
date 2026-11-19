import SwiftUI

// MARK: - DyNotch Wings content per module (spec PV-15, PV-32, PV-34, PV-35)

extension NotchView {
    // MARK: AI usage (spec PV-15)

    /// The current five-hour session: "62%" and the ring in the notch indicator's colours.
    @ViewBuilder var usageSessionWing: some View {
        if let limit = claudeUsage.limits.first(where: { $0.id == "five_hour" }) {
            let color = NotchIndicatorView.color(for: limit.level)
            HStack(spacing: 6) {
                WingText("\(Int(limit.utilization.rounded()))%", bold: true)
                    .foregroundStyle(color)
                    .monospacedDigit()
                LevelRing(fraction: limit.utilization / 100, color: color, label: "")
                    .scaleEffect(0.75)
                    .frame(width: LevelRing.size * 0.75, height: LevelRing.size * 0.75)
            }
            .help("Current session")
        } else {
            WingLabel(symbol: "gauge.with.dots.needle.50percent", text: "No usage loaded")
        }
    }

    // MARK: Notifications (spec PV-17)

    /// The apps with new notifications, newest first; Mail's unread first when it is the source.
    var wingsApps: [WingsApp] {
        var apps = Dictionary(grouping: notifications.recent, by: \.appIdentifier)
            .compactMap { key, list -> WingsApp? in
                guard let newest = list.max(by: { $0.date < $1.date }) else { return nil }
                let app = notifications.catalog.app(for: key)
                let content = notifications.content(for: newest)
                let line = "\(content.sender) · \(content.detail)"
                return WingsApp(id: key, name: app.name, count: list.count, date: newest.date, app: app, line: line)
            }
            .sorted { $0.date > $1.date }
        if notifications.mail.isActive, notifications.mail.totalUnread > 0 {
            let count = notifications.mail.totalUnread
            apps.insert(WingsApp(id: WingsApp.mailID, name: "Mail", count: count, date: .now, app: nil, line: "\(count) unread"), at: 0)
        }
        return Array(apps.prefix(5))
    }

    /// The app whose name and message show: the hovered one, else the newest.
    func activeWingsApp(in apps: [WingsApp]) -> WingsApp? {
        apps.first { $0.id == model.wings.hoveredApp } ?? apps.first
    }

    @ViewBuilder var notificationsWingLeftV2: some View {
        let apps = wingsApps
        if apps.isEmpty {
            WingLabel(symbol: "bell", text: "No new notifications")
        } else {
            let active = activeWingsApp(in: apps)?.id
            // The newest stands innermost, next to the notch; the others go outwards. The order
            // never changes: the hovered one's name opens in place and the others step aside.
            let shown = Array(apps.reversed())
            let activeIndex = shown.firstIndex { $0.id == active } ?? shown.count - 1
            HStack(spacing: 8) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, entry in
                    WingsAppIcon(
                        entry: entry, isActive: entry.id == active,
                        hover: {
                            guard entry.id != active else { return }
                            model.wings.stepsLeft = index < activeIndex
                            model.wings.holdsWidth = true
                            model.wings.hoveredApp = entry.id
                        },
                        open: { openWingsApp(entry) }
                    )
                }
            }
            .animation(AppleStyle.spring(response: 0.26, dampingFraction: 0.88), value: active)
        }
    }

    @ViewBuilder var notificationsWingRightV2: some View {
        if let active = activeWingsApp(in: wingsApps) {
            // The line steps the way the pointer went (spec PV-32).
            ZStack(alignment: .leading) {
                // Runs to its end when it does not fit (spec PV-38).
                WingsMarquee(text: active.line, repeats: false)
                    .id(active.id)
                    .transition(.push(from: model.wings.stepsLeft ? .trailing : .leading))
            }
            .animation(AppleStyle.spring(response: 0.26, dampingFraction: 0.88), value: active.id)
        }
    }

    /// A click on an app: the panel opens on that app's notifications (spec PV-17, B-6).
    private func openWingsApp(_ entry: WingsApp) {
        if entry.id == WingsApp.mailID {
            model.notificationsTab = .mail
        } else if let app = entry.app {
            notifications.setFocus(bundleID: app.identifier, name: app.name, count: nil)
            model.notificationsTab = .all
        }
        openFully()
    }

    // MARK: Notes (spec PV-34)

    @ViewBuilder var notesWingLeftV2: some View {
        Group {
            if let latest = notes.latest {
                HStack(spacing: 6) {
                    WingSymbol("note.text")
                    WingText(latest.name, bold: true)
                }
            } else {
                WingLabel(symbol: "note.text", text: noteFirstLine ?? "Notes")
            }
        }
        .onAppear { notes.refreshLatest() }
    }

    @ViewBuilder var notesWingRightV2: some View {
        let body = notes.latest.map { Self.noteBody($0.text) } ?? ""
        if !body.isEmpty {
            // Runs once to its end and stays there.
            WingsMarquee(text: body, dim: true, repeats: false)
        }
    }

    private var noteFirstLine: String? {
        notes.text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
    }

    /// The note's text from its second line, on one line.
    static func noteBody(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .dropFirst()
            .joined(separator: " · ")
    }

    // MARK: Clipboard (spec PV-22, PV-35)

    /// The three newest, the newest next to the notch.
    @ViewBuilder var clipboardWingLeftV2: some View {
        let items = Array(clipboard.history.prefix(3))
        if items.isEmpty {
            WingLabel(symbol: "doc.on.clipboard", text: "Nothing copied yet")
        } else {
            clipRow(items.reversed())
        }
    }

    /// The next three, outwards from the notch.
    var clipboardWingRightV2: some View {
        clipRow(Array(clipboard.history.dropFirst(3).prefix(3)))
    }

    /// Hovered, an item opens as far as its wing allows; the row's others shrink to dots at the
    /// edges. Left, it stays open two more seconds (spec PV-35, PV-46).
    private func clipRow(_ items: [ClipItem]) -> some View {
        let hovered = model.wings.hoveredClip
        let rowHasHover = items.contains { $0.id.uuidString == hovered }
        let motion = AppleStyle.spring(response: 0.3, dampingFraction: 0.86)
        return HStack(spacing: 6) {
            ForEach(items) { item in
                let key = item.id.uuidString
                WingsClip(
                    item: item, image: item.kind == .image ? clipboard.image(of: item) : nil,
                    isOpen: key == hovered, isDot: rowHasHover && key != hovered
                ) { clipboard.copy(item) }
                .onHover { inside in
                    guard inside else { return }
                    model.wings.clipMoves += 1
                    model.wings.holdsWidth = true
                    if model.wings.hoveredClip != key {
                        withAnimation(motion) { model.wings.hoveredClip = key }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { inside in
            guard !inside, rowHasHover else { return }
            model.wings.clipMoves += 1
            let move = model.wings.clipMoves
            Task { [model] in
                try? await Task.sleep(for: Self.clipFoldDelay)
                guard model.wings.clipMoves == move, model.wings.hoveredClip != nil else { return }
                withAnimation(motion) { model.wings.hoveredClip = nil }
            }
        }
    }

    /// How long an item left by the pointer stays open (spec PV-46).
    static let clipFoldDelay: Duration = .seconds(2)
}

/// A clipboard item in the wings: a chip, opened wide while hovered, or a dot (spec PV-35).
struct WingsClip: View {
    let item: ClipItem
    let image: NSImage?
    let isOpen: Bool
    let isDot: Bool
    let copy: () -> Void

    var body: some View {
        Button(action: copy) {
            Group {
                if isDot {
                    Circle()
                        .fill(Color.white.level(0.55))
                        .frame(width: 6, height: 6)
                        .frame(width: 14, height: 18)
                } else if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: isOpen ? 40 : 26, height: isOpen ? 18 : 16)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    Text(text)
                        .font(.notch(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.level(isOpen ? 1 : 0.85))
                        .lineLimit(1)
                        .frame(maxWidth: isOpen ? nil : 90, alignment: .leading)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.level(isOpen ? 0.2 : 0.12)))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .layoutPriority(isOpen ? 1 : 0)
        .help("Copy")
    }

    /// One line of the text.
    private var text: String {
        item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
    }
}

/// An app with new notifications in the Wings (spec PV-17).
struct WingsApp: Identifiable, Equatable {
    static let mailID = "dynotch.mail"

    let id: String
    let name: String
    let count: Int
    let date: Date
    let app: NotificationApp?
    let line: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.count == rhs.count && lhs.line == rhs.line
    }
}

/// An app's icon with its count; the active one also shows its name, which opens and closes.
struct WingsAppIcon: View {
    let entry: WingsApp
    let isActive: Bool
    let hover: () -> Void
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 0) {
                WingCount(count: entry.count) {
                    if let app = entry.app {
                        AppIconView(app: app, size: 16)
                    } else {
                        WingSymbol("envelope.fill")
                    }
                }
                // The name opens and closes in place, so the icons beside it step aside (spec PV-32).
                WingText(entry.name, bold: true)
                    .fixedSize()
                    .padding(.leading, 5)
                    .frame(width: isActive ? nil : 0, alignment: .leading)
                    .clipped()
                    .opacity(isActive ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Show \(entry.name)'s notifications")
        .onHover { if $0 { hover() } }
    }
}
