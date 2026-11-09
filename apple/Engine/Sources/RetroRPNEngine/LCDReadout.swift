import Foundation

public struct LCDCell: Equatable {
    public enum Glyph: Equatable {
        case blank
        case digit(Character)
        case minus
        case letter(Character)
    }

    public var glyph: Glyph
    public var dot: Bool

    public static let empty = LCDCell(glyph: .blank, dot: false)

    public init(glyph: Glyph, dot: Bool) {
        self.glyph = glyph
        self.dot = dot
    }
}

public struct LCDReadout: Equatable {
    public var cells: [LCDCell]

    public init() {
        cells = Array(repeating: .empty, count: 7)
    }

    /// Right-aligned text with a decimal point attached to the digit it follows.
    public var debugText: String {
        cells.map { cell in
            let symbol: String
            switch cell.glyph {
            case .blank:
                symbol = " "
            case .digit(let character), .letter(let character):
                symbol = String(character)
            case .minus:
                symbol = "-"
            }
            return symbol + (cell.dot ? "." : "")
        }.joined()
    }
}

public enum LCDRenderer {
    /// Port of `renderValue` from the Wear activity. `text` is the entry string
    /// for X, or `displayValue` for the other stack registers.
    public static func render(value: Double, text: String) -> LCDReadout {
        var line = LCDReadout()
        if text == "Infinity" {
            line.cells[2].glyph = .digit("1")
            line.cells[3].glyph = .letter("n")
            line.cells[4].glyph = .letter("f")
            line.cells[5].glyph = .letter("i")
            line.cells[6].glyph = .letter("n")
            return line
        }
        if text == "-Infinity" {
            line.cells[1].glyph = .minus
            line.cells[2].glyph = .digit("1")
            line.cells[3].glyph = .letter("n")
            line.cells[4].glyph = .letter("f")
            line.cells[5].glyph = .letter("i")
            line.cells[6].glyph = .letter("n")
            return line
        }
        if text == "NaN" {
            line.cells[2].glyph = .letter("e")
            line.cells[3].glyph = .letter("r")
            line.cells[4].glyph = .letter("r")
            line.cells[5].glyph = .letter("o")
            line.cells[6].glyph = .letter("r")
            return line
        }

        var parts = text.split(separator: "E", omittingEmptySubsequences: false).map(String.init)
        var exponentLength = 0
        var index = 6
        if parts.count > 1 {
            exponentLength = measuredExponent(parts[1])
            index -= exponentLength
        } else if needsScientific(value) {
            let scientific = DoubleFormat.decimalFormatScientific(value)
            parts = scientific.split(separator: "E", omittingEmptySubsequences: false).map(String.init)
            if parts.count > 1 {
                exponentLength = measuredExponent(parts[1])
                index -= exponentLength
            }
        }

        var mantissa = parts[0]
        let maxLength = (mantissa.contains(".") ? 8 : 7) - exponentLength
        if mantissa.count > maxLength {
            mantissa = String(mantissa.prefix(maxLength))
        }
        for character in mantissa.reversed() {
            if character == "." {
                if line.cells.indices.contains(index) {
                    line.cells[index].dot = true
                }
            } else if line.cells.indices.contains(index) {
                line.cells[index].glyph = glyph(for: character)
                index -= 1
            }
        }

        if parts.count > 1 {
            var exponentIndex = 6
            var negative = false
            for character in parts[1].reversed() {
                if character == "-" { negative = true }
                if line.cells.indices.contains(exponentIndex) {
                    line.cells[exponentIndex].glyph = glyph(for: character)
                }
                exponentIndex -= 1
            }
            if !negative, line.cells.indices.contains(exponentIndex) {
                line.cells[exponentIndex].glyph = .blank
            }
        }
        return line
    }

    private static func needsScientific(_ value: Double) -> Bool {
        value > 9_999_999
            || value < -999_999
            || (value > 0 && value < 0.000_001)
            || (value < 0 && value > -0.000_01)
    }

    private static func measuredExponent(_ exponent: String) -> Int {
        var length = exponent.count
        if exponent.first != "-" { length += 1 }
        return length
    }

    private static func glyph(for character: Character) -> LCDCell.Glyph {
        switch character {
        case "-":
            return .minus
        case "0"..."9":
            return .digit(character)
        case "e", "r", "o", "n", "f", "i":
            return .letter(character)
        default:
            return .blank
        }
    }
}
