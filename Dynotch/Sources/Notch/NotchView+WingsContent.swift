import SwiftUI

// MARK: - DyNotch Wings content per module (spec PV-15, PV-32, PV-34, PV-35)

extension NotchView {
    // MARK: Notifications (spec PV-17)

    /// The apps with new notifications, newest first; Mail's unread first when it is the source.
    var wingsApps: [WingsApp] {
        // Beeper's unread chats count as Beeper, without its notifications of the same messages (spec PV-52).
        let chats = beeper.keepsUnread && beeper.state == .ready ? beeper.unreadChats : []
        let shown = chats.isEmpty ? notifications.recent : notifications.recent.filter { !ChatSources.isBeeper($0) }
        var apps = Dictionary(grouping: shown, by: \.appIdentifier)
            .compactMap { key, list -> WingsApp? in
                guard let newest = list.max(by: { $0.date < $1.date }) else { return nil }
                let app = notifications.catalog.app(for: key)
                let content = notifications.content(for: newest)
                let line = "\(content.sender) · \(content.detail)"
                return WingsApp(id: key, name: app.name, count: list.count, date: newest.date, app: app, line: line)
            }
        if let entry = beeperWingsApp(chats) { apps.append(entry) }
        apps.sort { $0.date > $1.date }
        if notifications.mail.isActive, notifications.mail.totalUnread > 0 {
            let count = notifications.mail.totalUnread
            apps.insert(WingsApp(id: WingsApp.mailID, name: "Mail", count: count, date: .now, app: nil, line: "\(count) unread"), at: 0)
        }
        return Array(apps.prefix(geometry.isRoomy ? 9 : 5))
    }

    /// Beeper's unread chats as one app: the newest chat's sender and message.
    private func beeperWingsApp(_ chats: [BeeperChatInfo]) -> WingsApp? {
        let dated = chats.map { chat in
            (chat, (chat.preview?.timestamp ?? chat.lastActivity).flatMap(BeeperAPI.date(from:)) ?? .distantPast)
        }
        guard let (newest, date) = dated.max(by: { $0.1 < $1.1 }) else { return nil }
        let identifier = notifications.recent.first(where: ChatSources.isBeeper)?.appIdentifier ?? "com.automattic.beeper.desktop"
        let app = notifications.catalog.app(for: identifier)
        let sender = newest.preview?.senderName.flatMap { $0.isEmpty ? nil : $0 } ?? newest.name
        let text = newest.preview?.text ?? ""
        let line = text.isEmpty ? sender : "\(sender) · \(text)"
        let count = chats.reduce(0) { $0 + $1.unread }
        return WingsApp(id: WingsApp.beeperID, name: "Beeper", count: count, date: date, app: app, line: line)
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
            .animation(Motion.quick, value: active)
        }
    }

    @ViewBuilder var notificationsWingRightV2: some View {
        if let active = activeWingsApp(in: wingsApps) {
            HStack(spacing: 6) {
                // The line steps the way the pointer went (spec PV-32).
                ZStack(alignment: .leading) {
                    // Runs to its end when it does not fit (spec PV-38).
                    // The app's name before its message, so the icons on the left stay put (spec PV-70).
                    HStack(spacing: 6) {
                        WingText(active.name, bold: true).fixedSize()
                        WingsMarquee(text: active.line, repeats: false)
                    }
                    .id(active.id)
                        .transition(.push(from: model.wings.stepsLeft ? .trailing : .leading))
                }
                .animation(Motion.quick, value: active.id)
                // At the right edge: removes the shown app's notifications from Dynotch (spec PV-64).
                if active.id != WingsApp.mailID, active.id != WingsApp.beeperID {
                    Button { removeWingsApp(active) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.notch(size: 13))
                            .foregroundStyle(Color.white.level(0.55))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.notch)
                    .help("Remove these notifications")
                    .accessibilityLabel("Remove")
                }
            }
        }
    }

    private func removeWingsApp(_ entry: WingsApp) {
        let shown = notifications.recent.filter { $0.appIdentifier == entry.id }
        withAnimation(Motion.quick) { shown.forEach { notifications.remove($0) } }
    }

    /// A click on an app: the panel opens on that app's notifications (spec PV-17, B-6).
    private func openWingsApp(_ entry: WingsApp) {
        if entry.id == WingsApp.mailID {
            model.notificationsTab = .mail
        } else if entry.id == WingsApp.beeperID || ChatSources.isBeeper(entry.id) {
            // The chat apps open on their own tab, like their badges (spec PV-72).
            notifications.clearFocus()
            model.notificationsTab = .beeper
        } else if isGoogleChatApp(entry) {
            notifications.clearFocus()
            model.notificationsTab = .googleChat
        } else if let app = entry.app {
            notifications.setFocus(bundleID: app.identifier, name: app.name, count: nil)
            model.notificationsTab = .all
        }
        openFully()
    }

    private func isGoogleChatApp(_ entry: WingsApp) -> Bool {
        notifications.recent.contains { $0.appIdentifier == entry.id && ChatSources.isGoogleChat($0, catalog: notifications.catalog) }
    }

    // MARK: Notes (spec PV-34, PV-60)

    var notesWingLeftV2: some View { NotesWing(notes: notes, side: .left) }

    var notesWingRightV2: some View { NotesWing(notes: notes, side: .right) }

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
        let items = Array(clipboard.history.prefix(clipsPerWing))
        if items.isEmpty {
            WingLabel(symbol: "doc.on.clipboard", text: "Nothing copied yet")
        } else {
            clipRow(items.reversed())
        }
    }

    /// The next three, outwards from the notch.
    var clipboardWingRightV2: some View {
        clipRow(Array(clipboard.history.dropFirst(clipsPerWing).prefix(clipsPerWing)))
    }

    /// Three items a side, five on a large display (spec PV-75).
    private var clipsPerWing: Int { geometry.isRoomy ? 5 : 3 }

    /// Hovered, an item opens as far as its wing allows; the row's others shrink to dots at the
    /// edges. Left, it stays open two more seconds (spec PV-35, PV-46).
    private func clipRow(_ items: [ClipItem]) -> some View {
        let hovered = model.wings.hoveredClip
        let rowHasHover = items.contains { $0.id.uuidString == hovered }
        // Hovered, the row keeps the wing's width and the open item stands where the pointer
        // is, so a short text never pulls it away from under the pointer (spec PV-53).
        let fills = rowHasHover && items.count > 1
        return HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let key = item.id.uuidString
                WingsClip(
                    item: item, image: item.kind == .image ? clipboard.image(of: item) : nil,
                    isOpen: key == hovered, isDot: rowHasHover && key != hovered
                ) { clipboard.copy(item) }
                .frame(
                    maxWidth: fills && key == hovered ? .infinity : nil,
                    alignment: index == 0 ? .leading : index == items.count - 1 ? .trailing : .center
                )
                .contentShape(Rectangle())
                .onHover { inside in
                    if inside { openWingItem(key) }
                }
            }
        }
        .frame(maxWidth: fills ? .infinity : nil)
        .contentShape(Rectangle())
        .onHover { inside in
            if !inside, rowHasHover { foldWingItemLater() }
        }
    }

    static var wingItemMotion: Animation { Motion.spring }

    /// The pointer on an item of a clipboard or tray row: it opens, and the wings keep their
    /// width (spec PV-35, PV-40, PV-61).
    func openWingItem(_ key: String) {
        model.wings.clipMoves += 1
        model.wings.holdsWidth = true
        if model.wings.hoveredClip != key {
            withAnimation(Self.wingItemMotion) { model.wings.hoveredClip = key }
        }
    }

    /// The pointer left the row: the open item stays two more seconds (spec PV-46, PV-54).
    func foldWingItemLater() {
        model.wings.clipMoves += 1
        let move = model.wings.clipMoves
        Task { [model] in
            try? await Task.sleep(for: Self.clipFoldDelay)
            guard model.wings.clipMoves == move, model.wings.hoveredClip != nil else { return }
            withAnimation(Self.wingItemMotion) { model.wings.hoveredClip = nil }
            // Left below the wings, they close now (spec PV-54).
            model.recheckPointer()
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
    static let beeperID = "dynotch.beeper-chats"

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

/// An app's icon with its count; the active one is lit (spec PV-70).
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
            }
            // The icons never move: the active one is lit, its name stands on the right (spec PV-70).
            .opacity(isActive ? 1 : 0.55)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Show \(entry.name)'s notifications")
        .onHover { if $0 { hover() } }
    }
}

/// The AI wings: the AI chosen in the module at the left, its session at the right (spec PV-50).
struct AIWing: View {
    enum Side { case left, right }

    var usage: ClaudeUsageService
    var chat: ClaudeChatService
    /// The merged AI module's chat tab is the current one: its own AI counts.
    let isChat: Bool
    let side: Side

    /// The AI picked in the usage view (spec AI-6).
    @AppStorage("usageProvider") private var usageProvider = AIProvider.claude.rawValue

    private var provider: AIProvider {
        isChat ? chat.provider : AIProvider(rawValue: usageProvider) ?? .claude
    }

    var body: some View {
        switch side {
        case .left:
            HStack(spacing: 6) {
                AIProviderLogo(provider: provider)
                WingText(provider.title, bold: true)
            }
        case .right:
            session
        }
    }

    /// The five-hour session: Claude's, or ChatGPT's primary window.
    private var limit: UsageLimit? {
        switch provider {
        case .claude: usage.limits.first { $0.id == "five_hour" } ?? usage.session
        case .chatgpt: usage.gptLimits.first { $0.id == "gpt_primary" } ?? usage.gptLimits.first
        }
    }

    @ViewBuilder private var session: some View {
        if let limit {
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
                .onAppear { if provider == .chatgpt { usage.refreshChatGPT() } }
        }
    }
}

/// Claude's mark, or the ChatGPT app's icon.
struct AIProviderLogo: View {
    let provider: AIProvider

    var body: some View {
        switch provider {
        case .claude:
            BrandGlyphView(glyph: .claude, size: 14)
        case .chatgpt:
            if let icon = BadgeIconCache.appIcon(bundleID: "com.openai.chat") ?? BadgeIconCache.appIcon(bundleID: "com.openai.codex") {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            } else {
                WingSymbol("bubble.left.and.text.bubble.right")
            }
        }
    }
}
