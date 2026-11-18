import AppKit
import SwiftUI

private struct CloseNotchKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
    /// Closes the notch, e.g. before pasting an answer into the app in front (spec AI-7).
    var closeNotch: @MainActor @Sendable () -> Void {
        get { self[CloseNotchKey.self] }
        set { self[CloseNotchKey.self] = newValue }
    }
}

/// The AI module's header (spec AI-1, AI-2, AI-8, AI-12): service, model, more thinking,
/// templates, continuing in Terminal.
struct AIChatHeader: View {
    @ObservedObject var service: ClaudeChatService

    var body: some View {
        HStack(spacing: 6) {
            CapsulePicker(
                items: AIProvider.allCases,
                selection: Binding(get: { service.shownProvider }, set: { service.choose(provider: $0) }),
                title: \.title
            )
            if service.shownProvider == .chatgpt { chatGPTModeMenu } else { modelMenu }
            Button {
                service.thinksHarder.toggle()
            } label: {
                Image(systemName: "brain")
                    .foregroundStyle(service.thinksHarder ? ClaudeUsageView.blue : Color.white.opacity(0.55))
            }
            .buttonStyle(.plain)
            .help(service.thinksHarder ? "Thinking harder: on" : "Think harder")
            Spacer(minLength: 4)
            templatesMenu
            if let chat = service.selected, chat.sessionID != nil {
                Button {
                    service.continueInTerminal(chat)
                } label: {
                    Image(systemName: "terminal").foregroundStyle(Color.white.opacity(0.65))
                }
                .buttonStyle(.plain)
                .help("Continue in Terminal (\(chat.service == .claude ? "Claude Code" : "Codex"))")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(.white)
    }

    private var modelMenu: some View {
        let models = service.shownProvider.models()
        let current = models.first { $0.id == service.shownModel }?.title ?? "Default"
        return Menu {
            Button("Default") { service.choose(model: nil) }
            ForEach(models) { model in
                Button(model.title) { service.choose(model: model.id) }
            }
        } label: {
            HStack(spacing: 3) {
                Text(current).font(.system(size: 11, weight: .semibold))
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(Color.white.opacity(0.8))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Model")
        .accessibilityLabel("Model")
    }

    /// Codex in the notch, or chatgpt.com (spec AI-16); Codex's models below.
    private var chatGPTModeMenu: some View {
        Menu {
            ForEach(ChatGPTMode.allCases, id: \.self) { mode in
                Button(mode.title) { service.chatGPTMode = mode }
            }
            if service.chatGPTMode == .codex {
                Divider()
                Button("Default model") { service.choose(model: nil) }
                ForEach(service.shownProvider.models()) { model in
                    Button(model.title) { service.choose(model: model.id) }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(chatGPTLabel)
                    .font(.system(size: 11, weight: .semibold))
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(Color.white.opacity(0.8))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("How ChatGPT answers")
    }

    private var chatGPTLabel: String {
        if service.chatGPTMode == .web { return "chatgpt.com" }
        return service.shownProvider.models().first { $0.id == service.shownModel }?.title ?? "Codex"
    }

    private var templatesMenu: some View {
        Menu {
            ForEach(ClaudeChatService.builtInTemplates, id: \.self) { template in
                Button(template) { service.useTemplate(template) }
            }
            if !service.customTemplates.isEmpty {
                Divider()
                ForEach(service.customTemplates, id: \.self) { template in
                    Button(String(template.prefix(40))) { service.useTemplate(template) }
                }
                Menu("Remove") {
                    ForEach(service.customTemplates, id: \.self) { template in
                        Button(String(template.prefix(40))) { service.removeTemplate(template) }
                    }
                }
            }
            Divider()
            Button("Save the Question as a Template") { service.saveTemplate() }
                .disabled(service.draft.trimmingCharacters(in: .whitespaces).isEmpty)
        } label: {
            Image(systemName: "text.badge.star").foregroundStyle(Color.white.opacity(0.65))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Templates")
        .accessibilityLabel("Templates")
    }
}

/// An answer: paragraphs with bold, italic, links; headings; code blocks with Copy (spec AI-7).
struct AIMessageContent: View {
    let text: String
    let isError: Bool

    private enum Part {
        case text(String)
        case code(String)
    }

    private var parts: [Part] {
        var result: [Part] = []
        let pieces = text.components(separatedBy: "```")
        for (index, piece) in pieces.enumerated() {
            if index.isMultiple(of: 2) {
                if !piece.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(.text(piece)) }
            } else {
                // The first line names the language.
                let code = piece.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                result.append(.code(code.count > 1 ? String(code[1]) : piece))
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                switch part {
                case .text(let paragraph):
                    Text(Self.formatted(paragraph))
                        .font(.system(size: 13))
                        .foregroundStyle(isError ? Color(red: 1, green: 0.5, blue: 0.45) : Color.white.opacity(0.92))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                case .code(let code):
                    codeBlock(code.trimmingCharacters(in: .newlines))
                }
            }
        }
    }

    private func codeBlock(_ code: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.6))
            .padding(.horizontal, 8)
            .padding(.top, 4)
            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .textSelection(.enabled)
                    .padding(8)
            }
            .scrollIndicators(.never)
        }
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.45)))
    }

    /// Headings ("# …") bold; the rest with inline Markdown, line breaks kept.
    nonisolated static func formatted(_ paragraph: String) -> AttributedString {
        let lines = paragraph.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            let trimmed = line.drop { $0 == " " }
            guard trimmed.hasPrefix("#") else { return String(line) }
            return "**" + trimmed.drop { $0 == "#" || $0 == " " } + "**"
        }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let joined = lines.joined(separator: "\n").trimmingCharacters(in: .newlines)
        return (try? AttributedString(markdown: joined, options: options)) ?? AttributedString(joined)
    }
}

/// Star, Copy and Insert under an answer (spec AI-7, AI-15).
struct AIAnswerActions: View {
    let text: String
    var isFavorite = false
    /// Stars the answer (spec AI-15); nil: no star.
    var toggleFavorite: (() -> Void)?
    @Environment(\.closeNotch) private var closeNotch

    var body: some View {
        HStack(spacing: 10) {
            if let toggleFavorite {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? Color.yellow : Color.white.opacity(0.55))
                }
                .help(isFavorite ? "Remove from Favorites" : "Add to Favorites")
                .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
            }
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            Button("Insert") {
                closeNotch()
                let answer = text
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { ClaudeChatService.insert(answer) }
            }
            .help("Paste the answer into the app in front")
            .accessibilityLabel("Paste the answer into the app in front")
        }
        .buttonStyle(.plain)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Color.white.opacity(0.55))
    }
}

/// Context for the next question (spec AI-5): clipboard, selected text, files; the files
/// attached so far.
struct AIContextBar: View {
    @ObservedObject var service: ClaudeChatService

    var body: some View {
        HStack(spacing: 8) {
            button("doc.on.clipboard", help: "Add the clipboard", action: service.addClipboard)
            button("text.cursor", help: "Add the text selected in the app in front", action: service.addSelectedText)
            button("paperclip", help: "Attach a file", action: chooseFile)
            ForEach(service.attachments, id: \.self) { file in
                HStack(spacing: 4) {
                    Image(systemName: "doc").font(.system(size: 9))
                    Text(file.lastPathComponent).font(.system(size: 10)).lineLimit(1)
                    Button {
                        service.attachments.removeAll { $0 == file }
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(Color.white.opacity(0.75))
                .padding(.horizontal, 6)
                .frame(height: 18)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            Spacer(minLength: 0)
        }
    }

    private func button(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.6))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        NSApp.activate()
        if panel.runModal() == .OK { service.attachments += panel.urls }
    }
}

/// Three dots lighting up in turn: Claude is working (spec CC-4).
struct WorkingDots: View {
    var color: Color = .white

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { context in
            let step = context.date.timeIntervalSinceReferenceDate * 2.2
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                        .opacity(0.3 + 0.7 * max(0, sin(step - Double(index) * 0.9)))
                }
            }
        }
    }
}

/// The sidebar button's mark: a rounded frame with a short bar at its left edge.
struct SidebarGlyph: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .stroke(lineWidth: 1.5)
            Capsule()
                .frame(width: 2, height: 6)
                .padding(.leading, 3.5)
        }
        .frame(width: 16, height: 12)
    }
}

/// The service's own app icon (from the installed Claude or ChatGPT app), Claude's mark or a
/// symbol when the app is not installed (spec AI-13).
struct AIGlyph: View {
    let provider: AIProvider
    var size: CGFloat = 14

    var body: some View {
        if let icon = provider.appIcon {
            Image(nsImage: icon).resizable().scaledToFit().frame(width: size + 2, height: size + 2)
        } else if provider == .claude {
            BrandGlyphView(glyph: .claude, size: size)
        } else {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: size * 0.85, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

extension AIProvider {
    /// The app's identifiers, newest first: the ChatGPT app now runs as `com.openai.codex`.
    var bundleIdentifiers: [String] {
        switch self {
        case .claude: ["com.anthropic.claudefordesktop"]
        case .chatgpt: ["com.openai.codex", "com.openai.chat"]
        }
    }

    private var appPath: String {
        switch self {
        case .claude: "/Applications/Claude.app"
        case .chatgpt: "/Applications/ChatGPT.app"
        }
    }

    /// The installed app's icon, if the app is there.
    var appIcon: NSImage? {
        let url = bundleIdentifiers.lazy.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.first
            ?? (FileManager.default.fileExists(atPath: appPath) ? URL(fileURLWithPath: appPath) : nil)
        return url.map { NSWorkspace.shared.icon(forFile: $0.path) }
    }
}
