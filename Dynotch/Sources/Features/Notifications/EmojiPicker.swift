import SwiftUI

/// A small emoji picker that opens under its button (spec E-18): recently used first, then by
/// category; a click puts the emoji into the text.
struct EmojiButton: View {
    @Binding var text: String
    var size: CGFloat = 15

    @State private var isOpen = false
    @Environment(\.pinNotch) private var pinNotch

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            Image(systemName: "face.smiling")
                .font(.system(size: size))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 26, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Emoji")
        .accessibilityLabel("Emoji")
        .onHover { if $0 { isOpen = true } }
        // The picker hangs below the notch: keep the notch open meanwhile.
        .onChange(of: isOpen) { _, open in if open { pinNotch() } }
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            EmojiGrid { emoji in
                text += emoji
                EmojiGrid.remember(emoji)
            }
        }
    }
}

struct EmojiGrid: View {
    let pick: (String) -> Void

    @State private var category = 0

    static let categories: [(symbol: String, emoji: String)] = [
        ("face.smiling", "😀 😃 😄 😁 😆 😅 😂 🤣 🙂 🙃 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😋 😛 😜 🤪 😝"
            + " " + "🤗 🤭 🤫 🤔 🤐 🤨 😐 😑 😶 😏 😒 🙄 😬 😌 😔 😪 🤤 😴 😷 🤒 🤕 🥵 🥶 🥴"
            + " " + "😵 🤯 🤠 🥳 😎 🤓 🧐 😕 😟 🙁 😮 😯 😲 😳 🥺 😦 😧 😨 😰 😥 😢 😭 😱 😖"
            + " " + "😣 😞 😓 😩 😫 🥱 😤 😡 😠 🤬 😈 💀 💩 🤡 👻 👽 🤖"),
        ("hand.thumbsup", "👍 👎 👌 🤌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ 👋 🤚 🖐️ ✋ 🖖 👏 🙌 👐 🤲 🙏"
            + " " + "✍️ 💪 🦾 🤝 👀 🧠 🫶"),
        ("heart", "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💯 💢 💥 💫 💦 💨"
            + " " + "🔥 ✨ ⭐ 🌟 ⚡ 🎉 🎊 🎈 🎁 🏆 🥇"),
        ("leaf", "🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🐔 🐧 🐦 🦄 🐝 🦋 🐢 🐍 🐙"
            + " " + "🐬 🐳 🌸 🌹 🌻 🌲 🌴 🍀 🍁 🌈 ☀️ 🌙 ❄️ ☔"),
        ("fork.knife", "🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🥑 🥦 🌽 🥕 🥐 🍞 🧀 🍳"
            + " " + "🥓 🍔 🍟 🍕 🌭 🌮 🍝 🍜 🍣 🍰 🎂 🍫 🍿 ☕ 🍵 🍺 🍷 🥂 🍾"),
        ("car", "🚗 🚕 🚌 🚎 🏎️ 🚓 🚑 🚒 🚲 🛴 🏍️ ✈️ 🚀 🛳️ 🚆 🏠 🏢 🏖️ ⛰️ 🗺️ ⚽ 🏀 🏈 🎾"
            + " " + "🏐 🎮 🎧 🎸 🎬 📷 💻 📱 ⌚ 💡 📌 📎 ✏️ 📅 ✅ ❌ ⚠️ ❓ ❗")
    ]

    private static let recentKey = "recentEmoji"

    static func remember(_ emoji: String) {
        var recent = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
        recent.removeAll { $0 == emoji }
        recent.insert(emoji, at: 0)
        UserDefaults.standard.set(Array(recent.prefix(16)), forKey: recentKey)
    }

    private var recent: [String] { UserDefaults.standard.stringArray(forKey: Self.recentKey) ?? [] }

    var body: some View {
        VStack(spacing: 6) {
            if !recent.isEmpty, category == 0 {
                row(recent)
                Divider()
            }
            ScrollView(.vertical) {
                row(Self.categories[category].emoji.split(separator: " ").map(String.init))
            }
            .frame(height: 150)
            HStack(spacing: 2) {
                ForEach(Self.categories.indices, id: \.self) { index in
                    Button {
                        category = index
                    } label: {
                        Image(systemName: Self.categories[index].symbol)
                            .font(.system(size: 11))
                            .frame(width: 26, height: 20)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(index == category ? 0.15 : 0)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .frame(width: 236)
    }

    private func row(_ emoji: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 3), count: 8), spacing: 3) {
            ForEach(Array(emoji.enumerated()), id: \.offset) { _, item in
                Button(item) { pick(item) }
                    .buttonStyle(.plain)
                    .font(.system(size: 18))
                    .frame(width: 24, height: 24)
            }
        }
    }
}
