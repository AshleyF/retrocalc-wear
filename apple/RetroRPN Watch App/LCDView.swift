import RetroRPNEngine
import SwiftUI

struct LCDView: View {
    private static let stackRowGap: CGFloat = 3

    @ObservedObject var calc: RPNCalculator
    var showsStack: Bool
    var usesLed = false
    /// The expanded face draws the credit beside this view, so the rows can fill what remains.
    var showsCredit: Bool = true
    var drawsChrome: Bool = true
    /// False is the manual's order, ST down to X. True is X on top.
    var stackXOnTop: Bool = false
    var onLabelTap: (() -> Void)? = nil
    var onDigitsTap: (() -> Void)? = nil

    var body: some View {
        let screen = GeometryReader { geo in
            let creditHeight: CGFloat = showsStack && showsCredit ? max(14, geo.size.height * 0.075) : 0
            let rows = showsStack ? 5 : 1
            let annunciatorWidth: CGFloat = 13
            // The stack labels sit to the left of the digits. The digits give up a little width for them.
            let labelWidth = showsStack ? Self.stackLabelWidth(geo.size.width) : 0
            let labelSize = min(13, max(8, labelWidth * 0.46))
            let cellWidth = Self.cellWidth(geo.size.width, labelWidth: labelWidth)
            let rowArea = max(1, geo.size.height - creditHeight)
            let naturalHeight = cellWidth * (53 / 43)
            let rowGap = showsStack ? Self.stackRowGap : 0
            let gapHeight = rowGap * CGFloat(rows - 1)
            let cellHeight = min(naturalHeight, max(1, (rowArea - (showsStack ? gapHeight : 4)) / CGFloat(rows)))
            VStack(spacing: 0) {
                VStack(spacing: rowGap) {
                    ForEach(0..<rows, id: \.self) { row in
                        let register = Self.stackRegister(row, rows: rows, xOnTop: stackXOnTop)
                        HStack(spacing: 2) {
                            if showsStack {
                                stackLabel(register, width: labelWidth, height: cellHeight, size: labelSize)
                            }
                            if showsStack, let onDigitsTap {
                                ImmediateButton(action: onDigitsTap) {
                                    HStack(spacing: 2) {
                                        readout(register, cellWidth: cellWidth, cellHeight: cellHeight)
                                        marks(register, width: annunciatorWidth, height: cellHeight)
                                    }
                                }
                            } else {
                                readout(register, cellWidth: cellWidth, cellHeight: cellHeight)
                                marks(register, width: annunciatorWidth, height: cellHeight)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                if showsStack && showsCredit {
                    creditLine(width: geo.size.width)
                        .frame(height: creditHeight, alignment: .bottom)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        if drawsChrome {
            let rim = RoundedRectangle(cornerRadius: 4, style: .continuous)
            screen
                .padding(.horizontal, 3)
                .padding(.vertical, 3)
                .background(usesLed ? Theme.led : Theme.lcd, in: rim)
                .overlay {
                    rim.strokeBorder(usesLed ? Theme.ledInactive : Theme.lcdInactive, lineWidth: 0.75)
                        .allowsHitTesting(false)
                }
        } else {
            screen
        }
    }

    static func idealStackHeight(width: CGFloat) -> CGFloat {
        cellWidth(width, labelWidth: stackLabelWidth(width)) * (53 / 43) * 5 + stackRowGap * 4
    }

    private static func stackLabelWidth(_ width: CGFloat) -> CGFloat {
        min(28, max(16, width * 0.09))
    }

    private static func cellWidth(_ width: CGFloat, labelWidth: CGFloat) -> CGFloat {
        max(1, (width - 13 - 6 - labelWidth) / 7)
    }

    /// Marketing version from the watch bundle, so the face stays in step with the build.
    static var creditTitle: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.8"
        return "RetroRPN \(version)"
    }

    /// The Wear stack screen prints the version at the left and the author at the right.
    private func creditLine(width: CGFloat) -> some View {
        let title = Self.creditTitle
        return HStack(spacing: 4) {
            Text(title)
            Spacer(minLength: 4)
            Text("Ashley Feniello")
        }
        .font(.system(size: max(7, width * 0.042), weight: .medium))
        .foregroundStyle(usesLed ? Theme.ledCredit : Theme.credit)
        .shadow(color: usesLed ? Theme.ledCredit.opacity(0.48) : .clear, radius: 1.15)
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .padding(.horizontal, 4)
        .padding(.bottom, 3)
    }

    /// Top to bottom. The manual puts X at the bottom. X on top is the other way.
    private static func stackRegister(_ row: Int, rows: Int, xOnTop: Bool) -> Int {
        if rows == 1 || xOnTop { return row }
        return rows - 1 - row
    }

    private static func registerLabel(_ register: Int) -> String {
        switch register {
        case 1: return "y"
        case 2: return "z"
        case 3: return "t"
        case 4: return "ST"
        default: return "x"
        }
    }

    @ViewBuilder
    private func stackLabel(_ register: Int, width: CGFloat, height: CGFloat, size: CGFloat) -> some View {
        let text = Text(Self.registerLabel(register))
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(usesLed ? Theme.ledCredit : Theme.credit)
            .shadow(color: usesLed ? Theme.ledCredit.opacity(0.48) : .clear, radius: 1.15)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: width, height: height, alignment: .trailing)
        if let onLabelTap {
            ImmediateButton(action: onLabelTap, expands: false) {
                text.accessibilityLabel("flip the stack")
            }
        } else {
            text
        }
    }

    @ViewBuilder
    private func marks(_ register: Int, width: CGFloat, height: CGFloat) -> some View {
        if register == 0 {
            annunciators
                .frame(width: width, height: height)
        } else {
            Color.clear.frame(width: width, height: height)
        }
    }

    private func readout(_ register: Int, cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        let line = calc.readout(for: register)
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                DigitCell(cell: line.cells[index], usesLed: usesLed)
                    .frame(width: cellWidth, height: cellHeight)
            }
        }
    }

    private var annunciators: some View {
        VStack(spacing: 0) {
            sprite(calc.model.recMode ? "sym_rec" : "sym_rec_none")
            sprite(calc.model.fMode ? "sym_f" : "sym_f_none")
            sprite(calc.model.gMode ? "sym_g" : "sym_g_none")
            sprite(calc.model.editing ? "sym_editing" : "sym_editing_none")
        }
    }

    private func sprite(_ name: String) -> some View {
        Image(usesLed ? "led_" + name : name)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

private struct DigitCell: View {
    let cell: LCDCell
    let usesLed: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            ZStack(alignment: .topLeading) {
                usesLed ? Theme.led : Theme.lcd
                Image((usesLed ? "led_" : "") + Self.imageName(cell.glyph))
                    .resizable()
                    .frame(width: width * (35 / 43), height: height)
                if cell.dot || usesLed {
                    Image(usesLed ? (cell.dot ? "led_dot" : "led_dot_none") : "dot")
                        .resizable()
                        .frame(width: width * (10 / 43), height: height * (8 / 53))
                        .position(x: width * (36 / 43), y: height * (49 / 53))
                }
            }
        }
    }

    private static func imageName(_ glyph: LCDCell.Glyph) -> String {
        switch glyph {
        case .blank:
            return "display_none"
        case .minus:
            return "display_neg"
        case .digit(let character):
            return "display\(character)"
        case .letter(let character):
            return "display_\(character)"
        }
    }
}

/// The wiki face mark, drawn as the same dark LCD ink, with the empty cells left visible.
struct FacePortraitView: View {
    var usesLed = false
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .global)
            Canvas { context, size in
                let columns = 100
                let rows = FaceBits.side
                let pixel = 1 / displayScale
                let fit = min(size.width * 0.96 / CGFloat(columns), size.height / CGFloat(rows))
                let pitchInPixels = max(1, (fit * displayScale).rounded(.down))
                let pitch = pitchInPixels * pixel
                let side = max(1, pitchInPixels - 1) * pixel
                // Align to the screen even if the parent starts between physical pixels.
                let centerX = frame.minX + (size.width - pitch * CGFloat(columns)) / 2
                let centerY = frame.minY + (size.height - pitch * CGFloat(rows)) / 2
                let originX = (centerX * displayScale).rounded() * pixel - frame.minX
                let originY = (centerY * displayScale).rounded() * pixel - frame.minY
                let levels = FaceBits.levels
                let palette = usesLed
                    ? [Color(red: 57 / 255, green: 20 / 255, blue: 23 / 255),
                       Color(red: 220 / 255, green: 81 / 255, blue: 74 / 255),
                       Color(red: 112 / 255, green: 35 / 255, blue: 38 / 255)]
                    : [Color(red: 96 / 255, green: 105 / 255, blue: 91 / 255),
                       Color(red: 74 / 255, green: 80 / 255, blue: 69 / 255),
                       Color(red: 40 / 255, green: 40 / 255, blue: 40 / 255)]
                let ink = usesLed ? Theme.ledCredit : Theme.credit
                let lettering = usesLed ? Theme.led : Theme.lcd
                for row in 0..<rows {
                    for column in 0..<columns {
                        let level = column < FaceBits.side ? levels[row * FaceBits.side + column] : 0
                        var color = palette[min(Int(level), 2)]
                        let speechRow = row - 46
                        let speechColumn = column - 57
                        if Self.speech.indices.contains(speechRow),
                           Self.speech[speechRow].indices.contains(speechColumn) {
                            switch Self.speech[speechRow][speechColumn] {
                            case 35: color = ink
                            case 43: color = lettering
                            default: break
                            }
                        }
                        let cell = CGRect(x: originX + CGFloat(column) * pitch,
                                          y: originY + CGFloat(row) * pitch,
                                          width: side, height: side)
                        context.fill(Path(cell), with: .color(color), style: FillStyle(antialiased: false))
                    }
                }
            }
        }
        .accessibilityLabel("Portrait saying Howdy! Close the display")
    }

    // '#' is bubble ink, '+' is lettering, and '.' leaves the portrait visible.
    private static let speech = [
        "...........#########################...",
        ".........#############################.",
        "........###############################",
        "........###+##+###############+######+#",
        "........###+##+###############+######+#",
        "........###+##+##++##+###+##+++#+##+#+#",
        "......#####++++#+##+#+#+#+#+##+#+##+#+#",
        "....#######+##+#+##+#+#+#+#+##+#+##+#+#",
        "###########+##+#+##+#+#+#+#+##+##+++###",
        "...########+##+##++###+#+###+++####+#+#",
        "......##########################+++####",
        "........###############################",
        "........###############################",
        ".........#############################.",
        "...........#########################..."
    ].map { Array($0.utf8) }

}

private enum FaceBits {
    static let side = 80
    /// Two bits per pixel, row-major. 0 is an unlit cell, 1 is the face, 2 is the ink.
    static let packed = "AAAAAAAAAAAAKAAqAAAAAAAAAAAAAAAAAAAAAAKqqqqgAAAAAAAAAAAAAAAAAAAAKqqqqqgAAAAAAAAAAAAAAAAAAAKqqqqqqgAAAAAAAAAAAAAAAAAAqqqqqqqqgAAAAAAAAAAAAAAAACqqqqqqqqogAAAAAAAAAAAAAAACqqqqqqqqqqgAAAAAAAAAAAAAAAqqqqqqqqqqqgAAAAAAAAAAAAAACqqqqqqqqqqqgAAAAAAAAAAAAAAqqqqqqqqqqqqgAAAAAAAAAAAAACqqqqqqqqqqqqgAAAAAAAAAAAAAqqqqqqlZqqqqqgAAAAAAAAAAAACqqqqqVVVaqqqqAAAAAAAAAAAAAKqqqpVVVVVqqqqgAAAAAAAAAAACqqqpVVVVVVaqqqAAAAAAAAAAAAqqqpVVVVVVVWqqqAAAAAAAAAAAKqqqVVVVVVVVWqqqAAAAAAAAAAAqqqpVVVVVVVVWqqgAAAAAAAAAACqqqlVVVVVVVVaqqgAAAAAAAAAAqqqpVVVVVVVVVaqqAAAAAAAAAACqqqVVVVVVVVVVqqoAAAAAAAAAAKqqpVVVVVVVVVVqqgAAAAAAAAAAqqqVVVVVVVVVVWqqAAAAAAAAAACqqpVVVVVVVVVVaqgAAAAAAAAAAKqqpVVVVVVVVVVaqAAAAAAAAAAAKqqlVVVVVVVVVVqoAAAAAAAAAAAqqqVVVVVVVVVVWqAAAAAAAAAAACqqqVVVVVVVVVVaqAAAAAAAAAAACqqlVVVVVVVVVVqoAAAAAAAAAAAKqqlVValVVVVVWqAAAAAAAAAAAAqqqlVqqVVWqVVaoAAAAAAAAAAAKqqWWqqpVVaqqVqgAAAAAAAAAAAKqqmqqqlVVqqqWqAAAAAAAAAAAAqqlqpVWpVaWpqaoAAAAAAAAAAACqqaqlZWlWlZVqqgAAAAAAAAAAAKqlaqqqWlWqqmlqAAAAAAAAAAAAqqVqqqaaVaqqqWoAAAAAAAAAAACqpVqmlVpVVaWlaAAAAAAAAAAAAKqlVqqVWVVWpqVoAAAAAAAAAAACqqVWVVVVVVVVVWgAAAAAAAAAAAKqqVWVVVVVVVVVaAAAAAAAAAAAAqqpVVVVVVVVVVVoAAAAAAAAAAACqqlVVVVVVVVVVWgAAAAAAAAAAACqqVVVVWVVVVVVYAAAAAAAAAAAAKqpVVVVlVVZVVVgAAAAAAAAAAAAmqpVVVWWlVZVVWAAAAAAAAAAAACaqlVVVZqlplVVYAAAAAAAAAAAAAqqVVVVqqqllVVgAAAAAAAAAAAAJqpVVVWqqqVVVWAAAAAAAAAAAAAKqpVVVqqqqWVVYAAAAAAAAAAAAAKqqVVaqqqqmVVgAAAAAAAAAAAAAqqlVmqqVaqpVaAAAAAAAAAAAAACqqlWqqlWqqpWoAAAAAAAAAAAAACqqVaqqqlaqlaAAAAAAAAAAAAAAqqpVqqlVVWpVoAAAAAAAAAAAAAAqqlWqpVVVWVagAAAAAAAAAAAAACqqVWqqqqpVVoAAAAAAAAAAAAAAKqqlVaqqqlZWgAAAAAAAAAAAAAAKqqVWaqWqZlqAAAAAAAAAAAAAAAKqqaZWZWWVqgAAAAAAAAAAAAAACqqqqpqpVqqqAAAAAAAAAAAAACqqqqqqqmqqqqgAAAAAAAAAAAAAKqqqqqqqqqmqoAAAAAAAAAAAAAAKqqqqqqqqmaqgAAAAAAAAAAAAAAKqqqqqqqqqqoAAAAAAAAAAAAAAAKqqqqqqqqqqAAAAAAAAAAAAAAAAKqqqqqqqqqgAAAAAAAAAAAAAAAAKqqqqqqqqqAAAAAAAAAAAAAAAAAKqqqqqqqqoAAAAAAAAAAAAAAAAAKqqqqqqqqAAAAAAAAAAAAAAAAAAKqqqqqqqoAAAAAAAAAAAAAAAAAAKqqqqqqqgAAAAAAAAAAAAAAAAAAKqqqqqZoAAAAAAAAAAAAAAAAAAAKqqqqlZgAAAAAAAAAAAAAAAAAAAKqqqqmaAAAAAAAAAAAAAAAAAAAAKqVqqagAAAAAAAAAAAAAAAAAAAAKlVWqpYAAAAAAAAAAAAAAAAAAAAJVVWVmgAAAAAAAAAAAAAAAAAAAAJVVVVWAAAAAAAAAAAAAAAAAAAAAKVVVVYAAAAAAAAAA=="

    static let levels: [UInt8] = {
        let data = Data(base64Encoded: packed) ?? Data()
        var out = [UInt8](repeating: 0, count: side * side)
        let limit = min(out.count, data.count * 4)
        for index in 0..<limit {
            let byte = data[data.index(data.startIndex, offsetBy: index / 4)]
            let shift = UInt8((3 - (index % 4)) * 2)
            out[index] = (byte >> shift) & 3
        }
        return out
    }()

}
