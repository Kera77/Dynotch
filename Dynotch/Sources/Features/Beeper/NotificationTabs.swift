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

    /// The Beeper and Google Chat tabs need the larger panel (spec BP-1).
    var isWide: Bool { self == .beeper || self == .googleChat }
}

@MainActor
enum ChatSources {
    nonisolated static func isBeeper(_ notification: AppNotification) -> Bool {
        notification.appIdentifier.lowercased().contains("beeper")
    }

    static func isGoogleChat(_ notification: AppNotification, catalog: NotificationAppCatalog) -> Bool {
        if notification.site == "chat.google.com" || notification.appIdentifier == WebNotificationSource.siteIdentifier("chat.google.com") {
            return true
        }
        let name = catalog.app(for: notification.appIdentifier).name.lowercased()
        return name.contains("google chat") || (name == "chat" && notification.appIdentifier.lowercased().contains("webapp"))
    }
}

/// Answers sent to Google Chat from the notch, shown in the conversation (spec GC-3).
@MainActor
final class GoogleChatReplies: ObservableObject {
    static let shared = GoogleChatReplies()

    struct Reply: Identifiable {
        let id = UUID()
        let conversation: String
        let text: String
        let date: Date
    }

    @Published private(set) var replies: [Reply] = []

    func add(_ text: String, to conversation: String) {
        replies.append(Reply(conversation: conversation, text: text, date: Date()))
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
            // Changing tabs slides, like the tray's folders (spec UM-8).
            content
                .id(tab)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
        .animation(Motion.quick, value: tab)
        .clipped()
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .all:
            VStack(spacing: 6) {
                UnreadChatsSection(beeper: beeper) { open($0) }
                NotificationsFeatureView(service: service, isActive: isActive)
            }
        case .chats:
            // Unread Beeper chats as notification cards, like before Beeper got its own tab;
            // Beeper's own notifications would be the same messages twice (spec UM-9).
            let cards = beeper.keepsUnread && beeper.state == .ready && !beeper.unreadChats.isEmpty
            NotificationsFeatureView(
                service: service,
                isActive: isActive,
                include: { notification in
                    ChatSources.isGoogleChat(notification, catalog: service.catalog)
                        || (!cards && ChatSources.isBeeper(notification))
                },
                leading: cards ? AnyView(BeeperUnreadCards(beeper: beeper, open: open)) : nil
            )
        case .beeper:
            BeeperTabView(service: beeper)
        case .googleChat:
            GoogleChatTabView(service: service, showsList: beeper.showsChatList) { beeper.showsChatList.toggle() }
        }
    }

    private func open(_ chat: BeeperChatInfo) {
        withAnimation(Motion.quick) { tab = .beeper }
        beeper.open(chat.id)
    }
}

/// Unread Beeper chats on top of the notifications (spec UM-2, UM-5).
struct UnreadChatsSection: View {
    @ObservedObject var beeper: BeeperService
    let open: (BeeperChatInfo) -> Void

    var body: some View {
        if beeper.keepsUnread, !beeper.unreadChats.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Unread")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(beeper.unreadChats.prefix(12)) { chat in
                            Button {
                                open(chat)
                            } label: {
                                HStack(spacing: 6) {
                                    BeeperAvatar(image: beeper.avatar(chat.pictureURL), name: chat.name, network: chat.network, size: 24)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(chat.name).font(.system(size: 11, weight: .bold)).lineLimit(1)
                                        Text(chat.preview?.text ?? "").font(.system(size: 10)).opacity(0.7).lineLimit(1)
                                    }
                                    .frame(maxWidth: 130, alignment: .leading)
                                    Text("\(chat.unread)").font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 5).background(Capsule().fill(BeeperStyle.blue))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.never)
            }
            .padding(.horizontal, 14)
        }
    }
}

/// Google Chat without its API (spec GC-1…GC-4): the conversations from the notifications that
/// are still in Notification Center, answered by typing into Google Chat.
struct GoogleChatTabView: View {
    @ObservedObject var service: NotificationService
    let showsList: Bool
    let toggleList: () -> Void
    @ObservedObject private var replies = GoogleChatReplies.shared
    @State private var selected: String?

    private var conversations: [(name: String, messages: [AppNotification])] {
        let chats = service.recent.filter { ChatSources.isGoogleChat($0, catalog: service.catalog) }
        let grouped = Dictionary(grouping: chats) { service.content(for: $0).sender }
        return grouped.map { ($0.key, $0.value.sorted { $0.date < $1.date }) }
            .sorted { ($0.messages.last?.date ?? .distantPast) > ($1.messages.last?.date ?? .distantPast) }
    }

    var body: some View {
        let all = conversations
        let current = all.first { $0.name == selected } ?? all.first
        HStack(spacing: 0) {
            if showsList {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 2) {
                        ForEach(all, id: \.name) { conversation in
                            listRow(conversation, isSelected: conversation.name == current?.name)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(width: BeeperStyle.listWidth)
                Divider().overlay(Color.white.opacity(0.08))
            }
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Button(action: toggleList) { Image(systemName: "sidebar.left") }.buttonStyle(.plain)
                    if let current {
                        BeeperAvatar(image: nil, name: current.name, network: "google", size: 24)
                        Text(current.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Spacer()
                        Button {
                            if let last = current.messages.last { service.catalog.open(last.appIdentifier) }
                        } label: { Image(systemName: "arrow.up.forward.app") }
                            .buttonStyle(.plain)
                            .help("Open Google Chat")
                            .accessibilityLabel("Open Google Chat")
                    } else {
                        Spacer()
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 34)
                if let current {
                    conversation(current)
                } else {
                    EmptyStateView(symbol: "bubble.left", text: "Unread Google Chat messages appear here.")
                }
            }
        }
    }

    private func listRow(_ conversation: (name: String, messages: [AppNotification]), isSelected: Bool) -> some View {
        Button {
            selected = conversation.name
        } label: {
            HStack(spacing: 10) {
                BeeperAvatar(image: nil, name: conversation.name, network: "google")
                VStack(alignment: .leading, spacing: 2) {
                    Text(conversation.name).font(.system(size: 13, weight: .bold)).lineLimit(1)
                    Text(conversation.messages.last.map { service.content(for: $0).detail } ?? "")
                        .font(.system(size: 11)).opacity(0.75).lineLimit(1)
                }
                Spacer(minLength: 4)
                Text("\(conversation.messages.count)").font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6).background(Capsule().fill(BeeperStyle.blue))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(isSelected ? 0.12 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func conversation(_ current: (name: String, messages: [AppNotification])) -> some View {
        VStack(spacing: 6) {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(current.messages) { message in
                        HStack {
                            Text(service.content(for: message).detail)
                                .font(.system(size: 13)).foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BeeperStyle.incoming))
                            Spacer(minLength: 60)
                        }
                    }
                    ForEach(replies.replies.filter { $0.conversation == current.name }) { reply in
                        HStack {
                            Spacer(minLength: 60)
                            Text(reply.text)
                                .font(.system(size: 13)).foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BeeperStyle.blue))
                        }
                    }
                }
                .padding(.horizontal, 10)
            }
            .scrollIndicators(.never)
            if let last = current.messages.last {
                NotificationReplyField(service: service, target: last, sent: { text in
                    replies.add(text, to: current.name)
                })
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            }
        }
    }
}
