import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The file tray module (spec FT-1…FT-5): the tray and the attached folders as chips, their
/// files below. Files can be dragged out into any app and dropped in.
struct TrayFeatureView: View {
    @ObservedObject var store: TrayStore

    /// The file Space shows in Quick Look (spec FT-8).
    @State private var chosen: URL?
    @FocusState private var isFocused: Bool

    static let dotColours: [Color] = [.red, .green, .blue, .orange, .purple, .pink]

    private var selected: TrayFolder? {
        store.folders.first { $0.id == store.selectedFolder }
    }

    private var files: [URL] {
        selected.map(store.contents(of:)) ?? store.trayFiles.map(\.url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            chips
            grid
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private var chips: some View {
        HStack(spacing: 8) {
            chip(title: "Tray", colour: .white, isOn: store.selectedFolder == nil) { store.selectedFolder = nil }
            ForEach(store.folders) { folder in
                let colour = Self.dotColours[folder.colour % Self.dotColours.count]
                chip(title: folder.name, colour: colour, isOn: store.selectedFolder == folder.id) {
                    store.selectedFolder = folder.id
                }
                .contextMenu {
                    Button("Show in Finder") { store.url(of: folder).map { NSWorkspace.shared.activateFileViewerSelecting([$0]) } }
                    Button("Detach") { store.detach(folder) }
                }
                .dropDestination(for: URL.self) { urls, _ in
                    store.put(urls, into: folder, move: NSEvent.modifierFlags.contains(.option))
                    return true
                }
            }
            Button {
                store.attachFolder()
            } label: {
                HStack(spacing: 4) {
                    Circle().fill(Color.white.opacity(0.35)).frame(width: 7, height: 7)
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .help("Attach a folder")
            .accessibilityLabel("Attach a folder")
            Spacer(minLength: 0)
            // Tiles or a list (spec FT-11).
            CapsulePicker(items: [false, true], selection: $store.showsList) { $0 ? "List" : "Tiles" }
        }
    }

    private func cell(_ url: URL) -> some View {
        TrayFileCell(url: url, isChosen: chosen == url, isRow: store.showsList) {
            chosen = url
            isFocused = true
        }
        .contextMenu {
            Button("Quick Look") { TrayQuickLook.shared.toggle(url) }
            Button("Open") { NSWorkspace.shared.open(url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            if selected == nil, let item = store.trayFiles.first(where: { $0.url == url })?.item {
                Button("Remove from Tray") { store.remove(item) }
            }
        }
    }

    private func chip(title: String, colour: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(colour).frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? Color.black : Color.white)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Capsule().fill(isOn ? Color.white : Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        ScrollView(.vertical) {
            Group {
                if store.showsList {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(files, id: \.self) { cell($0) }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], spacing: 10) {
                        ForEach(files, id: \.self) { cell($0) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Switching between the tray and the folders slides, like the notification tabs (spec FT-10).
            .id(store.selectedFolder)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
        .animation(Motion.quick, value: store.selectedFolder)
        .scrollIndicators(.never)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(.space) {
            guard let chosen else { return .ignored }
            TrayQuickLook.shared.toggle(chosen)
            return .handled
        }
        .onDisappear { TrayQuickLook.shared.close() }
        .overlay {
            if files.isEmpty {
                EmptyStateView(
                    symbol: selected == nil ? "tray" : "folder",
                    text: selected == nil ? "Drop files on the notch to keep them here." : "This folder is empty."
                )
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            if let selected {
                store.put(urls, into: selected, move: NSEvent.modifierFlags.contains(.option))
            } else {
                store.add(urls)
            }
            return true
        }
    }
}

/// A file: its icon and name; drag it out, double-click opens it.
struct TrayFileCell: View {
    let url: URL
    var isChosen = false
    /// One line with a small icon (list), or a tile.
    var isRow = false
    var choose: () -> Void = {}

    var body: some View {
        content
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(isChosen ? 0.16 : 0)))
            .contentShape(Rectangle())
            // Dragged out under the name it came with (spec FT-12).
            .onDrag {
                let provider = NSItemProvider(contentsOf: url) ?? NSItemProvider()
                provider.suggestedName = url.lastPathComponent
                return provider
            }
            .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
            .onTapGesture(count: 1, perform: choose)
            .help(url.path)
    }

    @ViewBuilder private var content: some View {
        let icon = Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit()
        if isRow {
            HStack(spacing: 8) {
                icon.frame(width: 20, height: 20)
                Text(url.lastPathComponent).font(.system(size: 12)).foregroundStyle(.white).lineLimit(1)
                Spacer(minLength: 0)
            }
        } else {
            VStack(spacing: 4) {
                icon.frame(width: 44, height: 44)
                Text(url.lastPathComponent)
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 74)
            }
        }
    }
}

/// Dragging files over the notch (spec FT-1, FT-3): AirDrop on the left third, the tray on the
/// other two thirds, each a rounded section with its icon in the middle.
struct TrayDropZoneView: View {
    let notchHeight: CGFloat
    let keep: ([URL]) -> Void
    let airDrop: ([URL]) -> Void

    @State private var overKeep = false
    @State private var overAirDrop = false

    private static let airDropIcon = NSWorkspace.shared.icon(
        forFile: "/System/Library/CoreServices/Finder.app/Contents/Applications/AirDrop.app"
    )

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            GeometryReader { geometry in
                let spacing: CGFloat = 12
                let third = (geometry.size.width - spacing) / 3
                HStack(spacing: spacing) {
                    section(title: "AirDrop", isOver: overAirDrop) {
                        Image(nsImage: Self.airDropIcon).resizable().scaledToFit().frame(width: 44, height: 44)
                    }
                    .frame(width: third)
                    .dropDestination(for: URL.self) { urls, _ in
                        airDrop(urls)
                        return true
                    } isTargeted: { overAirDrop = $0 }
                    section(title: "Keep in Tray", isOver: overKeep) {
                        Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 34, weight: .semibold))
                    }
                    .frame(width: third * 2)
                    .dropDestination(for: URL.self) { urls, _ in
                        keep(urls)
                        return true
                    } isTargeted: { overKeep = $0 }
                }
            }
            .padding(14)
        }
    }

    private func section<Icon: View>(title: String, isOver: Bool, @ViewBuilder icon: () -> Icon) -> some View {
        VStack(spacing: 8) {
            icon()
            Text(title).font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(isOver ? 1 : 0.8))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(isOver ? 0.2 : 0.08)))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(isOver ? 0.7 : 0.22), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .scaleEffect(isOver ? 1.02 : 1)
        .animation(Motion.hover, value: isOver)
    }
}
