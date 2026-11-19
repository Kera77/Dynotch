import SwiftUI

// MARK: - DyNotch Wings content per module, v0.75 (spec PV-15, PV-17, PV-19, PV-22)

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
            // The newest stands innermost, next to the notch; the others go outwards.
            HStack(spacing: 8) {
                ForEach(apps.reversed()) { entry in
                    WingsAppIcon(
                        entry: entry, isActive: entry.id == active,
                        hover: { model.wings.hoveredApp = entry.id },
                        open: { openWingsApp(entry) }
                    )
                }
            }
            .animation(Motion.quick, value: active)
        }
    }

    @ViewBuilder var notificationsWingRightV2: some View {
        if let active = activeWingsApp(in: wingsApps) {
            WingText(active.line)
                .id(active.id)
                .transition(.opacity)
                .animation(Motion.quick, value: active.id)
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

    // MARK: Notes (spec PV-19)

    @ViewBuilder var notesWingLeftV2: some View {
        Group {
            if let latest = notes.latest {
                HStack(spacing: 6) {
                    WingSymbol("note.text")
                    WingsMarquee(text: "\(latest.folder) › \(latest.name)", bold: true)
                }
            } else {
                WingLabel(symbol: "note.text", text: noteFirstLine ?? "Empty note")
            }
        }
        .onAppear { notes.refreshLatest() }
    }

    @ViewBuilder var notesWingRightV2: some View {
        let body = notes.latest.map { Self.noteBody($0.text) } ?? ""
        if !body.isEmpty {
            WingsMarquee(text: body, dim: true)
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

    // MARK: Clipboard (spec PV-22)

    /// The three newest, the newest next to the notch.
    @ViewBuilder var clipboardWingLeftV2: some View {
        let items = Array(clipboard.history.prefix(3))
        if items.isEmpty {
            WingLabel(symbol: "doc.on.clipboard", text: "Nothing copied yet")
        } else {
            HStack(spacing: 6) {
                ForEach(items.reversed()) { item in clipChip(item) }
            }
        }
    }

    /// The next three, outwards from the notch.
    var clipboardWingRightV2: some View {
        HStack(spacing: 6) {
            ForEach(Array(clipboard.history.dropFirst(3).prefix(3))) { item in clipChip(item) }
        }
    }

    private func clipChip(_ item: ClipItem) -> some View {
        Button { clipboard.copy(item) } label: {
            Group {
                if item.kind == .image, let image = clipboard.image(of: item) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 26, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.notch(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.level(0.85))
                        .lineLimit(1)
                        .frame(maxWidth: 90)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.level(0.12)))
                }
            }
        }
        .buttonStyle(.notch)
        .help("Copy")
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
            HStack(spacing: 5) {
                WingCount(count: entry.count) {
                    if let app = entry.app {
                        AppIconView(app: app, size: 16)
                    } else {
                        WingSymbol("envelope.fill")
                    }
                }
                if isActive {
                    WingText(entry.name, bold: true)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Show \(entry.name)'s notifications")
        .onHover { if $0 { hover() } }
    }
}
