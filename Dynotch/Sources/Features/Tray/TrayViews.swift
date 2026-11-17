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
            Spacer(minLength: 0)
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], spacing: 10) {
                ForEach(files, id: \.self) { url in
                    TrayFileCell(url: url, isChosen: chosen == url) {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                Text(selected == nil ? "Drop files on the notch to keep them here." : "This folder is empty.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.5))
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
    var choose: () -> Void = {}

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
            Text(url.lastPathComponent)
                .font(.system(size: 10))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 74)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(isChosen ? 0.16 : 0)))
        .contentShape(Rectangle())
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
        .onTapGesture(count: 1, perform: choose)
        .help(url.path)
    }
}

/// Dragging files over the notch (spec FT-1, FT-3): keep them in the tray on the left, send
/// them with AirDrop on the right (the system's AirDrop window opens).
struct TrayDropZoneView: View {
    let notchHeight: CGFloat
    let keep: ([URL]) -> Void
    let airDrop: ([URL]) -> Void

    @State private var overKeep = false
    @State private var overAirDrop = false

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: 12) {
                target(symbol: "tray.and.arrow.down.fill", title: "Keep in Tray", isOver: overKeep)
                    .dropDestination(for: URL.self) { urls, _ in
                        keep(urls)
                        return true
                    } isTargeted: { overKeep = $0 }
                target(symbol: "airplayaudio", title: "AirDrop", isOver: overAirDrop)
                    .dropDestination(for: URL.self) { urls, _ in
                        airDrop(urls)
                        return true
                    } isTargeted: { overAirDrop = $0 }
            }
            .padding(14)
        }
    }

    private func target(symbol: String, title: String, isOver: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(isOver ? 1 : 0.75))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(isOver ? 0.2 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(isOver ? 0.7 : 0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .scaleEffect(isOver ? 1.03 : 1)
        .animation(.easeOut(duration: 0.12), value: isOver)
    }
}
