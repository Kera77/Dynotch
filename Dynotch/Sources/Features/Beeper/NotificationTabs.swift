import SwiftUI

/// The notifications module's tabs (spec UM-8), and one per highlighted Beeper network (spec BP-15).
enum NotificationsTab: Hashable, Sendable, RawRepresentable {
    case all
    case chats
    case beeper
    case googleChat
    /// The web Teams' chats (spec MT-3).
    case teams
    /// The unread mail of the accounts read from Apple Mail (spec GM-6).
    case mail
    /// A highlighted Beeper network's unread chats (spec BP-15).
    case network(String)

    private static let networkPrefix = "network:"

    init?(rawValue: String) {
        switch rawValue {
        case "all": self = .all
        case "chats": self = .chats
        case "beeper": self = .beeper
        case "googleChat": self = .googleChat
        case "teams": self = .teams
        case "mail": self = .mail
        default:
            guard rawValue.hasPrefix(Self.networkPrefix) else { return nil }
            self = .network(String(rawValue.dropFirst(Self.networkPrefix.count)))
        }
    }

    var rawValue: String {
        switch self {
        case .all: "all"
        case .chats: "chats"
        case .beeper: "beeper"
        case .googleChat: "googleChat"
        case .teams: "teams"
        case .mail: "mail"
        case .network(let name): Self.networkPrefix + name
        }
    }

    var title: String {
        switch self {
        case .all: "All"
        case .chats: "Chats"
        case .beeper: "Beeper"
        case .googleChat: "Google Chat"
        case .teams: "Teams"
        case .mail: "Mail"
        case .network(let name): name
        }
    }

    /// The tabs in the picker and the swipe order: the highlighted networks after Beeper
    /// (spec BP-15), Mail only with Mail as Gmail's source (spec GM-6).
    /// Teams once the web Teams was read or sent a notification (spec MT-3).
    static func shown(mail: Bool, networks: [String] = [], teams: Bool = false) -> [Self] {
        [.all, .chats, .beeper] + networks.map(Self.network) + [.googleChat] + (teams ? [.teams] : []) + (mail ? [.mail] : [])
    }

    /// The Beeper tab needs the larger panel (spec BP-1); Google Chat is a list like All (spec GC-6).
    var isWide: Bool { self == .beeper }
}

@MainActor
enum ChatSources {
    nonisolated static func isBeeper(_ notification: AppNotification) -> Bool {
        isBeeper(notification.appIdentifier)
    }

    nonisolated static func isBeeper(_ appIdentifier: String) -> Bool {
        appIdentifier.lowercased().contains("beeper")
    }

    /// True when a chat of that name is known and has nothing unread; an unknown name stays.
    nonisolated static func isRead(chatNamed name: String, in chats: [BeeperChatInfo]) -> Bool {
        let wanted = name.trimmingCharacters(in: .whitespaces).lowercased()
        let matching = chats.filter { $0.name.lowercased() == wanted }
        return !matching.isEmpty && matching.allSatisfy { $0.unread == 0 }
    }

    static func isGoogleChat(_ notification: AppNotification, catalog: NotificationAppCatalog) -> Bool {
        if notification.site == "chat.google.com" || notification.appIdentifier == WebNotificationSource.siteIdentifier("chat.google.com") {
            return true
        }
        let name = catalog.app(for: notification.appIdentifier).name.lowercased()
        return name.contains("google chat") || (name == "chat" && notification.appIdentifier.lowercased().contains("webapp"))
    }
}

/// The notifications module with its tabs (spec UM-5, UM-8).
struct NotificationsTabsView: View {
    var service: NotificationService
    var beeper: BeeperService
    var mail: MailService
    @Binding var tab: NotificationsTab
    var isActive = false
    /// The pointer is over the tab picker: only there a swipe steps between the tabs (spec UM-8d).
    var onHoverTabs: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                CapsulePicker(
                    items: NotificationsTab.shown(
                        mail: mail.isActive, networks: beeper.highlightedNetworks, teams: TeamsService.shared.showsTab(service)
                    ),
                    selection: $tab, title: \.title
                ) { item in
                    switch item {
                    case .beeper: beeper.unreadTotal
                    case .network(let name): beeper.unreadTotal(network: name)
                    case .mail: mail.state == .reading ? mail.totalUnread : nil
                    case .teams: TeamsService.shared.snapshot.map { $0.unread.count }.flatMap { $0 > 0 ? $0 : nil }
                    default: nil
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
            .onHover(perform: onHoverTabs)
            // The picker stays in sight however small the panel is (spec UM-8c).
            .layoutPriority(1)
            // Changing tabs slides, like the tray's folders (spec UM-8).
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .id(tab)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
        .animation(Motion.quick, value: tab)
        .clipped()
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .all:
            // Everything, the chats too (spec PV-52): Mail's unread above, standing for Gmail's
            // notifications (spec GM-6), then Beeper's unread chats as cards, without Beeper's
            // own notifications of the same messages.
            let cards = showsBeeperCards
            let showsMail = mail.isActive && mail.totalUnread > 0
            NotificationsFeatureView(
                service: service, isActive: isActive,
                include: { !readInBeeper($0) && !service.isShownByMail($0) && !(cards && ChatSources.isBeeper($0)) },
                leading: showsMail || cards ? AnyView(allLeading(mail: showsMail, cards: cards)) : nil
            )
        case .chats:
            // Unread Beeper chats as notification cards, like before Beeper got its own tab;
            // Beeper's own notifications would be the same messages twice (spec UM-9).
            let cards = showsBeeperCards
            NotificationsFeatureView(
                service: service,
                isActive: isActive,
                include: { notification in
                    ChatSources.isGoogleChat(notification, catalog: service.catalog)
                        || (!cards && ChatSources.isBeeper(notification) && !readInBeeper(notification))
                },
                leading: cards ? AnyView(BeeperUnreadCards(beeper: beeper, open: open)) : nil
            )
        case .beeper:
            BeeperTabView(service: beeper)
        case .mail:
            MailTabView(mail: mail)
        case .googleChat:
            // Only the unread messages, like the All tab (spec GC-6).
            NotificationsFeatureView(service: service, isActive: isActive) { ChatSources.isGoogleChat($0, catalog: service.catalog) }
        case .teams:
            TeamsTabView(teams: .shared, service: service, isActive: isActive)
        case .network(let name):
            BeeperNetworkTab(beeper: beeper, network: name) { open($0) }
        }
    }

    /// Beeper's unread chats stand as cards (spec UM-9, PV-52).
    private var showsBeeperCards: Bool {
        beeper.keepsUnread && beeper.state == .ready && !beeper.cardChats().isEmpty
    }

    @ViewBuilder private func allLeading(mail showsMail: Bool, cards: Bool) -> some View {
        if showsMail { MailUnreadList(mail: mail, limit: 3) }
        if cards { BeeperUnreadCards(beeper: beeper, open: open) }
    }

    /// A Beeper message whose chat Beeper no longer counts as unread goes from the list (spec UM-10).
    /// A highlighted network's message belongs to its own tab (spec BP-16).
    private func readInBeeper(_ notification: AppNotification) -> Bool {
        // Being answered from its card, it stays until the card is closed (spec E-32).
        guard ChatSources.isBeeper(notification), beeper.state == .ready, !service.isAnswering(notification) else { return false }
        return ChatSources.isRead(chatNamed: notification.title, in: beeper.chats) || beeper.isHighlighted(chatNamed: notification.title)
    }

    private func open(_ chat: BeeperChatInfo) {
        withAnimation(Motion.quick) { tab = .beeper }
        beeper.open(chat.id)
    }
}
