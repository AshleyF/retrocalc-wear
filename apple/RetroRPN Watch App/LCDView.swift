import RetroRPNEngine
import SwiftUI

struct LCDView: View {
    @ObservedObject var calc: RPNCalculator
    var showsStack: Bool

    var body: some View {
        GeometryReader { geo in
            let creditHeight: CGFloat = showsStack ? max(14, geo.size.height * 0.075) : 0
            let rows = showsStack ? 4 : 1
            let annunciatorWidth: CGFloat = 13
            let cellWidth = max(1, (geo.size.width - annunciatorWidth - 6) / 7)
            let rowArea = max(1, geo.size.height - creditHeight)
            let naturalHeight = cellWidth * (53 / 43)
            let cellHeight = min(naturalHeight, max(1, (rowArea - 4) / CGFloat(rows)))
            VStack(spacing: 0) {
                VStack(spacing: 1) {
                    ForEach(0..<rows, id: \.self) { register in
                        HStack(spacing: 2) {
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
                if showsStack {
                    creditLine(width: geo.size.width)
                        .frame(height: creditHeight, alignment: .bottom)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .background(Theme.lcd)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    /// The Wear stack screen prints the version at the left and the author at the right.
    private func creditLine(width: CGFloat) -> some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let title: String
        if version.isEmpty {
            title = "RetroRPN"
        } else if build.isEmpty {
            title = "RetroRPN \(version)"
        } else {
            title = "RetroRPN \(version) (\(build))"
        }
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
