import Contacts
import Foundation

/// Sends a text message to the caller through the Messages app (spec P-3).
enum CallMessenger {
    enum Failure: Error, Equatable {
        case noNumber
        case failed(String)

        var message: String {
            switch self {
            case .noNumber: "The caller is unknown, so there is nobody to send to."
            case .failed(let text): text
            }
        }
    }

    /// Tries every address of the caller: as a text message first, then as an iMessage.
    private static let script = """
    on run argv
        set theText to item 1 of argv
        set wasSent to false
        set lastError to "No address to send to."
        tell application "Messages"
            repeat with i from 2 to (count of argv)
                set theTarget to item i of argv
                repeat with theType in {SMS, iMessage}
                    if not wasSent then
                        try
                            set theAccount to first account whose service type = theType
                            send theText to participant theTarget of theAccount
                            set wasSent to true
                        on error errorMessage
                            set lastError to errorMessage
                        end try
                    end if
                end repeat
            end repeat
        end tell
        if not wasSent then error lastError
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
            CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactThumbnailImageDataKey,
            CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey
        ] as [CNKeyDescriptor]
        let predicate = isNumber
            ? CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: caller))
            : CNContact.predicateForContacts(matchingName: caller)
        guard let contact = (try? store.unifiedContacts(matching: predicate, keysToFetch: keys))?.first else { return result }
        let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        result.name = name.isEmpty ? (contact.organizationName.isEmpty ? nil : contact.organizationName) : name
        result.imageData = contact.thumbnailImageData
        result.emails = contact.emailAddresses.map { $0.value as String }
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

    /// Where a message can go, best first: the number, the e-mail addresses (iMessage), and the
    /// name itself, which Messages resolves for people it already has a conversation with.
    static func targets(for caller: String, contact: CallerContact) -> [String] {
        var targets = [contact.number].compactMap { $0 } + contact.emails
        if caller != CallMatcher.unknownCaller, !CallMatcher.isPhoneNumber(caller) { targets.append(caller) }
        var seen = Set<String>()
        return targets.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    static func send(_ text: String, toCaller caller: String) throws {
        let targets = targets(for: caller, contact: contact(for: caller))
        guard !targets.isEmpty else { throw Failure.noNumber }
        guard let result = ProcessRunner.run("/usr/bin/osascript", ["-e", script, text] + targets, timeout: 30) else {
            throw Failure.failed("osascript could not start")
        }
        guard result.succeeded else {
            let message = result.timedOut ? "Messages did not answer in time." : result.errorText
            throw Failure.failed(message.isEmpty ? "Messages could not send the text." : String(message.prefix(200)))
        }
    }
}
