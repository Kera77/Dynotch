import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The file tray module (spec FT-1…FT-5): the tray and the attached folders as chips, their
/// files below. Files can be dragged out into any app and dropped in.
struct TrayFeatureView: View {
    @ObservedObject var store: TrayStore
    /// Opens a screenshot in the editor (spec SH-11).
    var edit: (URL) -> Void = { _ in }

    /// The file Space shows in Quick Look (spec FT-8).
    @State private var chosen: URL?
    @FocusState private var isFocused: Bool

    /// The folder dots; new colours go at the end so stored indices keep their colour (spec FT-4b).
    static let dotColours: [(name: String, colour: NSColor)] = [
        ("Red", .systemRed), ("Green", .systemGreen), ("Blue", .systemBlue), ("Orange", .systemOrange),
        ("Purple", .systemPurple), ("Pink", .systemPink), ("Yellow", .systemYellow), ("Teal", .systemTeal),
        ("Grey", .systemGray)
    ]

    static func dotColour(_ index: Int) -> Color {
        Color(nsColor: dotColours[index % dotColours.count].colour)
    }

    /// A coloured dot for the menu, not tinted like a template image.
    static func dotImage(_ colour: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            colour.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    /// The grid's width, so a tile's full name stays inside it (spec FT-11d).
    @State private var gridWidth: CGFloat = 0

    private var selected: TrayFolder? {
        store.folders.first { $0.id == store.selectedFolder }
    }

    private var isScreenshots: Bool { store.selectedFolder == TrayStore.screenshotsID }

    private var files: [URL] {
        // The ten newest shots and recordings (spec SH-11).
        if isScreenshots { return ScreenshotFiles.recent(10) }
        return selected.map(store.contents(of:)) ?? store.trayFiles.map(\.url)
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
            chip(title: "Tray", colour: Theme.blue, isOn: store.selectedFolder == nil) { store.selectedFolder = nil }
            if store.showsScreenshots {
                chip(title: "Screenshots", colour: .orange, isOn: isScreenshots) { store.selectedFolder = TrayStore.screenshotsID }
            }
            ForEach(store.folders) { folder in
                chip(title: folder.name, colour: Self.dotColour(folder.colour), isOn: store.selectedFolder == folder.id) {
                    store.selectedFolder = folder.id
                }
                .contextMenu {
                    colourMenu(for: folder)
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

    private func colourMenu(for folder: TrayFolder) -> some View {
        Menu("Colour") {
            ForEach(Self.dotColours.indices, id: \.self) { index in
                Button {
                    store.setColour(index, of: folder)
                } label: {
                    let isOn = folder.colour % Self.dotColours.count == index
                    Label {
                        Text(isOn ? "\(Self.dotColours[index].name) ✓" : Self.dotColours[index].name)
                    } icon: {
                        Image(nsImage: Self.dotImage(Self.dotColours[index].colour))
                    }
                }
            }
        }
    }

    private func cell(_ url: URL) -> some View {
        let trayItem = selected == nil ? store.trayFiles.first(where: { $0.url == url })?.item : nil
        // Out of the tray a file moves; out of an attached folder it is copied (spec FT-12b).
        return TrayFileCell(
            url: url, isChosen: chosen == url, isRow: store.showsList, gridWidth: gridWidth, move: trayItem != nil,
            moved: { if let trayItem { store.remove(trayItem) } },
            // A double click opens a shot in the editor (spec SH-11).
            open: isScreenshots && ScreenshotFiles.isEditable(url) ? { edit(url) } : nil,
            choose: {
                chosen = url
                isFocused = true
            }
        )
        .contextMenu {
            if isScreenshots, ScreenshotFiles.isEditable(url) {
                Button("Edit") { edit(url) }
            }
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 98), spacing: 8)], spacing: 10) {
                        ForEach(files, id: \.self) { cell($0) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .coordinateSpace(.named(TrayFileCell.gridSpace))
            .readWidth($gridWidth)
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
                    symbol: isScreenshots ? "camera.viewfinder" : selected == nil ? "tray" : "folder",
                    text: isScreenshots ? "Press ⌃⇧S to take a screenshot."
                        : selected == nil ? "Drop files on the notch to keep them here." : "This folder is empty."
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
    /// The grid's width; 0 when unknown.
    var gridWidth: CGFloat = 0
    /// Dragged out, the file moves (a tray file) or is copied (an attached folder's).
    var move = false
    var moved: @MainActor () -> Void = {}
    /// What a double click does instead of opening the file.
    var open: (() -> Void)?
    var choose: () -> Void = {}
    @State private var isHovering = false
    /// The tile's place in the grid, so its full name can be moved inside the grid (spec FT-11d).
    @State private var frameInGrid: CGRect = .zero

    static let gridSpace = "trayGrid"
    private static let nameWidth: CGFloat = 150
    private static let pop = Animation.spring(response: 0.28, dampingFraction: 0.78)

    var body: some View {
        content
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isChosen ? 0.16 : isHovering && !isRow ? 0.07 : 0))
            )
            // A tile shows its whole name while the mouse is over it (spec FT-11c, FT-11d).
            .overlay(alignment: .top) {
                if isHovering && !isRow {
                    fullName
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.85, anchor: .top).combined(with: .opacity).combined(with: .offset(y: -6)),
                                removal: .opacity
                            )
                        )
                }
            }
            .contentShape(Rectangle())
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.gridSpace)) } action: { frameInGrid = $0 }
            // Dragged out under its own name, "(1)" when taken (spec FT-12, FT-12b).
            .overlay {
                TrayDragSource(url: url, move: move, moved: moved) { clicks in
                    if clicks >= 2 {
                        if let open { open() } else { NSWorkspace.shared.open(url) }
                    } else {
                        choose()
                    }
                }
            }
            .help(url.path)
            .onHover { hovering in withAnimation(Self.pop) { isHovering = hovering } }
            .zIndex(isHovering ? 1 : 0)
    }

    /// How far the name moves sideways so it stays inside the grid at the left and right edges.
    private var nameShift: CGFloat {
        guard gridWidth > Self.nameWidth else { return 0 }
        let left = frameInGrid.midX - Self.nameWidth / 2
        return min(max(left, 0), gridWidth - Self.nameWidth) - left
    }

    private var fullName: some View {
        Text(url.lastPathComponent)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(5)
            .frame(width: Self.nameWidth - 16)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(white: 0.13).opacity(0.97))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.06)], startPoint: .top, endPoint: .bottom),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
            }
            .offset(x: nameShift, y: 54)
            .allowsHitTesting(false)
    }

    @ViewBuilder private var content: some View {
        let icon = Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit()
        if isRow {
            HStack(spacing: 8) {
                icon.frame(width: 20, height: 20)
                Text(url.lastPathComponent).font(.system(size: 12)).foregroundStyle(.white).lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
        } else {
            VStack(spacing: 4) {
                // The icon lifts a little under the mouse.
                icon.frame(width: 44, height: 44)
                    .scaleEffect(isHovering ? 1.1 : 1)
                    .offset(y: isHovering ? -2 : 0)
                    .shadow(color: .black.opacity(isHovering ? 0.35 : 0), radius: 6, y: 3)
                // The middle is cut, so the end of the name (a shot's time, the extension) stays (spec FT-11c).
                Text(url.lastPathComponent)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
                    .frame(width: 90)
            }
        }
    }
}

/// Dragging files over the notch (spec FT-1, FT-3): the tray on the left two thirds, AirDrop on
/// the right third, each a rounded section with its icon in the middle.
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
                    section(title: "Keep in Tray", isOver: overKeep) {
                        Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 34, weight: .semibold))
                    }
                    .frame(width: third * 2)
                    .dropDestination(for: URL.self) { urls, _ in
                        keep(urls)
                        return true
                    } isTargeted: { overKeep = $0 }
                    section(title: "AirDrop", isOver: overAirDrop) {
                        Image(nsImage: Self.airDropIcon).resizable().scaledToFit().frame(width: 44, height: 44)
                    }
                    .frame(width: third)
                    .dropDestination(for: URL.self) { urls, _ in
                        airDrop(urls)
                        return true
                    } isTargeted: { overAirDrop = $0 }
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
