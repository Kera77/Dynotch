import AppKit
import SwiftUI

/// Beeper's look (spec BP-2): dark, round pictures with the network's badge, blue unread pills.
enum BeeperStyle {
    static let blue = Color(red: 0.04, green: 0.52, blue: 1)
    static let incoming = Color.white.opacity(0.12)
    static let listWidth: CGFloat = 240

    /// Words in the network's name → its colour and an SF Symbol; no brand logos.
    private struct NetworkLook {
        let words: [String]
        let color: Color
        let symbol: String

        init(_ words: [String], _ color: Color, _ symbol: String) {
            self.words = words
            self.color = color
            self.symbol = symbol
        }
    }

    private static let networks: [NetworkLook] = [
        NetworkLook(["whatsapp"], Color(red: 0.15, green: 0.83, blue: 0.4), "phone.fill"),
        NetworkLook(["messenger", "facebook"], Color(red: 0.0, green: 0.52, blue: 1), "bolt.fill"),
        NetworkLook(["instagram"], Color(red: 0.88, green: 0.19, blue: 0.42), "camera.fill"),
        NetworkLook(["telegram"], Color(red: 0.16, green: 0.63, blue: 0.89), "paperplane.fill"),
        NetworkLook(["signal"], Color(red: 0.23, green: 0.46, blue: 0.94), "bubble.left.fill"),
        NetworkLook(["imessage", "sms"], Color(red: 0.2, green: 0.78, blue: 0.35), "message.fill"),
        NetworkLook(["slack"], Color(red: 0.38, green: 0.15, blue: 0.4), "number"),
        NetworkLook(["discord"], Color(red: 0.35, green: 0.4, blue: 0.95), "gamecontroller.fill"),
        NetworkLook(["linkedin"], Color(red: 0.04, green: 0.4, blue: 0.76), "briefcase.fill"),
        NetworkLook(["google"], Color(red: 0.1, green: 0.62, blue: 0.35), "bubble.left.fill"),
        NetworkLook(["twitter"], Color.black, "xmark")
    ]

    static func network(_ name: String?) -> (color: Color, symbol: String) {
        let lowered = (name ?? "").lowercased()
        let found = networks.first { entry in entry.words.contains { lowered.contains($0) } }
        return found.map { ($0.color, $0.symbol) } ?? (Color.gray, "bubble.left.and.bubble.right.fill")
    }

    static func time(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if let week = calendar.date(byAdding: .day, value: -6, to: now), date > week {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

/// A round picture, or initials on a colour, with the network's badge (spec BP-3).
struct BeeperAvatar: View {
    let image: NSImage?
    let name: String
    let network: String?
    var size: CGFloat = 36

    private var initials: String {
        let words = name.split(separator: " ").prefix(2)
        return words.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private var colour: Color {
        let colours: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .green]
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colours[sum % colours.count]
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Text(initials)
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(colour.opacity(0.85))
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            if network != nil {
                let style = BeeperStyle.network(network)
                Image(systemName: style.symbol)
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.42, height: size * 0.42)
                    .background(Circle().fill(style.color))
                    .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                    .offset(x: 2, y: 2)
            }
        }
    }
}

/// The chats, unread first (spec BP-1, BP-2).
struct BeeperChatList: View {
    @ObservedObject var service: BeeperService

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 2) {
                ForEach(service.sortedChats) { chat in
                    row(chat)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.never)
    }

    private func row(_ chat: BeeperChatInfo) -> some View {
        let isSelected = chat.id == service.selectedChatID
        return Button {
            service.open(chat.id)
        } label: {
            HStack(spacing: 10) {
                BeeperAvatar(image: service.avatar(chat.imgURL), name: chat.name, network: chat.network)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(chat.name)
                            .font(.system(size: 13, weight: chat.unread > 0 ? .bold : .medium))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if chat.reminder != nil {
                            Image(systemName: "bell.fill").font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.5))
                        }
                        Text(BeeperStyle.time(lastDate(of: chat)))
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    HStack {
                        Text(previewText(chat))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(chat.unread > 0 ? 0.85 : 0.5))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if chat.unread > 0 {
                            Text("\(chat.unread)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .frame(minWidth: 18, minHeight: 16)
                                .background(Capsule().fill(BeeperStyle.blue))
                        }
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(isSelected ? 0.12 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func lastDate(of chat: BeeperChatInfo) -> Date? {
        chat.preview?.timestamp.flatMap(BeeperAPI.date(from:)) ?? chat.lastActivity.flatMap(BeeperAPI.date(from:))
    }

    private func previewText(_ chat: BeeperChatInfo) -> String {
        guard let preview = chat.preview else { return "" }
        let text = preview.text ?? "Attachment"
        if preview.isSender == true { return "You: " + text }
        if chat.isGroup, let sender = preview.senderName { return sender + ": " + text }
        return text
    }
}
