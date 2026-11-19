import SwiftUI

/// A small emoji picker that opens under its button (spec E-18): recently used first, then by
/// category; a click puts the emoji into the text.
struct EmojiButton: View {
    @Binding var text: String
    var size: CGFloat = 15

    @State private var isOpen = false
    @State private var hover = HoverIntent()
    @Environment(\.pinNotch) private var pinNotch

    var body: some View {
        Button {
            isOpen.toggle()
            // Opened by a click: it stays until the next click (spec E-18b).
            hover.openedByHover = false
            if isOpen { pinNotch() }
        } label: {
            Image(systemName: "face.smiling")
                .font(.notch(size: size))
                .foregroundStyle(Color.white.level(0.7))
                .frame(width: 26, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .help("Emoji")
        .accessibilityLabel("Emoji")
        .onHover { inside in
            hover.overButton = inside
            if inside, !isOpen {
                isOpen = true
                hover.openedByHover = true
            }
            closeIfLeft()
        }
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            EmojiGrid { emoji in
                text += emoji
                EmojiGrid.remember(emoji)
            }
            .onHover { inside in
                hover.overPopover = inside
                closeIfLeft()
            }
        }
    }

    /// Opened by hover and the pointer went elsewhere, not onto the picker: it goes (spec E-18b).
    private func closeIfLeft() {
        DispatchQueue.main.asyncAfter(deadline: .now() + HoverIntent.grace) {
            if hover.shouldClose { isOpen = false }
        }
    }
}

/// A drop-down opened by hover closes once the pointer is neither on its button nor on it;
/// one opened by a click stays (spec E-18b).
struct HoverIntent {
    var openedByHover = false
    var overButton = false
    var overPopover = false

    static let grace: TimeInterval = 0.35

    var shouldClose: Bool { openedByHover && !overButton && !overPopover }
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
                            .font(.notch(size: 11))
                            .frame(width: 26, height: 20)
                            .background(RoundedRectangle(cornerRadius: AppleStyle.corner(5))
                                .fill(Color.primary.opacity(index == category ? 0.15 : 0)))
                    }
                    .buttonStyle(.notch)
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
                    .buttonStyle(.notch)
                    .font(.notch(size: 18))
                    .frame(width: 24, height: 24)
            }
        }
    }
}
