import RetroRPNEngine
import SwiftUI

struct LCDView: View {
    @ObservedObject var calc: RPNCalculator
    var showsStack: Bool
    /// The expanded face draws the credit beside this view, so the rows can fill what remains.
    var showsCredit: Bool = true
    var drawsChrome: Bool = true

    var body: some View {
        let screen = GeometryReader { geo in
            let creditHeight: CGFloat = showsStack && showsCredit ? max(14, geo.size.height * 0.075) : 0
            let rows = showsStack ? 5 : 1
            let annunciatorWidth: CGFloat = 13
            // The stack labels sit to the left of the digits. The digits give up a little width for them.
            let labelWidth: CGFloat = showsStack ? min(28, max(16, geo.size.width * 0.09)) : 0
            let labelSize = min(13, max(8, labelWidth * 0.46))
            let cellWidth = max(1, (geo.size.width - annunciatorWidth - 6 - labelWidth) / 7)
            let rowArea = max(1, geo.size.height - creditHeight)
            let naturalHeight = cellWidth * (53 / 43)
            let cellHeight = min(naturalHeight, max(1, (rowArea - 4) / CGFloat(rows)))
            VStack(spacing: 0) {
                VStack(spacing: 1) {
                    ForEach(0..<rows, id: \.self) { register in
                        HStack(spacing: 2) {
                            if showsStack {
                                Text(Self.registerLabel(register))
                                    .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.credit)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                    .frame(width: labelWidth, height: cellHeight, alignment: .trailing)
                            }
                            readout(register, cellWidth: cellWidth, cellHeight: cellHeight)
                            if register == 0 {
                                annunciators
                                    .frame(width: annunciatorWidth, height: cellHeight)
                            } else {
                                Color.clear.frame(width: annunciatorWidth, height: cellHeight)
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
            screen
                .padding(.horizontal, 3)
                .padding(.vertical, 2)
                .background(Theme.lcd)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            screen
        }
    }

    /// Marketing version from the watch bundle, so the face stays in step with the build.
    static var creditTitle: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.6"
        return "RetroRPN \(version)"
    }

    /// The Wear stack screen prints the version at the left and the author at the right.
    private func creditLine(width: CGFloat) -> some View {
        let title = Self.creditTitle
        return HStack(spacing: 4) {
            Text(title)
            Spacer(minLength: 4)
            Text("Ashley Nathan Feniello")
        }
        .font(.system(size: max(7, width * 0.042), weight: .medium))
        .foregroundStyle(Theme.credit)
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .padding(.horizontal, 4)
        .padding(.bottom, 3)
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

    private func readout(_ register: Int, cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        let line = calc.readout(for: register)
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                DigitCell(cell: line.cells[index])
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
        Image(name)
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

private struct DigitCell: View {
    let cell: LCDCell

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            ZStack(alignment: .topLeading) {
                Theme.lcd
                Image(Self.imageName(cell.glyph))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: width * (35 / 43), height: height)
                if cell.dot {
                    Image("dot")
                        .interpolation(.none)
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
    var body: some View {
        Canvas { context, size in
            let count = CGFloat(FaceBits.side)
            let pitch = min(size.width, size.height) / count
            let gap = min(pitch * 0.45, max(0.45, pitch * 0.2))
            let side = max(0.4, pitch - gap)
            let originX = (size.width - pitch * count) / 2
            let originY = (size.height - pitch * count) / 2
            let levels = FaceBits.levels
            for index in levels.indices {
                let column = index % FaceBits.side
                let row = index / FaceBits.side
                let rect = CGRect(
                    x: originX + CGFloat(column) * pitch,
                    y: originY + CGFloat(row) * pitch,
                    width: side,
                    height: side
                )
                context.fill(Path(rect), with: .color(FaceBits.color(levels[index])))
            }
        }
        .accessibilityLabel("picture, close the display")
    }
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

    static func color(_ level: UInt8) -> Color {
        switch level {
        case 2:
            return Color(red: 40 / 255, green: 40 / 255, blue: 40 / 255)
        case 1:
            return Color(red: 74 / 255, green: 80 / 255, blue: 69 / 255)
        default:
            return Color(red: 96 / 255, green: 105 / 255, blue: 91 / 255)
        }
    }
}
