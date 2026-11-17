import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut (spec SC-1).
struct KeyShortcut: Codable, Equatable, Sendable {
    let keyCode: UInt32
    /// Carbon modifier bits (cmdKey, optionKey, controlKey, shiftKey).
    let modifiers: UInt32
    /// E.g. "⌥1".
    let display: String

    private static let namedKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋", kVK_Delete: "⌫",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"
    ]

    /// Digits and letters by key position, so Option-1 is "1" and not the symbol it types.
    private static let positionKeys: [Int: String] = [
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9"
    ]

    /// A shortcut from a key press; nil without Command, Option or Control (a plain key would
    /// take that key away from every app).
    static func make(keyCode: UInt16, flags: NSEvent.ModifierFlags, characters: String?) -> KeyShortcut? {
        let flags = flags.intersection([.command, .option, .control, .shift])
        guard !flags.isDisjoint(with: [.command, .option, .control]) else { return nil }
        var carbon: UInt32 = 0
        var symbols = ""
        if flags.contains(.control) { carbon |= UInt32(controlKey); symbols += "⌃" }
        if flags.contains(.option) { carbon |= UInt32(optionKey); symbols += "⌥" }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey); symbols += "⇧" }
        if flags.contains(.command) { carbon |= UInt32(cmdKey); symbols += "⌘" }
        let code = Int(keyCode)
        let typed = (characters ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let key = namedKeys[code] ?? positionKeys[code] ?? (typed.isEmpty ? "Key \(code)" : typed)
        return KeyShortcut(keyCode: UInt32(keyCode), modifiers: carbon, display: symbols + key)
    }
}

/// The features' shortcuts (spec SC-1, SC-2), persisted in UserDefaults.
@MainActor
final class ShortcutStore: ObservableObject {
    private static let shortcutsKey = "featureShortcuts"
    private static let pinKey = "shortcutPins"
    private static let pinShortcutKey = "pinShortcut"
    private static let pinnedKey = "shortcutPinnedFeatures"
    private static let quickAskKey = "aiQuickAskShortcutSet"

    @Published private(set) var shortcuts: [FeatureID: KeyShortcut] {
        didSet { save() }
    }

    /// The features whose shortcut also pins the panel, so it stays open (spec SC-2).
    @Published private(set) var pinnedFeatures: Set<FeatureID> {
        didSet { defaults.set(pinnedFeatures.map(\.rawValue).sorted(), forKey: Self.pinnedKey) }
    }

    func pins(_ feature: FeatureID) -> Bool {
        pinnedFeatures.contains(feature)
    }

    /// Pinning only means something for a module that has a shortcut.
    func pinsWhenOpened(_ feature: FeatureID) -> Bool {
        shortcuts[feature] != nil && pins(feature)
    }

    func setPins(_ feature: FeatureID, _ pins: Bool) {
        if pins {
            pinnedFeatures.insert(feature)
        } else {
            pinnedFeatures.remove(feature)
        }
    }

    /// Pins the notch open, or releases it (spec SC-3).
    @Published private(set) var pinShortcut: KeyShortcut? {
        didSet { defaults.set(pinShortcut.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.pinShortcutKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.data(forKey: Self.shortcutsKey)
            .flatMap { try? JSONDecoder().decode([String: KeyShortcut].self, from: $0) } ?? [:]
        var loaded: [FeatureID: KeyShortcut] = [:]
        for (name, shortcut) in stored {
            if let feature = FeatureID(rawValue: name) { loaded[feature] = shortcut }
        }
        shortcuts = loaded
        if let stored = defaults.stringArray(forKey: Self.pinnedKey) {
            pinnedFeatures = Set(stored.compactMap(FeatureID.init(rawValue:)))
        } else {
            // Before 0.26 one switch pinned every feature.
            pinnedFeatures = defaults.bool(forKey: Self.pinKey) ? Set(FeatureID.allCases) : []
        }
        pinShortcut = defaults.data(forKey: Self.pinShortcutKey).flatMap { try? JSONDecoder().decode(KeyShortcut.self, from: $0) }
        // A quick question from anywhere (spec AI-4): ⌃⌥A, once, if the module has no shortcut.
        if !defaults.bool(forKey: Self.quickAskKey) {
            defaults.set(true, forKey: Self.quickAskKey)
            if shortcuts[.claudeChat] == nil {
                shortcuts[.claudeChat] = .controlOptionA
                // didSet does not run in init.
                save()
            }
        }
    }

    private static func same(_ lhs: KeyShortcut, _ rhs: KeyShortcut) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }

    func setPinShortcut(_ shortcut: KeyShortcut?) {
        if let shortcut {
            shortcuts = shortcuts.filter { !Self.same($0.value, shortcut) }
        }
        pinShortcut = shortcut
    }

    /// Sets or clears a feature's shortcut; a combination belongs to one feature only.
    func set(_ shortcut: KeyShortcut?, for feature: FeatureID) {
        var updated = shortcuts
        if let shortcut {
            updated = updated.filter { !Self.same($0.value, shortcut) }
            if let pinShortcut, Self.same(pinShortcut, shortcut) { self.pinShortcut = nil }
        }
        updated[feature] = shortcut
        shortcuts = updated
    }

    private func save() {
        let named = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(named) { defaults.set(data, forKey: Self.shortcutsKey) }
    }
}

extension KeyShortcut {
    /// ⌃⌥A: the AI module's quick question (spec AI-4).
    static let controlOptionA = KeyShortcut(keyCode: 0, modifiers: 0x1000 | 0x0800, display: "⌃⌥A")
}
