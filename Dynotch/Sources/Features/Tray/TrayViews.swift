import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The file tray module (spec FT-1…FT-5): the tray and the attached folders as chips, their
/// files below. Files can be dragged out into any app and dropped in.
struct TrayFeatureView: View {
    @Bindable var store: TrayStore
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

    /// Read in the background by the store, not on every redraw (spec FT-16).
    private var files: [URL] { store.shownFiles }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Only a swipe over the tabs steps between them; elsewhere it switches modules (spec FT-4d).
            chips
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onHover { store.isOverTabs = $0 }
            grid
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        // Files deleted or added outside Dynotch since the last look (spec FT-16).
        .onAppear { store.refreshShownFiles() }
    }

    private var chips: some View {
        HStack(spacing: 8) {
            chip(title: "Tray", colour: Self.dotColour(store.colour(ofFixed: "tray")), isOn: store.selectedFolder == nil) {
                store.selectedFolder = nil
            }
            .contextMenu { colourMenu(current: store.colour(ofFixed: "tray")) { store.setColour($0, ofFixed: "tray") } }
            if store.showsScreenshots {
                chip(title: "Screenshots", colour: Self.dotColour(store.colour(ofFixed: "screenshots")), isOn: isScreenshots) {
                    store.selectedFolder = TrayStore.screenshotsID
                }
                .contextMenu {
                    colourMenu(current: store.colour(ofFixed: "screenshots")) { store.setColour($0, ofFixed: "screenshots") }
                }
            }
            ForEach(store.folders) { folder in
                chip(title: folder.name, colour: Self.dotColour(folder.colour), isOn: store.selectedFolder == folder.id) {
                    store.selectedFolder = folder.id
                }
                .contextMenu {
                    colourMenu(current: folder.colour) { store.setColour($0, of: folder) }
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
                    Circle().fill(Color.white.level(0.35)).frame(width: 7, height: 7)
                    Image(systemName: "plus").font(.notch(size: 10, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Capsule().fill(Color.white.level(0.1)))
            }
            .buttonStyle(.notch)
            .help("Attach a folder")
            .accessibilityLabel("Attach a folder")
            Spacer(minLength: 0)
            // Tiles or a list (spec FT-11).
            CapsulePicker(items: [false, true], selection: $store.showsList) { $0 ? "List" : "Tiles" }
        }
    }

    /// The dot colour of a tab, from its right-click menu (spec FT-4b, FT-4c).
    private func colourMenu(current: Int, set: @escaping (Int) -> Void) -> some View {
        Menu("Colour") {
            ForEach(Self.dotColours.indices, id: \.self) { index in
                Button {
                    set(index)
                } label: {
                    let isOn = current % Self.dotColours.count == index
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
        let trayItem = selected == nil ? store.trayItemByURL[url] : nil
        // Out of the tray a file moves; out of an attached folder it is copied (spec FT-12b).
        return TrayFileCell(
            url: url, isChosen: chosen == url, isRow: store.showsList, gridWidth: gridWidth, move: trayItem != nil,
            moved: { if let trayItem { store.remove(trayItem) } },
            // A double click opens a shot in the editor (spec SH-11).
            open: isScreenshots && ScreenshotFiles.isEditable(url) ? { edit(url) } : nil,
            choose: {
                chosen = url
                isFocused = true
            },
            // The file under the mouse is the one Space shows, no click needed (spec FT-8c).
            hovered: {
                chosen = url
                isFocused = true
                TrayQuickLook.shared.follow(url)
            }
        )
        .contextMenu {
            if isScreenshots, ScreenshotFiles.isEditable(url) {
                Button("Edit") { edit(url) }
            }
            Button("Quick Look") { TrayQuickLook.shared.toggle(url) }
            Button("Open") { NSWorkspace.shared.open(url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            if let trayItem {
                Button("Remove from Tray") { store.remove(trayItem) }
            }
        }
    }

    private func chip(title: String, colour: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(colour).frame(width: 7, height: 7)
                Text(title)
                    .font(.notch(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? Color.black : Color.white)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Capsule().fill(isOn ? Color.white : Color.white.level(0.1)))
        }
        .buttonStyle(.notch)
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
    var hovered: () -> Void = {}
    @State private var isHovering = false
    /// The tile's place in the grid, so its full name can be moved inside the grid (spec FT-11d).
    @State private var frameInGrid: CGRect = .zero

    static let gridSpace = "trayGrid"
    private static let nameWidth: CGFloat = 150
    private static var pop: Animation { Motion.quick }

    var body: some View {
        content
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous)
                    .fill(Color.white.level(isChosen ? 0.16 : isHovering && !isRow ? 0.07 : 0))
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
            .onHover { hovering in
                withAnimation(Self.pop) { isHovering = hovering }
                if hovering { hovered() }
            }
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
            .font(.notch(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(5)
            .frame(width: Self.nameWidth - 16)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: AppleStyle.corner(9), style: .continuous)
                    .fill(Color(white: 0.13).opacity(0.97))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppleStyle.corner(9), style: .continuous)
                            .strokeBorder(
                                LinearGradient(colors: [.white.level(0.28), .white.level(0.06)], startPoint: .top, endPoint: .bottom),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
            }
            .offset(x: nameShift, y: 54)
            .allowsHitTesting(false)
    }

    @ViewBuilder private var content: some View {
        let icon = Image(nsImage: TrayIcons.icon(for: url)).resizable().scaledToFit()
        if isRow {
            HStack(spacing: 8) {
                icon.frame(width: 20, height: 20)
                Text(url.lastPathComponent).font(.notch(size: 12)).foregroundStyle(.white).lineLimit(1)
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
                    .font(.notch(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
                    .frame(width: 90)
            }
        }
    }
}

/// File icons asked from the Finder once per file, not on every redraw (spec FT-16).
@MainActor
enum TrayIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(for url: URL) -> NSImage {
        if let known = cache[url.path] { return known }
        if cache.count > 500 { cache.removeAll() }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[url.path] = icon
        return icon
    }
}
