import AppKit
import SwiftUI

/// Starred answers (spec AI-15).
extension ClaudeChatService {
    struct Favorite: Identifiable, Equatable {
        let chatID: UUID
        let message: ChatMessage
        var id: UUID { message.id }
    }

    func toggleFavorite(_ messageID: UUID, in chatID: UUID) {
        update(chatID) { chat in
            guard let index = chat.messages.firstIndex(where: { $0.id == messageID }) else { return }
            chat.messages[index].isFavorite = chat.messages[index].isFavorite == true ? nil : true
        }
        save()
    }

    /// The starred answers of one service, the newest first.
    func favorites(of provider: AIProvider) -> [Favorite] {
        Self.favorites(in: chats.filter { $0.service == provider })
    }

    nonisolated static func favorites(in chats: [ClaudeChat]) -> [Favorite] {
        chats.flatMap { chat in
            chat.messages.filter { $0.isFavorite == true }.map { Favorite(chatID: chat.id, message: $0) }
        }
        .sorted { $0.message.date > $1.message.date }
    }

    /// macOS dictation into the focused field (spec AI-14): no microphone permission of our own.
    static func startDictation() {
        NSApp.sendAction(Selector(("startDictation:")), to: nil, from: nil)
    }
}

/// The starred answers in the chat list; a click opens the chat (spec AI-15).
struct AIFavoritesSection: View {
    @ObservedObject var service: ClaudeChatService

    var body: some View {
        let favorites = service.favorites(of: service.shownProvider)
        if !favorites.isEmpty {
            Text("FAVORITES")
                .font(.notch(size: 9, weight: .bold))
                .foregroundStyle(Color.white.level(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.top, 8)
            ForEach(favorites) { favorite in
                Button {
                    service.select(favorite.chatID)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").font(.notch(size: 8)).foregroundStyle(.yellow)
                        Text(favorite.message.text.replacingOccurrences(of: "\n", with: " "))
                            .font(.notch(size: 11))
                            .foregroundStyle(Color.white.level(0.75))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.notch)
                .help(String(favorite.message.text.prefix(300)))
                .contextMenu {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(favorite.message.text, forType: .string)
                    }
                    Button("Remove from Favorites") { service.toggleFavorite(favorite.message.id, in: favorite.chatID) }
                }
            }
        }
    }
}
