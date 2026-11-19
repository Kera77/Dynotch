import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

/// A shot or recording that was just made: shown under the notch for a moment (spec SH-6).
struct ScreenshotShot: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let thumbnail: NSImage?
    let isVideo: Bool
}

/// The screenshot tool (spec SH-1…SH-12): the shortcut steps through the modes while its
/// modifiers are held, letting go takes the picture; it is saved, copied and announced.
@MainActor
final class ScreenshotService: ObservableObject {
    /// The mode chosen while the modifiers are held (spec SH-1).
    @Published private(set) var choosing: CaptureMode?
    @Published private(set) var peek: ScreenshotShot?
    @Published private(set) var recordingSince: Date?
    private var areaFrame: NSWindow?
    /// Tells the notch to open the editor for a file (spec SH-7, SH-11).
    var openEditor: (URL) -> Void = { _ in }

    let settings: ScreenshotSettings
    private let recorder = ScreenRecorder()
    private var scrolling: ScrollCapture?
    private var isBusy = false
    private var handler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []
    private var escapeKeys: [EventHotKeyRef] = []
    private var releaseTimer: Timer?
    private var peekTask: Task<Void, Never>?
    private var observer: AnyCancellable?
    private var registered: KeyShortcut??

    private static let signature: OSType = 0x4459_5353 // "DYSS"
    private static let peekDuration: Duration = .seconds(5)

    init(settings: ScreenshotSettings) {
        self.settings = settings
    }

    func start() {
        installHandler()
        observer = settings.afterChange { [weak self] in self?.registerShortcut() }
        registerShortcut()
    }

    // MARK: - Choosing (spec SH-1)

    /// The next mode after `current` in `modes`, round and round.
    nonisolated static func next(after current: CaptureMode?, in modes: [CaptureMode]) -> CaptureMode? {
        guard !modes.isEmpty else { return nil }
        guard let current, let index = modes.firstIndex(of: current) else { return modes[0] }
        return modes[(index + 1) % modes.count]
    }

    private func pressed() {
        if recorder.isRecording {
            stopRecording()
            return
        }
        if let scrolling {
            scrolling.finish()
            return
        }
        guard !isBusy else { return }
        let first = choosing == nil
        choosing = Self.next(after: choosing, in: settings.modes)
        if first { watchRelease() }
    }

    private func watchRelease() {
        registerEscape()
        let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkRelease() }
        }
        RunLoop.main.add(timer, forMode: .common)
        releaseTimer = timer
    }

    private func checkRelease() {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let modifiers = settings.shortcut?.modifiers ?? 0
        var held = true
        if modifiers & UInt32(controlKey) != 0, !flags.contains(.maskControl) { held = false }
        if modifiers & UInt32(shiftKey) != 0, !flags.contains(.maskShift) { held = false }
        if modifiers & UInt32(optionKey) != 0, !flags.contains(.maskAlternate) { held = false }
        if modifiers & UInt32(cmdKey) != 0, !flags.contains(.maskCommand) { held = false }
        guard !held else { return }
        let mode = choosing
        endChoosing()
        if let mode { run(mode) }
    }

    private func endChoosing() {
        releaseTimer?.invalidate()
        releaseTimer = nil
        unregisterEscape()
        choosing = nil
    }

    // MARK: - Taking the picture (spec SH-2…SH-5)

    func run(_ mode: CaptureMode) {
        guard !isBusy else { return }
        guard ScreenCapture.isAllowed else {
            ScreenCapture.requestAccess()
            DiagnosticsLog.append("screenshots", "no Screen Recording permission")
            return
        }
        isBusy = true
        Task { [weak self] in
            await self?.perform(mode)
            self?.isBusy = false
        }
    }

    private func perform(_ mode: CaptureMode) async {
        let screen = ScreenCapture.screen(at: NSEvent.mouseLocation)
        switch mode {
        case .area, .scrolling, .areaRecording:
            await performArea(mode)
        case .window:
            guard case let .window(id, _) = await SelectionOverlay.run(.window) else { return }
            try? await Task.sleep(for: .milliseconds(120))
            finish(await ScreenCapture.captureWindow(id))
        case .screen:
            guard let screen else { return }
            finish(await ScreenCapture.captureScreen(screen))
        case .recording:
            guard let screen else { return }
            await startRecording(on: screen)
        }
    }

    /// The modes that start by picking an area (spec SH-2, SH-4, SH-13).
    private func performArea(_ mode: CaptureMode) async {
        guard case let .area(rect, picked) = await SelectionOverlay.run(.area) else { return }
        // Let the overlay leave the screen first.
        try? await Task.sleep(for: .milliseconds(120))
        switch mode {
        case .scrolling:
            let capture = ScrollCapture(rect: rect, screen: picked)
            scrolling = capture
            finish(await capture.run())
            scrolling = nil
        case .areaRecording:
            // Only the picked area goes on the video (spec SH-13).
            await startRecording(on: picked, area: rect)
        default:
            finish(await ScreenCapture.capture(rect, on: picked))
        }
    }

    private func finish(_ image: CGImage?) {
        guard let image else { return }
        let url = ScreenshotFiles.newURL(prefix: "Screenshot", ext: "png")
        let saved = ScreenshotFiles.save(image, to: url)
        ScreenshotFiles.copy(image, file: saved ? url : nil)
        DiagnosticsLog.append("screenshots", "shot \(image.width)×\(image.height) saved=\(saved)")
        guard saved else { return }
        show(ScreenshotShot(url: url, thumbnail: NSImage(cgImage: image, size: .zero), isVideo: false))
    }

    private func show(_ shot: ScreenshotShot) {
        peekTask?.cancel()
        peek = shot
        peekTask = Task { [weak self] in
            try? await Task.sleep(for: Self.peekDuration)
            guard !Task.isCancelled else { return }
            self?.peek = nil
        }
    }

    /// The peek was opened into the editor, or should go.
    func clearPeek() {
        peekTask?.cancel()
        peek = nil
    }

    // MARK: - Recording (spec SH-5)

    private func startRecording(on screen: NSScreen, area: CGRect? = nil) async {
        let started = await recorder.start(
            on: screen, area: area, systemAudio: settings.recordsSystemAudio, microphone: settings.recordsMicrophone
        )
        guard started else { return }
        recordingSince = Date()
        if let area { showAreaFrame(area) }
    }

    /// A thin frame just outside the recorded area; Dynotch is left out of the video (spec SH-13).
    private func showAreaFrame(_ area: CGRect) {
        let window = NSWindow(contentRect: area.insetBy(dx: -3, dy: -3), styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.sharingType = .none
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: RoundedRectangle(cornerRadius: AppleStyle.corner(3))
            .stroke(Color.red.opacity(0.85), lineWidth: 2))
        window.orderFrontRegardless()
        areaFrame = window
    }

    func stopRecording() {
        guard recorder.isRecording else { return }
        recordingSince = nil
        areaFrame?.orderOut(nil)
        areaFrame = nil
        Task { [weak self] in
            guard let self, let url = await self.recorder.stop() else { return }
            ScreenshotFiles.copyFile(url)
            DiagnosticsLog.append("screenshots", "recording saved")
            self.show(ScreenshotShot(url: url, thumbnail: NSWorkspace.shared.icon(forFile: url.path), isVideo: true))
        }
    }
}

// MARK: - Keys

extension ScreenshotService {
    private enum Action: UInt32 { case shortcut = 1, escape, escapePlain }

    private func registerShortcut() {
        let wanted = settings.isOn ? settings.shortcut : nil
        guard registered != .some(wanted) else { return }
        hotKeys.forEach { UnregisterEventHotKey($0) }
        hotKeys = []
        registered = .some(wanted)
        guard let wanted else { return }
        hotKeys += register(wanted.keyCode, wanted.modifiers, .shortcut)
    }

    private func registerEscape() {
        escapeKeys += register(UInt32(kVK_Escape), settings.shortcut?.modifiers ?? 0, .escape)
        escapeKeys += register(UInt32(kVK_Escape), 0, .escapePlain)
    }

    private func unregisterEscape() {
        escapeKeys.forEach { UnregisterEventHotKey($0) }
        escapeKeys = []
    }

    private func fired(_ raw: UInt32) {
        switch Action(rawValue: raw) {
        case .shortcut: pressed()
        case .escape, .escapePlain: endChoosing()
        case nil: break
        }
    }

    private func register(_ keyCode: UInt32, _ modifiers: UInt32, _ action: Action) -> [EventHotKeyRef] {
        var reference: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: action.rawValue)
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &reference)
        guard status == noErr, let reference else {
            DiagnosticsLog.append("shortcuts", "screenshot key \(action) not registered (\(status))")
            return []
        }
        return [reference]
    }

    private func installHandler() {
        guard handler == nil else { return }
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKey = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &hotKey
            )
            guard status == noErr, hotKey.signature == ScreenshotService.signature else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<ScreenshotService>.fromOpaque(userData).takeUnretainedValue()
            let raw = hotKey.id
            MainActor.assumeIsolated { service.fired(raw) }
            return noErr
        }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
}
