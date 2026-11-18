import SwiftUI

/// The editor in the large notch (spec SH-7…SH-10): the tools on top, the shot below.
struct ScreenshotEditorView: View {
    @ObservedObject var editor: ScreenshotEditor
    @ObservedObject var settings: ScreenshotSettings
    let notchHeight: CGFloat
    /// Closes the editor; true when it was saved.
    let close: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Color.clear.frame(height: max(notchHeight - 6, 0))
            EditorToolbar(editor: editor, tools: settings.tools, close: close)
            EditorCanvas(editor: editor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            if let message = editor.message {
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .padding(.bottom, 22)
                    .transition(.opacity)
            }
        }
        .animation(Motion.quick, value: editor.message)
    }
}

private struct EditorToolbar: View {
    @ObservedObject var editor: ScreenshotEditor
    let tools: [EditorTool]
    let close: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tools.filter(\.isAction)) { tool in
                button(tool.symbol, help: tool.title, isOn: false) {
                    if tool == .copy { editor.copy() } else if editor.save() { close() }
                }
            }
            if tools.contains(where: \.isAction) { divider }
            ForEach(tools.filter { !$0.isAction }) { tool in
                button(tool.symbol, help: tool.title, isOn: editor.tool == tool) {
                    editor.commitText()
                    editor.tool = tool
                }
            }
            divider
            colorMenu
            Picker("Width", selection: $editor.widthLevel) {
                ForEach(0..<3, id: \.self) { level in
                    Image(systemName: "circle.fill").font(.system(size: [5, 8, 11][level])).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help("Line width")
            Spacer(minLength: 8)
            button("arrow.uturn.backward", help: "Undo (⌘Z)", isOn: false, action: editor.undo)
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!editor.canUndo)
            button("arrow.uturn.forward", help: "Redo (⇧⌘Z)", isOn: false, action: editor.redo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!editor.canRedo)
            divider
            Button("Close", action: close)
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.7))
                .keyboardShortcut(.cancelAction)
                .help("Close without saving (Esc)")
            Button("Done") { if !editor.hasChanges || editor.save() { close() } }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.blue)
                .keyboardShortcut("s", modifiers: .command)
                .help("Save the changes into the file and close (⌘S)")
                .padding(.leading, 6)
        }
        .frame(height: 30)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 16).padding(.horizontal, 4)
    }

    private var colorMenu: some View {
        Menu {
            ForEach(EditorColor.allCases) { color in
                Button(color.rawValue.capitalized) { editor.color = color }
            }
        } label: {
            Circle()
                .fill(Color(nsColor: editor.color.nsColor))
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                .frame(width: 16, height: 16)
                .frame(width: 26, height: 26)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Colour")
    }

    private func button(_ symbol: String, help: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isOn ? Color.black : Color.white.opacity(0.85))
                .frame(width: 28, height: 26)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(isOn ? Color.white : Color.white.opacity(0.0001)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// The shot, fitted into the room, with the annotations on it; drags draw with the tool.
private struct EditorCanvas: View {
    @ObservedObject var editor: ScreenshotEditor
    @State private var dragStart: CGPoint?
    @FocusState private var typing: Bool

    var body: some View {
        GeometryReader { proxy in
            let visible = editor.visibleRect
            let scale = min(proxy.size.width / visible.width, proxy.size.height / visible.height, 2)
            let size = CGSize(width: visible.width * scale, height: visible.height * scale)
            let origin = CGPoint(x: (proxy.size.width - size.width) / 2, y: (proxy.size.height - size.height) / 2)
            ZStack(alignment: .topLeading) {
                canvas(visible: visible, scale: scale)
                    .frame(width: size.width, height: size.height)
                    .gesture(drawing(visible: visible, scale: scale))
                if let anchor = editor.textAnchor {
                    textField
                        .offset(x: (anchor.x - visible.minX) * scale, y: (anchor.y - visible.minY) * scale)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 10)
            .offset(x: origin.x, y: origin.y)
        }
    }

    private func canvas(visible: CGRect, scale: CGFloat) -> some View {
        Canvas { context, _ in
            context.withCGContext { cgContext in
                cgContext.scaleBy(x: scale, y: scale)
                cgContext.translateBy(x: -visible.minX, y: -visible.minY)
                var shown = editor.annotations
                if let draft = editor.draft { shown.append(draft) }
                AnnotationRenderer.draw(editor.image, annotations: shown, pixelated: editor.pixelated, in: cgContext)
                if let crop = editor.cropDraft {
                    cgContext.setStrokeColor(NSColor.white.cgColor)
                    cgContext.setLineWidth(2 / scale)
                    cgContext.setLineDash(phase: 0, lengths: [6 / scale, 4 / scale])
                    cgContext.stroke(crop)
                }
            }
        }
    }

    private var textField: some View {
        TextField("Text", text: $editor.typedText)
            .textFieldStyle(.plain)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color(nsColor: editor.color.nsColor))
            .padding(.horizontal, 4)
            .frame(minWidth: 140)
            .fixedSize()
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.45)))
            .focused($typing)
            .onAppear { typing = true }
            .onSubmit { editor.commitText() }
    }

    private func drawing(visible: CGRect, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = Self.point(value.startLocation, visible: visible, scale: scale)
                if dragStart == nil {
                    dragStart = start
                    if editor.textAnchor != nil { editor.commitText() }
                }
                editor.drag(from: start, to: Self.point(value.location, visible: visible, scale: scale))
            }
            .onEnded { value in
                let start = dragStart ?? Self.point(value.startLocation, visible: visible, scale: scale)
                editor.endDrag(at: Self.point(value.location, visible: visible, scale: scale), start: start)
                dragStart = nil
            }
    }

    /// A point on the view in the image's pixels.
    nonisolated static func point(_ location: CGPoint, visible: CGRect, scale: CGFloat) -> CGPoint {
        CGPoint(x: visible.minX + location.x / max(scale, 0.0001), y: visible.minY + location.y / max(scale, 0.0001))
    }
}
