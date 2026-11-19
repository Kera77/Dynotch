@testable import Dynotch
import Foundation
import Testing

struct V069Tests {
    @Test func claudeFinishedNamesTheAppItRanIn() throws {
        let url = try #require(URL(string: "dynotch://claude-finished?project=Dynotch&app=com.microsoft.VSCode"))
        let notice = try #require(ClaudeHook.notice(from: url, now: Date()))
        #expect(notice.appIdentifier == "com.microsoft.VSCode")
        let old = try #require(URL(string: "dynotch://claude-finished?project=Dynotch&app="))
        #expect(ClaudeHook.notice(from: old, now: Date())?.appIdentifier == nil)
        #expect(ClaudeHook.command.contains("app=${__CFBundleIdentifier:-}"))
    }

    @Test func codexFinishedIsAChatGPTNotice() throws {
        let url = try #require(URL(string: "dynotch://codex-finished?project=site&app=com.openai.codex"))
        let notice = try #require(CodexHook.notice(from: url, now: Date()))
        #expect(notice.title == "ChatGPT finished")
        #expect(notice.detail == "site")
        #expect(notice.appIdentifier == "com.openai.codex")
        #expect(CodexHook.notice(from: try #require(URL(string: "dynotch://claude-finished?project=x")), now: Date()) == nil)
    }

    @Test func codexHookKeepsOtherAppsHooks() {
        let other: [String: Any] = ["hooks": ["Stop": [["hooks": [["type": "command", "command": "bartender.sh"]]]]]]
        let installed = CodexHook.hooks(other, installed: true)
        #expect(CodexHook.isInstalled(in: installed))
        let stop = ((installed["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]) ?? []
        #expect(stop.count == 2)
        let removed = CodexHook.hooks(installed, installed: false)
        #expect(!CodexHook.isInstalled(in: removed))
        #expect((((removed["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]) ?? []).count == 1)
    }

    @Test func codexHooksFeatureIsTurnedOnOnce() {
        let isOn = "[features]\ncodex_hooks = true  # other\n"
        #expect(CodexHook.configWithHooksOn(isOn) == isOn)
        let features = CodexHook.configWithHooksOn("model = \"x\"\n[features]\nfoo = 1\n")
        #expect(features.contains("[features]\ncodex_hooks = true"))
        let none = CodexHook.configWithHooksOn("model = \"x\"\n")
        #expect(none.hasPrefix("codex_hooks = true"))
        let off = CodexHook.configWithHooksOn("[features]\ncodex_hooks = false\n")
        #expect(off.contains("codex_hooks = true") && !off.contains("false"))
    }

    @Test func theProjectsWindowIsFoundByTitle() {
        let titles = ["notes.md — Other", "NotchView.swift — Dynotch", "Dynotch-old"]
        #expect(NoticeApp.window(among: titles, naming: "Dynotch") == 1)
        #expect(NoticeApp.window(among: ["a — egy-50-000"], naming: "egy-50-000") == 0)
        #expect(NoticeApp.window(among: titles, naming: "Missing") == nil)
    }
}

struct MenuBarTintTests {
    @Test func hexColorsRoundTrip() throws {
        let rgb = try #require(TintColor.rgb("#7F5AF0"))
        #expect(TintColor.hex(red: rgb.red, green: rgb.green, blue: rgb.blue) == "#7F5AF0")
        #expect(TintColor.rgb("nope") == nil)
    }

    @Test func theStripCoversTheMenuBarOnly() throws {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = try #require(MenuBarTintService.menuBarFrame(screen: screen, visible: CGRect(x: 0, y: 0, width: 1512, height: 945)))
        #expect(frame == CGRect(x: 0, y: 945, width: 1512, height: 37))
        // The menu bar's own window is a point lower than the room on a display with a notch.
        let drawn = MenuBarTintService.menuBarFrame(screen: screen, visible: CGRect(x: 0, y: 0, width: 1512, height: 943), drawn: 38)
        #expect(drawn?.height == 38)
        #expect(drawn?.maxY == 982)
        // The notch's place is left clear.
        let gap = MenuBarTintService.notchGap(
            screenWidth: 1512, left: CGRect(x: 0, y: 945, width: 660, height: 37),
            right: CGRect(x: 852, y: 945, width: 660, height: 37), screenMinX: 0
        )
        #expect(gap == 660...852)
        #expect(MenuBarTintService.notchGap(screenWidth: 1512, left: nil, right: nil, screenMinX: 0) == nil)
        // A menu bar that hides by itself leaves no room: no strip.
        #expect(MenuBarTintService.menuBarFrame(screen: screen, visible: screen) == nil)
    }

    @Test func darkModeUsesItsOwnPairUnlessShared() {
        var style = MenuBarTintStyle()
        style.sameInBoth = false
        #expect(style.pair(dark: true) == style.dark)
        style.sameInBoth = true
        #expect(style.pair(dark: true) == style.light)
    }
}

struct GoogleChatSidebarTests {
    @Test func theNameSkipsTheUnreadMarkerAndTheStatus() {
        let texts = ["Olvasatlan", "Sales - Support", "Privát", "Kiemelt bejegyzés", "2 értesítés"]
        let space = GoogleChatWebReader.nameAndCount(texts, isDirect: false)
        #expect(space.name == "Sales - Support")
        #expect(space.count == 2)
        let readSpace = GoogleChatWebReader.nameAndCount(["Kereskedés Infó", "Beszélgetés"], isDirect: false)
        #expect(readSpace.name == "Kereskedés Infó")
        #expect(readSpace.count == nil)
        let direct = GoogleChatWebReader.nameAndCount(["Nincs a gépnél", "Olvasatlan", "Mark Smith", "1 értesítés"], isDirect: true)
        #expect(direct.name == "Mark Smith")
        #expect(direct.count == 1)
        #expect(GoogleChatWebReader.nameAndCount(["Anna Kovács"], isDirect: true).name == "Anna Kovács")
    }

    @Test func theCardSaysHowManyAreUnread() {
        #expect(NotificationService.unreadText(nil) == "1 unread message in Google Chat")
        #expect(NotificationService.unreadText(3) == "3 unread messages in Google Chat")
        #expect(NotificationService.unreadCount(in: "3 unread messages in Google Chat") == 3)
    }
}
