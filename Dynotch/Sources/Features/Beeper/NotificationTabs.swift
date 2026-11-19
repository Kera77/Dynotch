import SwiftUI

/// The notifications module's tabs (spec UM-8).
enum NotificationsTab: String, CaseIterable, Sendable {
    case all
    case chats
    case beeper
    case googleChat

    var title: String {
        switch self {
        case .all: "All"
        case .chats: "Chats"
        case .beeper: "Beeper"
        case .googleChat: "Google Chat"
        }
    }

    /// The Beeper tab needs the larger panel (spec BP-1); Google Chat is a list like All (spec GC-6).
    var isWide: Bool { self == .beeper }
}

@MainActor
enum ChatSources {
    nonisolated static func isBeeper(_ notification: AppNotification) -> Bool {
        notification.appIdentifier.lowercased().contains("beeper")
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
    @ObservedObject var service: NotificationService
    @ObservedObject var beeper: BeeperService
    @Binding var tab: NotificationsTab
    var isActive = false

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                CapsulePicker(items: NotificationsTab.allCases, selection: $tab, title: \.title) { item in
                    item == .beeper ? beeper.unreadTotal : nil
                }
                Spacer()
            }
            .padding(.horizontal, 14)
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
            // No unread bubbles here; the Chats tab has them as cards (spec UM-8b).
            NotificationsFeatureView(service: service, isActive: isActive) { !readInBeeper($0) }
        case .chats:
            // Unread Beeper chats as notification cards, like before Beeper got its own tab;
            // Beeper's own notifications would be the same messages twice (spec UM-9).
            let cards = beeper.keepsUnread && beeper.state == .ready && !beeper.unreadChats.isEmpty
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
        case .googleChat:
            // Only the unread messages, like the All tab (spec GC-6).
            NotificationsFeatureView(service: service, isActive: isActive) { ChatSources.isGoogleChat($0, catalog: service.catalog) }
        }
    }

    /// A Beeper message whose chat Beeper no longer counts as unread goes from the list (spec UM-10).
    private func readInBeeper(_ notification: AppNotification) -> Bool {
        guard ChatSources.isBeeper(notification), beeper.state == .ready else { return false }
        return ChatSources.isRead(chatNamed: notification.title, in: beeper.chats)
    }

    private func open(_ chat: BeeperChatInfo) {
        withAnimation(Motion.quick) { tab = .beeper }
        beeper.open(chat.id)
    }
}
