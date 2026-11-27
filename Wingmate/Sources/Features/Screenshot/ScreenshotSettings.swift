import Carbon.HIToolbox
import Foundation
import Observation

/// The kinds of capture the shortcut steps through (spec SH-2).
enum CaptureMode: String, CaseIterable, Identifiable, Sendable {
    case area
    case window
    case screen
    case scrolling
    case recording
    case areaRecording

    var id: String { rawValue }

    var title: String {
        switch self {
        case .area: "Area"
        case .window: "Window"
        case .screen: "Full Screen"
        case .scrolling: "Scrolling"
        case .recording: "Screen Recording"
        case .areaRecording: "Area Recording"
        }
    }

    var symbol: String {
        switch self {
        case .area: "rectangle.dashed"
        case .window: "macwindow"
        case .screen: "display"
        case .scrolling: "arrow.up.and.down.text.horizontal"
        case .recording: "record.circle"
        case .areaRecording: "rectangle.dashed.badge.record"
        }
    }
}

/// The editor's buttons and tools, each can be turned off (spec SH-7, SH-8).
enum EditorTool: String, CaseIterable, Identifiable, Sendable {
    case copy, save, crop, text, arrow, rectangle, ellipse, line, pencil, highlighter, pixelate, counter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copy: "Copy"
        case .save: "Save"
        case .crop: "Crop"
        case .text: "Text"
        case .arrow: "Arrow"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .line: "Line"
        case .pencil: "Pencil"
        case .highlighter: "Highlighter"
        case .pixelate: "Pixelate"
        case .counter: "Numbered Step"
        }
    }

    var symbol: String {
        switch self {
        case .copy: "doc.on.doc"
        case .save: "square.and.arrow.down"
        case .crop: "crop"
        case .text: "textformat"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .line: "line.diagonal"
        case .pencil: "pencil"
        case .highlighter: "highlighter"
        case .pixelate: "checkerboard.rectangle"
        case .counter: "1.circle"
        }
    }

    /// Copy and Save act at once; the others draw on the image.
    var isAction: Bool { self == .copy || self == .save }
}

/// Settings › Screenshots (spec SH-1…SH-12), kept in the defaults.
@MainActor
@Observable
final class ScreenshotSettings {
    var isOn: Bool { didSet { defaults.set(isOn, forKey: Key.isOn) } }
    /// The order the shortcut steps through, disabled ones included (spec SH-2).
    private(set) var order: [CaptureMode] { didSet { defaults.set(order.map(\.rawValue), forKey: Key.order) } }
    private(set) var modesOff: Set<CaptureMode> {
        didSet { defaults.set(modesOff.map(\.rawValue).sorted(), forKey: Key.modesOff) }
    }
    private(set) var toolsOff: Set<EditorTool> {
        didSet { defaults.set(toolsOff.map(\.rawValue).sorted(), forKey: Key.toolsOff) }
    }
    var shortcut: KeyShortcut? {
        didSet { defaults.set(shortcut.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.shortcut) }
    }
    var recordsSystemAudio: Bool { didSet { defaults.set(recordsSystemAudio, forKey: Key.audio) } }
    var recordsMicrophone: Bool { didSet { defaults.set(recordsMicrophone, forKey: Key.microphone) } }
    /// How long the modifiers stay down before the modes show (spec SH-14).
    var chooserDelay: Double { didSet { defaults.set(chooserDelay, forKey: Key.chooserDelay) } }
    static let chooserDelayRange: ClosedRange<Double> = 0...1

    /// ⌃⇧S (spec SH-1).
    static let defaultShortcut = KeyShortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(controlKey | shiftKey), display: "⌃⇧S")

    private enum Key {
        static let isOn = "screenshotsOn", order = "screenshotModes", modesOff = "screenshotModesOff"
        static let toolsOff = "screenshotToolsOff", shortcut = "screenshotShortcut"
        static let audio = "screenshotSystemAudio", microphone = "screenshotMicrophone"
        static let chooserDelay = "screenshotChooserDelay"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isOn = defaults.object(forKey: Key.isOn) as? Bool ?? true
        order = Self.normalized((defaults.stringArray(forKey: Key.order) ?? []).compactMap(CaptureMode.init(rawValue:)))
        modesOff = Set((defaults.stringArray(forKey: Key.modesOff) ?? []).compactMap(CaptureMode.init(rawValue:)))
        toolsOff = Set((defaults.stringArray(forKey: Key.toolsOff) ?? []).compactMap(EditorTool.init(rawValue:)))
        if let data = defaults.data(forKey: Key.shortcut) {
            shortcut = try? JSONDecoder().decode(KeyShortcut.self, from: data)
        } else {
            shortcut = Self.defaultShortcut
        }
        recordsSystemAudio = defaults.object(forKey: Key.audio) as? Bool ?? true
        recordsMicrophone = defaults.bool(forKey: Key.microphone)
        chooserDelay = min(max(defaults.object(forKey: Key.chooserDelay) as? Double ?? 0.15, 0), 1)
    }

    /// Every mode once, the stored order first.
    nonisolated static func normalized(_ stored: [CaptureMode]) -> [CaptureMode] {
        var seen: Set<CaptureMode> = []
        let kept = stored.filter { seen.insert($0).inserted }
        return kept + CaptureMode.allCases.filter { !seen.contains($0) }
    }

    /// The modes the shortcut steps through, in order.
    var modes: [CaptureMode] { order.filter { !modesOff.contains($0) } }

    var tools: [EditorTool] { EditorTool.allCases.filter { !toolsOff.contains($0) } }

    func isOn(_ mode: CaptureMode) -> Bool { !modesOff.contains(mode) }

    /// At least one mode stays on.
    func setOn(_ mode: CaptureMode, _ isOn: Bool) {
        if isOn {
            modesOff.remove(mode)
        } else if modes.count > 1 {
            modesOff.insert(mode)
        }
    }

    func isOn(_ tool: EditorTool) -> Bool { !toolsOff.contains(tool) }

    func setOn(_ tool: EditorTool, _ isOn: Bool) {
        if isOn { toolsOff.remove(tool) } else { toolsOff.insert(tool) }
    }

    func move(_ mode: CaptureMode, to target: CaptureMode) {
        guard mode != target, let source = order.firstIndex(of: mode), let destination = order.firstIndex(of: target) else { return }
        var next = order
        next.remove(at: source)
        next.insert(mode, at: destination)
        order = next
    }
}
