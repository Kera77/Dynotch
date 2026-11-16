import Contacts
import Foundation

/// Sends a text message to the caller through the Messages app (spec P-3).
enum CallMessenger {
    enum Failure: Error, Equatable {
        case noNumber
        case failed(String)

        var message: String {
            switch self {
            case .noNumber: "No phone number found for this caller."
            case .failed(let text): text
            }
        }
    }

    private static let script = """
    on run argv
        set theNumber to item 1 of argv
        set theText to item 2 of argv
        tell application "Messages"
            try
                set theAccount to first account whose service type = SMS
            on error
                set theAccount to first account whose service type = iMessage
            end try
            send theText to participant theNumber of theAccount
        end tell
    end run
    """

    /// The caller's number: the caller text itself, or the contact of that name (mobile first).
    static func number(for caller: String) -> String? {
        if CallMatcher.isPhoneNumber(caller) { return caller }
        let store = CNContactStore()
        if CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
            // Called off the main thread: wait for the answer to the system prompt.
            let answered = DispatchSemaphore(value: 0)
            store.requestAccess(for: .contacts) { _, _ in answered.signal() }
            answered.wait()
        }
        let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
        let predicate = CNContact.predicateForContacts(matchingName: caller)
        guard let contacts = try? store.unifiedContacts(matching: predicate, keysToFetch: keys) else { return nil }
        let numbers = contacts.flatMap(\.phoneNumbers)
        let mobile = numbers.first { ($0.label ?? "").lowercased().contains("mobile") || $0.label == CNLabelPhoneNumberiPhone }
        return (mobile ?? numbers.first)?.value.stringValue
    }

    /// Sends the text; nil when it went out.
    static func failure(sending text: String, toCaller caller: String) -> Failure? {
        do {
            try send(text, toCaller: caller)
            return nil
        } catch let failure as Failure {
            return failure
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    static func send(_ text: String, toCaller caller: String) throws {
        guard let number = number(for: caller) else { throw Failure.noNumber }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, number, text]
        let errors = Pipe()
        process.standardOutput = Pipe()
        process.standardError = errors
        do {
            try process.run()
        } catch {
            throw Failure.failed(error.localizedDescription)
        }
        let data = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw Failure.failed(message.isEmpty ? "Messages could not send the text." : String(message.prefix(200)))
        }
    }
}
