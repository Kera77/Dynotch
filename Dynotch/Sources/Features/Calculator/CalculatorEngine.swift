import Foundation

/// Evaluates one line of the calculator notepad (spec SZ-2…SZ-4).
enum CalculatorEngine {
    enum Token: Equatable {
        case number(Double)
        /// One of + - * / ^ ( ) %
        case symbol(Character)
    }

    /// Formatted result of a line, or nil if the line is not a calculation
    /// (plain text, a lone number, or an incomplete expression).
    static func result(for line: String) -> String? {
        guard let tokens = tokenize(line), tokens.count > 1 else { return nil }
        var parser = Parser(tokens: tokens)
        guard let value = parser.parseAll(), value.isFinite else { return nil }
        return format(value)
    }

    static func evaluate(_ line: String) -> Double? {
        guard let tokens = tokenize(line) else { return nil }
        var parser = Parser(tokens: tokens)
        guard let value = parser.parseAll(), value.isFinite else { return nil }
        return value
    }

    /// Up to 8 decimals, decimal comma, digits grouped by non-breaking spaces: "1 234,5".
    static func format(_ value: Double) -> String {
        let rounded = (value * 1e8).rounded() / 1e8
        guard abs(rounded) < 1e15 else { return String(format: "%g", value) }

        var text = String(format: "%.8f", abs(rounded))
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }

        let parts = text.split(separator: ".", maxSplits: 1)
        var grouped = ""
        for (offset, digit) in (parts.first ?? "0").reversed().enumerated() {
            if offset > 0, offset % 3 == 0 { grouped.append("\u{00A0}") }
            grouped.append(digit)
        }
        var output = String(grouped.reversed())
        if parts.count > 1 { output += "," + parts[1] }
        return rounded < 0 ? "-" + output : output
    }

    // MARK: - Tokenizer

    static func tokenize(_ line: String) -> [Token]? {
        let characters = Array(line)
        var tokens: [Token] = []
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character.isWhitespace {
                index += 1
            } else if isDigit(character) || character == "." || character == "," {
                guard let (value, next) = readNumber(characters, from: index) else { return nil }
                tokens.append(.number(value))
                index = next
            } else if let symbol = symbol(for: character) {
                tokens.append(.symbol(symbol))
                index += 1
            } else {
                return nil
            }
        }
        return tokens.isEmpty ? nil : tokens
    }

    /// Reads a number: decimal point or comma, and spaces as thousands separators ("1 200,5").
    private static func readNumber(_ characters: [Character], from start: Int) -> (Double, Int)? {
        var text = ""
        var index = start
        var hasSeparator = false
        while index < characters.count {
            let character = characters[index]
            if isDigit(character) {
                text.append(character)
            } else if !hasSeparator, character == "." || character == "," {
                hasSeparator = true
                text.append(".")
            } else if character == " ", !hasSeparator, !text.isEmpty, isThousandsGroup(characters, after: index) {
                // Skip the separator.
            } else {
                break
            }
            index += 1
        }
        return Double(text).map { ($0, index) }
    }

    /// True if exactly three digits follow the position.
    private static func isThousandsGroup(_ characters: [Character], after index: Int) -> Bool {
        let last = index + 3
        guard last < characters.count, characters[(index + 1)...last].allSatisfy(isDigit) else { return false }
        return last + 1 >= characters.count || !isDigit(characters[last + 1])
    }

    private static func isDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }

    private static func symbol(for character: Character) -> Character? {
        switch character {
        case "+", "-", "*", "/", "^", "(", ")", "%": character
        case "×", "x", "X", "·": "*"
        case "÷": "/"
        case "−", "–": "-"
        default: nil
        }
    }
}

// MARK: - Parser

private struct Operand {
    var value: Double
    /// Written with a % sign: "200 + 10%" adds ten percent of 200.
    var isPercent = false
}

/// Recursive descent: expression → term → power → unary → postfix → primary.
private struct Parser {
    let tokens: [CalculatorEngine.Token]
    var index = 0

    mutating func parseAll() -> Double? {
        guard let result = expression(), index == tokens.count else { return nil }
        return result.value
    }

    private mutating func accept(_ symbol: Character) -> Bool {
        guard index < tokens.count, tokens[index] == .symbol(symbol) else { return false }
        index += 1
        return true
    }

    private mutating func expression() -> Operand? {
        guard var left = term() else { return nil }
        while true {
            let sign: Double
            if accept("+") {
                sign = 1
            } else if accept("-") {
                sign = -1
            } else {
                return left
            }
            guard let right = term() else { return nil }
            let amount = right.isPercent ? left.value * right.value : right.value
            left = Operand(value: left.value + sign * amount)
        }
    }

    private mutating func term() -> Operand? {
        guard var left = power() else { return nil }
        while true {
            if accept("*") {
                guard let right = power() else { return nil }
                left = Operand(value: left.value * right.value)
            } else if accept("/") {
                guard let right = power(), right.value != 0 else { return nil }
                left = Operand(value: left.value / right.value)
            } else {
                return left
            }
        }
    }

    private mutating func power() -> Operand? {
        guard let base = unary() else { return nil }
        guard accept("^") else { return base }
        guard let exponent = power() else { return nil }
        return Operand(value: pow(base.value, exponent.value))
    }

    private mutating func unary() -> Operand? {
        if accept("-") {
            guard var operand = unary() else { return nil }
            operand.value = -operand.value
            return operand
        }
        if accept("+") { return unary() }
        return postfix()
    }

    private mutating func postfix() -> Operand? {
        guard var operand = primary() else { return nil }
        while accept("%") {
            operand = Operand(value: operand.value / 100, isPercent: true)
        }
        return operand
    }

    private mutating func primary() -> Operand? {
        guard index < tokens.count else { return nil }
        if case .number(let value) = tokens[index] {
            index += 1
            return Operand(value: value)
        }
        guard accept("("), let inner = expression(), accept(")") else { return nil }
        return Operand(value: inner.value)
    }
}
