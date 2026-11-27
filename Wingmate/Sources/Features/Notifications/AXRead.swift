import ApplicationServices
import Foundation

/// Small Accessibility accessors.
enum AXRead {
    nonisolated static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    nonisolated static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        value(element, attribute) as? String
    }

    nonisolated static func strings(_ element: AXUIElement, _ attribute: String) -> [String] {
        value(element, attribute) as? [String] ?? []
    }

    nonisolated static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        value(element, attribute) as? Bool
    }

    nonisolated static func url(_ element: AXUIElement) -> URL? {
        value(element, kAXURLAttribute) as? URL
    }

    nonisolated static func children(_ element: AXUIElement) -> [AXUIElement] {
        guard let list = value(element, kAXChildrenAttribute), CFGetTypeID(list) == CFArrayGetTypeID() else { return [] }
        return (list as? [AXUIElement]) ?? []
    }

    /// The first element with the role under `root` (page order, without recursion) that passes `test`.
    nonisolated static func first(
        in root: AXUIElement, role: String, limit: Int = 8000, where test: (AXUIElement) -> Bool = { _ in true }
    ) -> AXUIElement? {
        var stack = [root]
        var visited = 0
        while let element = stack.popLast(), visited < limit {
            visited += 1
            if string(element, kAXRoleAttribute) == role, test(element) { return element }
            stack += children(element).reversed()
        }
        return nil
    }

    /// The static texts under an element, in order.
    nonisolated static func texts(in element: AXUIElement, depth: Int = 0) -> [String] {
        guard depth < 12 else { return [] }
        if string(element, kAXRoleAttribute) == (kAXStaticTextRole as String) {
            return [string(element, kAXValueAttribute) ?? ""].filter { !$0.isEmpty }
        }
        return children(element).flatMap { texts(in: $0, depth: depth + 1) }
    }
}
