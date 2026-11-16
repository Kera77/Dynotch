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
            try
                send theText to participant theNumber of theAccount
            on error
                send theText to buddy theNumber of theAccount
            end try
        end tell
    end run
    """

    /// The caller in Contacts: by number if the banner shows one, otherwise by name. Gives the
    /// name, the number to text (mobile first) and the picture.
    static func contact(for caller: String) -> CallerContact {
        let isNumber = CallMatcher.isPhoneNumber(caller)
        var result = CallerContact(name: nil, number: isNumber ? caller : nil, imageData: nil)
        let store = CNContactStore()
        if CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
            // Called off the main thread: wait for the answer to the system prompt.
            let answered = DispatchSemaphore(value: 0)
            store.requestAccess(for: .contacts) { _, _ in answered.signal() }
            answered.wait()
        }
        let keys = [
            CNContactPhoneNumbersKey, CNContactThumbnailImageDataKey, CNContactGivenNameKey, CNContactFamilyNameKey,
            CNContactOrganizationNameKey
        ] as [CNKeyDescriptor]
        let predicate = isNumber
            ? CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: caller))
            : CNContact.predicateForContacts(matchingName: caller)
        guard let contact = (try? store.unifiedContacts(matching: predicate, keysToFetch: keys))?.first else { return result }
        let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        result.name = name.isEmpty ? (contact.organizationName.isEmpty ? nil : contact.organizationName) : name
        result.imageData = contact.thumbnailImageData
        if result.number == nil {
            let numbers = contact.phoneNumbers
            let mobile = numbers.first { ($0.label ?? "").lowercased().contains("mobile") || $0.label == CNLabelPhoneNumberiPhone }
            result.number = (mobile ?? numbers.first)?.value.stringValue
        }
        return result
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
        guard let number = contact(for: caller).number else { throw Failure.noNumber }
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
