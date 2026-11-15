import SwiftUI

/// State of the menu bar panel.
@MainActor
final class MenuBarPanelState: ObservableObject {
    /// Lock: the panel stays open when clicking elsewhere (spec SZ-8).
    @Published var isPinned = false
    /// True for a moment after "copy all".
    @Published var didCopy = false
    /// Horizontal position of the arrow tip inside the panel.
    @Published var arrowX: CGFloat = 0
}

/// Popover outline: rounded rectangle with an arrow on its top edge.
struct PopoverShape: Shape {
    static let arrowHeight: CGFloat = 9
    static let arrowWidth: CGFloat = 20

    var arrowX: CGFloat
    var cornerRadius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let top = rect.minY + Self.arrowHeight
        let half = Self.arrowWidth / 2
        let tipX = min(max(arrowX, rect.minX + cornerRadius + half), rect.maxX - cornerRadius - half)
        let topRight = CGPoint(x: rect.maxX, y: top)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let topLeft = CGPoint(x: rect.minX, y: top)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: top))
        path.addLine(to: CGPoint(x: tipX - half, y: top))
        path.addLine(to: CGPoint(x: tipX, y: rect.minY))
        path.addLine(to: CGPoint(x: tipX + half, y: top))
        path.addArc(tangent1End: topRight, tangent2End: bottomRight, radius: cornerRadius)
        path.addArc(tangent1End: bottomRight, tangent2End: bottomLeft, radius: cornerRadius)
        path.addArc(tangent1End: bottomLeft, tangent2End: topLeft, radius: cornerRadius)
        path.addArc(tangent1End: topLeft, tangent2End: topRight, radius: cornerRadius)
        path.closeSubpath()
        return path
    }
}

/// Content of the menu bar panel: the notepad with a status bar below it (spec SZ-6).
struct CalculatorMenuBarView: View {
    @ObservedObject var store: CalculatorStore
    @ObservedObject var state: MenuBarPanelState

    private static let surface = Color(red: 0.145, green: 0.145, blue: 0.15)
    private static let accent = Color(nsColor: CalculatorResultsView.resultColor)

    private var resultCount: Int {
        CalculatorEngine.results(in: store.text).count
    }

    private var statusText: String {
        if state.didCopy { return "Vágólapra másolva" }
        if store.text.isEmpty { return "Készen áll…" }
        return resultCount == 0 ? "Nincs számítás" : "Kattintásra másol"
    }

    var body: some View {
        VStack(spacing: 0) {
            CalculatorEditor(text: $store.text)
                .padding(.horizontal, 14)
                .padding(.top, 10)
            statusBar
        }
        .padding(.top, PopoverShape.arrowHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PopoverShape(arrowX: state.arrowX).fill(Self.surface))
        .overlay(PopoverShape(arrowX: state.arrowX).stroke(Color.white.opacity(0.14), lineWidth: 1))
        .padding(1)
        .environment(\.colorScheme, .dark)
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text("\(resultCount) számítás")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.6))
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 16)
            PinButton(isPinned: state.isPinned) { state.isPinned.toggle() }
                .frame(width: 30, height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.14)))
            Button(action: copyAll) {
                Text("Mind másolása")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Self.accent))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(resultCount == 0 ? 0.4 : 1)
            .disabled(resultCount == 0)
            .help("Minden számítás és eredménye a vágólapra kerül")
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    /// Copies every calculation with its result, one per line ("10*10 = 100").
    private func copyAll() {
        let summary = CalculatorEngine.summary(of: store.text)
        guard !summary.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
        state.didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [state] in
            state.didCopy = false
        }
    }
}
