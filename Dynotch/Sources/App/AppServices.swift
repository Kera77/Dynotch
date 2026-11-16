import Foundation

/// The app-wide objects every notch panel needs.
@MainActor
struct AppServices {
    let settings: AppSettings
    let calendar: CalendarService
    let notifications: NotificationService
    let calculator: CalculatorStore
    let notes: NotesStore
    let reminders: RemindersStore
    let claudeUsage: ClaudeUsageService
    let hud: HUDService
    let badges: BadgeService
    let calls: CallService
    let keyboardLock: KeyboardLock
    let shortcuts: ShortcutStore
    let notices: NoticeService
    let chat: ClaudeChatService
}
