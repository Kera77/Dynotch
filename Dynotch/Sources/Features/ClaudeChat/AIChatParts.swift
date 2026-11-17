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
            HStack(spacing: 2) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { service.choose(provider: provider) }
                    } label: {
                        Text(provider.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(provider == service.shownProvider ? Color.black : Color.white.opacity(0.75))
                            .padding(.horizontal, 9)
                            .frame(height: 22)
                            .background(Capsule().fill(provider == service.shownProvider ? Color.white : .clear))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Capsule().fill(Color.white.opacity(0.1)))
            modelMenu
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
    static func formatted(_ paragraph: String) -> AttributedString {
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

/// Copy and Insert under an answer (spec AI-7).
struct AIAnswerActions: View {
    let text: String
    @Environment(\.closeNotch) private var closeNotch

    var body: some View {
        HStack(spacing: 10) {
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
