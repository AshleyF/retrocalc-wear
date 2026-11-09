import Foundation

/// Number formatting that matches the Wear app: Java `Double.toString` for ordinary
/// results, and `DecimalFormat("0.0####E0")` when a value has to be forced into
/// scientific notation to fit the seven-digit LCD.
enum DoubleFormat {
    static func displayValue(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        if value == .infinity { return "Infinity" }
        if value == -.infinity { return "-Infinity" }
        if let exact = Int64(exactly: value) {
            return String(exact)
        }
        return javaToString(value)
    }

    /// Shortest round-trip decimal, written the way `Double.toString` writes it.
    static func javaToString(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        if value == .infinity { return "Infinity" }
        if value == -.infinity { return "-Infinity" }
        if value == 0 {
            return value.sign == .minus ? "-0.0" : "0.0"
        }
        let negative = value < 0
        let (digits, exponent) = significand(String(abs(value)))
        let body = (exponent < -3 || exponent >= 7)
            ? formatScientific(digits: digits, exponent: exponent)
            : formatPlain(digits: digits, exponent: exponent)
        return negative ? "-" + body : body
    }

    /// `DecimalFormat` pattern `0.0####E0`: six significant digits, at least one
    /// fraction digit, half-even rounding, no plus on the exponent.
    static func decimalFormatScientific(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        if value == .infinity { return "Infinity" }
        if value == -.infinity { return "-Infinity" }
        if value == 0 { return "0.0E0" }
        let negative = value < 0
        let (digits, exponent) = significand(String(abs(value)))
        let rounded = roundHalfEven(digits, maxDigits: 6)
        let body = formatScientific(digits: rounded.digits, exponent: exponent + rounded.exponentDelta)
        return negative ? "-" + body : body
    }

    /// Significant digits of a Swift `String(double)`, and the power of ten of the first digit.
    static func significand(_ swift: String) -> (digits: String, exponent: Int) {
        var text = swift.lowercased()
        if text.hasPrefix("-") { text.removeFirst() }
        var exponent = 0
        if let marker = text.firstIndex(of: "e") {
            exponent = Int(text[text.index(after: marker)...]) ?? 0
            text = String(text[..<marker])
        }
        let pieces = text.split(separator: ".", omittingEmptySubsequences: false)
        let whole = pieces.isEmpty ? "0" : String(pieces[0])
        let fraction = pieces.count > 1 ? String(pieces[1]) : ""
        if whole != "0" && !whole.isEmpty {
            let lead = whole.count - 1 + exponent
            let digits = trimZeros(whole + fraction)
            return (digits.isEmpty ? "0" : digits, lead)
        }
        var zeros = 0
        for character in fraction where character == "0" {
            zeros += 1
        }
        if zeros != fraction.count {
            // The loop above counts every zero, including ones after a nonzero digit.
            zeros = 0
            for character in fraction {
                if character == "0" { zeros += 1 } else { break }
            }
        }
        let digits = trimZeros(String(fraction.dropFirst(zeros)))
        return (digits.isEmpty ? "0" : digits, exponent - zeros - 1)
    }

    private static func formatScientific(digits: String, exponent: Int) -> String {
        let safe = digits.isEmpty ? "0" : digits
        let lead = safe.first!
        var fraction = trimZeros(String(safe.dropFirst()))
        if fraction.isEmpty { fraction = "0" }
        return "\(lead).\(fraction)E\(exponent)"
    }

    private static func formatPlain(digits: String, exponent: Int) -> String {
        let safe = digits.isEmpty ? "0" : digits
        if exponent >= 0 {
            let integerCount = exponent + 1
            var all = safe
            if all.count < integerCount {
                all += String(repeating: "0", count: integerCount - all.count)
            }
            let integerPart = all.prefix(integerCount)
            var fraction = String(all.dropFirst(integerCount))
            fraction = trimZeros(fraction)
            if fraction.isEmpty { fraction = "0" }
            return "\(integerPart).\(fraction)"
        }
        let zeros = String(repeating: "0", count: max(0, -exponent - 1))
        return "0.\(zeros)\(safe)"
    }

    private static func roundHalfEven(_ digits: String, maxDigits: Int) -> (digits: String, exponentDelta: Int) {
        if digits.count <= maxDigits {
            return (digits, 0)
        }
        let kept = Array(digits.prefix(maxDigits))
        let rest = digits.dropFirst(maxDigits)
        let next = rest.first ?? "0"
        let nonzeroRemainder = rest.dropFirst().contains { $0 != "0" }
        var roundUp = false
        if next > "5" {
            roundUp = true
        } else if next == "5" {
            if nonzeroRemainder {
                roundUp = true
            } else if let last = kept.last, let value = last.wholeNumberValue, value % 2 == 1 {
                roundUp = true
            }
        }
        if !roundUp {
            return (trimZeros(String(kept)), 0)
        }
        var chars = kept
        var index = chars.count - 1
        while index >= 0 {
            if chars[index] < "9" {
                chars[index] = Character(UnicodeScalar(chars[index].asciiValue! + 1))
                return (trimZeros(String(chars)), 0)
            }
            chars[index] = "0"
            index -= 1
        }
        return ("1", 1)
    }

    private static func trimZeros(_ digits: String) -> String {
        var text = digits
        while text.count > 1 && text.last == "0" {
            text.removeLast()
        }
        return text
    }
}
