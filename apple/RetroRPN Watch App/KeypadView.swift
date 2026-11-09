import SwiftUI

struct KeySpec: Identifiable {
    enum Role {
        case normal
        case f
        case g
        case enter
    }

    let code: Int
    let title: String
    let fLabel: String
    let gLabel: String
    let role: Role
    /// Trig labels sit together, as `sin` plus a blue inverse.
    let tight: Bool
    var id: Int { code }

    /// Where the orange and blue legends sit. The corner keys pull inward so the curve does not eat them.
    enum LegendAnchor {
        case center
        case leading
        case trailing
    }

    var legendAnchor: LegendAnchor = .center

    var accessibilityText: String {
        switch code {
        case 14: return "enter, f clear x, g delete"
        case 15: return "plus, f store, g recall"
        default:
            break
        }
        switch role {
        case .f: return "f"
        case .g: return "g"
        case .enter: return "enter"
        case .normal:
            var parts = [title]
            if !fLabel.isEmpty { parts.append("f \(fLabel)") }
            if !gLabel.isEmpty { parts.append("g \(gLabel)") }
            return parts.joined(separator: ", ")
        }
    }
}

enum Keypad {
    static let top = [
        KeySpec(code: 0, title: "÷", fLabel: "a", gLabel: "", role: .normal, tight: false),
        KeySpec(code: 1, title: "7", fLabel: "b", gLabel: "", role: .normal, tight: false),
        KeySpec(code: 2, title: "8", fLabel: "c", gLabel: "", role: .normal, tight: false),
        KeySpec(code: 3, title: "9", fLabel: "d", gLabel: "", role: .normal, tight: false),
        KeySpec(code: 4, title: "f", fLabel: "▶", gLabel: "", role: .f, tight: false),
    ]
    static let second = [
        KeySpec(code: 5, title: "×", fLabel: "yˣ", gLabel: "ˣ√y", role: .normal, tight: false),
        KeySpec(code: 6, title: "4", fLabel: "eˣ", gLabel: "ln", role: .normal, tight: false),
        KeySpec(code: 7, title: "5", fLabel: "10ˣ", gLabel: "log", role: .normal, tight: false),
        KeySpec(code: 8, title: "6", fLabel: "1/x", gLabel: "int", role: .normal, tight: false),
        KeySpec(code: 9, title: "g", fLabel: "●", gLabel: "", role: .g, tight: false),
    ]
    static let third = [
        KeySpec(code: 10, title: "−", fLabel: "ran", gLabel: "abs", role: .normal, tight: false),
        KeySpec(code: 11, title: "1", fLabel: "sin", gLabel: "⁻¹", role: .normal, tight: true),
        KeySpec(code: 12, title: "2", fLabel: "cos", gLabel: "⁻¹", role: .normal, tight: true),
        KeySpec(code: 13, title: "3", fLabel: "tan", gLabel: "⁻¹", role: .normal, tight: true),
    ]
    static let fourth = [
        KeySpec(code: 15, title: "+", fLabel: "ST", gLabel: "RC", role: .normal, tight: false, legendAnchor: .trailing),
        KeySpec(code: 16, title: "0", fLabel: "e", gLabel: "π", role: .normal, tight: false),
        KeySpec(code: 17, title: "·", fLabel: "x↔y", gLabel: "over", role: .normal, tight: false),
        KeySpec(code: 18, title: "+/−", fLabel: "R↓", gLabel: "R↑", role: .normal, tight: false),
    ]
    static let enter = KeySpec(code: 14, title: "ENTER", fLabel: "Cx", gLabel: "⌫", role: .enter, tight: false, legendAnchor: .leading)
}

struct KeypadView: View {
    var onKey: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let gap = max(2, geo.size.width * 0.012)
            let keyWidth = (geo.size.width - gap * 4) / 5
            let rowHeight = (geo.size.height - gap * 3) / 4
            VStack(spacing: gap) {
                row(Keypad.top, width: keyWidth, height: rowHeight, gap: gap)
                row(Keypad.second, width: keyWidth, height: rowHeight, gap: gap)
                HStack(spacing: gap) {
                    VStack(spacing: gap) {
                        row(Keypad.third, width: keyWidth, height: rowHeight, gap: gap)
                        row(Keypad.fourth, width: keyWidth, height: rowHeight, gap: gap)
                    }
                    CalcKey(spec: Keypad.enter, action: { onKey(14) })
                        .frame(width: keyWidth)
                }
            }
        }
    }

    private func row(_ keys: [KeySpec], width: CGFloat, height: CGFloat, gap: CGFloat) -> some View {
        HStack(spacing: gap) {
            ForEach(keys) { spec in
                CalcKey(spec: spec, action: { onKey(spec.code) })
                    .frame(width: width, height: height)
            }
        }
        .frame(height: height)
    }
}

private struct CalcKey: View {
    let spec: KeySpec
    let action: () -> Void

    var body: some View {
        ImmediateButton(action: action) {
            face
        }
        .accessibilityLabel(spec.accessibilityText)
    }

    private var face: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            let shape = RoundedRectangle(cornerRadius: min(width, height) * 0.18, style: .continuous)
            ZStack {
                shape
                    .fill(bevel(width: width, height: height))
                    .overlay(shape.stroke(Color.black.opacity(0.45), lineWidth: 0.5))
                labels(width: width, height: height)
                    .padding(.horizontal, 1)
            }
        }
    }

    /// Flat top face, then a darker lower band the height of one key's legend.
    /// The tall ENTER key keeps that band at the label, instead of scaling it up.
    private func bevel(width: CGFloat, height: CGFloat) -> LinearGradient {
        let lip: Color
        let face: Color
        let skirt: Color
        switch spec.role {
        case .f:
            lip = Theme.fKeyLip
            face = Theme.fKeyFace
            skirt = Theme.fKeySkirt
        case .g:
            lip = Theme.gKeyLip
            face = Theme.gKeyFace
            skirt = Theme.gKeySkirt
        case .normal, .enter:
            lip = Theme.keyLip
            face = Theme.keyFace
            skirt = Theme.keySkirt
        }
        let skirtBand = width * 0.28
        let blend = width * 0.12
        let skirtStart = min(0.94, max(0.5, (height - skirtBand) / height))
        let faceEnd = min(skirtStart - 0.02, max(0.35, (height - skirtBand - blend) / height))
        let lipEnd = min(faceEnd - 0.02, max(0.04, 2.5 / height))
        return LinearGradient(
            stops: [
                .init(color: lip, location: 0),
                .init(color: face, location: lipEnd),
                .init(color: face, location: faceEnd),
                .init(color: skirt, location: skirtStart),
                .init(color: skirt, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private func labels(width: CGFloat, height: CGFloat) -> some View {
        let inward = spec.legendAnchor != .center
        let shiftSize = width * (inward ? 0.22 : 0.26)
        let legend = ShiftLabels(
            fLabel: spec.fLabel,
            gLabel: spec.gLabel,
            fColor: spec.role == .enter ? Theme.fLabel : fColor,
            gColor: Theme.gLabel,
            size: shiftSize,
            tight: spec.tight,
            anchor: spec.legendAnchor,
            skinny: inward
        )
        .frame(height: shiftSize * 1.15)
        // Same bottom inset as every other legend, so the corner words sit on that line.
        // A few points in from the key edge keeps the ink on the flat face.
        let bottom = width * 0.05
        let edge = width * 0.1
        if spec.role == .enter {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: -1) {
                    ForEach(Array("ENTER".enumerated()), id: \.offset) { _, character in
                        Text(String(character))
                            .font(.system(size: width * 0.28, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.label)
                    }
                }
                Spacer(minLength: 0)
                legend
                    .padding(.leading, edge)
                    .padding(.bottom, bottom)
            }
        } else {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(spec.title)
                    .font(.system(size: height * titleScale, weight: .medium, design: .rounded))
                    .foregroundStyle(spec.role == .normal ? Theme.label : Theme.legend)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Spacer(minLength: 0)
                legend
                    .padding(.trailing, spec.legendAnchor == .trailing ? edge : 0)
                    .padding(.bottom, bottom)
            }
        }
    }

    /// Digits, the four operators, and f/g. Plus/minus stays put so the pair still fits the key.
    private var titleScale: CGFloat {
        if spec.code == 18 { return 0.42 }
        return spec.role == .normal ? 0.52 : 0.58
    }

    private var fColor: Color {
        if spec.role == .f || spec.role == .g { return Theme.program }
        if spec.gLabel.isEmpty { return Theme.program }
        return Theme.fLabel
    }
}

/// Bottom legend. Wide pairs squeeze sideways so the letters stay tall.
/// Corner keys use a narrower face and sit on the inner edge, clear of the bezel curve.
private struct ShiftLabels: View {
    let fLabel: String
    let gLabel: String
    let fColor: Color
    let gColor: Color
    let size: CGFloat
    let tight: Bool
    var anchor: KeySpec.LegendAnchor = .center
    var skinny: Bool = false

    @State private var naturalWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let available = max(geo.size.width, 1)
            let fit = naturalWidth > 1 ? min(1, available / naturalWidth) : 1
            let scale = fit * (skinny ? 0.82 : 1)
            HStack(spacing: tight ? 0 : 2) {
                if !fLabel.isEmpty {
                    Text(fLabel)
                        .foregroundStyle(fColor)
                        .scaleEffect(fLabel == "●" ? 0.72 : 1)
                }
                if !gLabel.isEmpty {
                    Text(gLabel)
                        .foregroundStyle(gColor)
                }
            }
            .font(.system(size: size, weight: .bold, design: .rounded))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: NaturalWidthKey.self, value: proxy.size.width)
                }
            }
            .scaleEffect(x: scale, y: 1, anchor: scaleAnchor)
            .frame(width: geo.size.width, height: geo.size.height, alignment: frameAlignment)
        }
        .onPreferenceChange(NaturalWidthKey.self) { naturalWidth = $0 }
    }

    private var frameAlignment: Alignment {
        switch anchor {
        case .center: return .bottom
        case .leading: return .bottomLeading
        case .trailing: return .bottomTrailing
        }
    }

    private var scaleAnchor: UnitPoint {
        switch anchor {
        case .center: return .bottom
        case .leading: return .bottomLeading
        case .trailing: return .bottomTrailing
        }
    }
}

private struct NaturalWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Fires when the finger lands. A normal button action waits for the finger to
/// lift, and the watch also pauses to see if the touch is a scroll.
/// Not focusable, so the crown stays on the calculator instead of moving between keys.
struct ImmediateButton<Label: View>: View {
    var action: () -> Void
    @ViewBuilder var label: () -> Label
    @State private var gate = PressGate()

    var body: some View {
        Button(action: { gate.pressUp(action) }) {
            label()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(ImmediatePressStyle(action: action, gate: gate))
        .focusable(false)
        .buttonBorderShape(.roundedRectangle)
    }
}

private struct ImmediatePressStyle: ButtonStyle {
    var action: () -> Void
    var gate: PressGate

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { gate.pressDown(action) }
            }
    }
}

private final class PressGate {
    private var lastFire = Date.distantPast
    /// Downs that already counted. Each one consumes its matching release,
    /// however long the finger stayed down. VoiceOver has no down, so its
    /// release still counts.
    private var pendingReleases = 0

    func pressDown(_ action: () -> Void) {
        if fire(action) {
            pendingReleases += 1
        }
    }

    /// Finger-up, or VoiceOver with no press. A flickery touch reports both,
    /// and sometimes reports the down twice. One contact counts once.
    func pressUp(_ action: () -> Void) {
        if pendingReleases > 0 {
            pendingReleases -= 1
            return
        }
        fire(action)
    }

    @discardableResult
    private func fire(_ action: () -> Void) -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastFire) > 0.08 else { return false }
        lastFire = now
        action()
        return true
    }
}

extension Keypad {
    /// Which key contains a point in the keypad's own coordinates.
    static func code(at local: CGPoint, size: CGSize) -> Int? {
        let gap = max(2, size.width * 0.012)
        let keyWidth = (size.width - gap * 4) / 5
        let rowHeight = (size.height - gap * 3) / 4
        let strideX = keyWidth + gap
        let strideY = rowHeight + gap
        guard local.x >= 0, local.y >= 0, local.x < size.width, local.y < size.height else { return nil }
        let column = min(4, Int(local.x / strideX))
        let row = min(3, Int(local.y / strideY))
        let codes = [
            [0, 1, 2, 3, 4],
            [5, 6, 7, 8, 9],
            [10, 11, 12, 13, 14],
            [15, 16, 17, 18, 14],
        ]
        return codes[row][column]
    }
}
