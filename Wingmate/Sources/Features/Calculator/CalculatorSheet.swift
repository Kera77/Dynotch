import Foundation

/// The calculator's lines together (spec SZ-12…SZ-15): variables ("price = 1200"), "20% of 340",
/// units ("5 km in mi") and a total of the lines above ("total").
enum CalculatorSheet {
    /// One result per line, nil where the line is no calculation.
    static func results(for lines: [String]) -> [String?] {
        var variables: [String: Double] = [:]
        var block: [Double] = []
        return lines.map { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                block = []
                return nil
            }
            if totalWords.contains(line.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":="))) {
                defer { block = [] }
                return block.isEmpty ? nil : CalculatorEngine.format(block.reduce(0, +))
            }
            if let assignment = assignment(in: line, variables: variables) {
                variables[assignment.name] = assignment.value
                block.append(assignment.value)
                return CalculatorEngine.format(assignment.value)
            }
            if let converted = UnitConversion.convert(substitute(line, variables)) {
                return converted
            }
            let expression = percentOf(substitute(line, variables))
            guard let shown = CalculatorEngine.result(for: expression) else { return nil }
            if let value = CalculatorEngine.evaluate(expression) { block.append(value) }
            return shown
        }
    }

    static let totalWords: Set<String> = ["total", "sum", "összesen", "osszesen", "össz"]

    /// "name = expression", the name starting with a letter.
    static func assignment(in line: String, variables: [String: Double]) -> (name: String, value: Double)? {
        guard let match = line.range(of: #"^\p{L}[\p{L}\p{N}_]*\s*="#, options: .regularExpression) else { return nil }
        let name = line[match].dropLast().trimmingCharacters(in: .whitespaces).lowercased()
        let expression = String(line[match.upperBound...])
        guard let value = CalculatorEngine.evaluate(percentOf(substitute(expression, variables))) else { return nil }
        return (name, value)
    }

    /// Known names replaced by their values, as whole words.
    static func substitute(_ line: String, _ variables: [String: Double]) -> String {
        var result = line
        for (name, value) in variables.sorted(by: { $0.key.count > $1.key.count }) {
            let pattern = "(?<![\\p{L}\\p{N}_])" + NSRegularExpression.escapedPattern(for: name) + "(?![\\p{L}\\p{N}_])"
            result = result.replacingOccurrences(
                of: pattern, with: "(\(value))", options: [.regularExpression, .caseInsensitive]
            )
        }
        return result
    }

    /// "20% of 340" → "(20/100)*(340)".
    static func percentOf(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"(\d+(?:[.,]\d+)?)\s*%\s*of\s*"#, with: "($1/100)*", options: [.regularExpression, .caseInsensitive]
        )
    }
}

/// "5 km in mi", "70 kg to lb", "30 c in f" (spec SZ-14).
enum UnitConversion {
    private static let units: [String: Dimension] = [
        "mm": UnitLength.millimeters, "cm": UnitLength.centimeters, "m": UnitLength.meters, "km": UnitLength.kilometers,
        "in": UnitLength.inches, "inch": UnitLength.inches, "ft": UnitLength.feet, "yd": UnitLength.yards,
        "mi": UnitLength.miles, "mile": UnitLength.miles, "miles": UnitLength.miles,
        "g": UnitMass.grams, "kg": UnitMass.kilograms, "lb": UnitMass.pounds, "lbs": UnitMass.pounds, "oz": UnitMass.ounces,
        "c": UnitTemperature.celsius, "°c": UnitTemperature.celsius, "f": UnitTemperature.fahrenheit,
        "°f": UnitTemperature.fahrenheit, "k": UnitTemperature.kelvin,
        "ml": UnitVolume.milliliters, "l": UnitVolume.liters, "gal": UnitVolume.gallons,
        "kmh": UnitSpeed.kilometersPerHour, "km/h": UnitSpeed.kilometersPerHour, "mph": UnitSpeed.milesPerHour,
        "b": UnitInformationStorage.bytes, "kb": UnitInformationStorage.kilobytes, "mb": UnitInformationStorage.megabytes,
        "gb": UnitInformationStorage.gigabytes, "tb": UnitInformationStorage.terabytes,
        "s": UnitDuration.seconds, "sec": UnitDuration.seconds, "min": UnitDuration.minutes, "h": UnitDuration.hours
    ]

    static func convert(_ line: String) -> String? {
        let pattern = #"^(.+?)\s*([a-zA-Z°/]+)\s+(?:in|to|->)\s+([a-zA-Z°/]+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let valueRange = Range(match.range(at: 1), in: line),
              let fromRange = Range(match.range(at: 2), in: line),
              let toRange = Range(match.range(at: 3), in: line),
              let from = units[line[fromRange].lowercased()], let target = units[line[toRange].lowercased()],
              type(of: from) == type(of: target),
              let value = CalculatorEngine.evaluate(String(line[valueRange]))
        else { return nil }
        let converted = Measurement(value: value, unit: from).converted(to: target).value
        return CalculatorEngine.format(converted) + " " + line[toRange].lowercased()
    }
}
