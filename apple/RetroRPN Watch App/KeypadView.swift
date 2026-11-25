import RetroRPNEngine
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

    /// X on top points the roll arrows the other way. The keys themselves stay put.
    func matchingRoll(xOnTop: Bool) -> KeySpec {
        guard code == 18, xOnTop else { return self }
        return KeySpec(code: code, title: title, fLabel: "R↑", gLabel: "R↓", role: role, tight: tight, legendAnchor: legendAnchor)
    }

    var accessibilityText: String {
        switch code {
        case 14: return "enter, f clear x, g delete"
        case 15: return "plus, f store, g recall"
        default:
            break
        }
        switch role {
        case .f: return "f, play, iterate"
        case .g: return "g, record, stop"
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
        KeySpec(code: 10, title: "−", fLabel: "ran", gLabel: "|x|", role: .normal, tight: false),
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
    var flashedCode: Int?
    var xOnTop: Bool = false
    var leftHanded = false
    let screenSize: CGSize
    var onEnterDown: () -> Void
    var onKey: (Int) -> Void

    @GestureState private var touching = false
    @State private var pressedCode: Int?
    @State private var holdTask: Task<Void, Never>?
    @State private var didHold = false

    var body: some View {
        GeometryReader { geo in
            let grid = KeypadGrid(size: geo.size)
            let origin = geo.frame(in: .named("watchFace")).origin
            let rows = keyRows
            ZStack(alignment: .topLeading) {
                ForEach(0..<4, id: \.self) { row in
                    ForEach(0..<5, id: \.self) { column in
                        let spec = rows[row][column]
                        if spec.code != 14 || row == 2 {
                            let frame = grid.frame(row: row, column: column, tall: spec.code == 14)
                            key(spec, frame: frame, origin: origin)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(touchGesture(grid: grid, rows: rows))
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: touching) { _, active in
            if !active {
                // A cancelled gesture has no onEnded callback. Let a normal
                // end handle Enter first, then clear any abandoned press.
                Task { @MainActor in
                    await Task.yield()
                    if !touching { resetPress() }
                }
            }
        }
        .onDisappear { resetPress() }
    }

    private var keyRows: [[KeySpec]] {
        let rows: [[KeySpec]]
        if leftHanded {
            rows = [
                [Keypad.top[4]] + Keypad.top[1...3] + [Keypad.top[0]],
                [Keypad.second[4]] + Keypad.second[1...3] + [Keypad.second[0]],
                [Keypad.enter] + Keypad.third.dropFirst() + [Keypad.third[0]],
                [Keypad.enter] + Keypad.fourth.dropFirst() + [Keypad.fourth[0]],
            ]
        } else {
            rows = [Keypad.top, Keypad.second, Keypad.third + [Keypad.enter], Keypad.fourth + [Keypad.enter]]
        }
        return rows.map { $0.map(oriented) }
    }

    private func oriented(_ spec: KeySpec) -> KeySpec {
        var shown = spec.matchingRoll(xOnTop: xOnTop)
        if leftHanded {
            switch shown.legendAnchor {
            case .leading: shown.legendAnchor = .trailing
            case .trailing: shown.legendAnchor = .leading
            case .center: break
            }
        }
        return shown
    }

    @ViewBuilder
    private func key(_ spec: KeySpec, frame: CGRect, origin: CGPoint) -> some View {
        let appearance = CalcKey(spec: spec, down: spec.code == pressedCode || spec.code == flashedCode)
            .frame(width: frame.width, height: frame.height)
        let screenFrame = frame.offsetBy(dx: origin.x, dy: origin.y)
        let clearance = ScreenCornerClearance(screen: screenSize, key: screenFrame)
        Group {
            if spec.legendAnchor == .center { appearance }
            else { appearance.clipShape(clearance) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spec.accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            if spec.code == 14 { onEnterDown() }
            onKey(spec.code)
        }
        .accessibilityActions {
            if spec.code == 14 {
                Button("Enter exponent") {
                    onEnterDown()
                    onKey(RPNCalculator.exponentKey)
                }
            }
        }
        .position(x: frame.midX, y: frame.midY)
    }

    private func touchGesture(grid: KeypadGrid, rows: [[KeySpec]]) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($touching) { _, active, _ in active = true }
            .onChanged { value in
                if pressedCode == 14 && hypot(value.translation.width, value.translation.height) > 14 {
                    holdTask?.cancel()
                    holdTask = nil
                }
                guard pressedCode == nil, let cell = grid.cell(at: value.startLocation) else { return }
                let code = rows[cell.row][cell.column].code
                pressedCode = code
                if code == 14 {
                    onEnterDown()
                    holdTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(450))
                        guard !Task.isCancelled, pressedCode == 14 else { return }
                        didHold = true
                        onKey(RPNCalculator.exponentKey)
                    }
                } else {
                    onKey(code)
                }
            }
            .onEnded { _ in
                if pressedCode == 14 && holdTask != nil && !didHold { onKey(14) }
                resetPress()
            }
    }

    private func resetPress() {
        holdTask?.cancel()
        holdTask = nil
        pressedCode = nil
        didHold = false
    }
}

/// Drawing and touch routing share these dimensions. A gap is split between
/// its two neighbors, and the two cells occupied by Enter resolve to one key.
private struct KeypadGrid {
    let size: CGSize

    var gap: CGFloat { max(2, size.width * 0.012) }
    var keyWidth: CGFloat { (size.width - 4 * gap) / 5 }
    var rowHeight: CGFloat { (size.height - 3 * gap) / 4 }

    func frame(row: Int, column: Int, tall: Bool = false) -> CGRect {
        CGRect(x: CGFloat(column) * (keyWidth + gap), y: CGFloat(row) * (rowHeight + gap),
               width: keyWidth, height: tall ? 2 * rowHeight + gap : rowHeight)
    }

    func cell(at point: CGPoint) -> (row: Int, column: Int)? {
        guard keyWidth > 0, rowHeight > 0, CGRect(origin: .zero, size: size).contains(point) else { return nil }
        let row = min(3, Int((point.y + gap / 2) / (rowHeight + gap)))
        let column = min(4, Int((point.x + gap / 2) / (keyWidth + gap)))
        return (row, column)
    }
}

/// Leaves a small inset from the rounded bottom of the physical display.
private struct ScreenCornerClearance: Shape {
    let screen: CGSize
    let key: CGRect

    func path(in rect: CGRect) -> Path {
        let gap: CGFloat = 2
        // The point widths distinguish the different corner curves measured
        // from the simulator masks. Use the deeper Ultra curve for other sizes.
        let profile: (width: CGFloat, height: CGFloat, curve: CGFloat)
        switch Int(screen.width.rounded()) {
        case 162: profile = (0.23, 0.18, 2.7)
        case 184: profile = (0.23, 0.18, 2.5)
        case 187: profile = (0.30, 0.24, 2.5)
        case 208: profile = (0.29, 0.24, 2.4)
        default: profile = (0.36, 0.30, 2.8)
        }
        let cornerWidth = screen.width * profile.width
        let cornerHeight = screen.height * profile.height
        let curve = profile.curve

        func inset(at y: CGFloat) -> CGFloat {
            let depth = key.minY + y - (screen.height - gap - cornerHeight)
            let t = min(1, max(0, depth / cornerHeight))
            return gap + cornerWidth * (1 - pow(1 - pow(t, curve), 1 / curve))
        }

        // Sample both sides of the same contour so handedness needs no special cases.
        let samples = 32
        let rows = (0...samples).map { rect.height * CGFloat($0) / CGFloat(samples) }
        let left = rows.map { y in
            CGPoint(x: max(0, inset(at: y) - key.minX), y: y)
        }
        let right = rows.reversed().map { y in
            CGPoint(x: min(rect.width, screen.width - inset(at: y) - key.minX), y: y)
        }
        var outline = Path()
        outline.addLines(left + right)
        outline.closeSubpath()
        return outline
    }
}

private struct CalcKey: View {
    let spec: KeySpec
    let down: Bool

    var body: some View {
        face
            .overlay { KeyDepression(down: down) }
            .visualEffect { content, _ in
                content
                    .scaleEffect(down ? 0.95 : 1, anchor: .center)
                    .offset(y: down ? 1.6 : 0)
            }
            .animation(.easeOut(duration: 0.08), value: down)
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
            skinny: inward,
            squeeze: spec.code == 17 ? 0.92 : 1
        )
        .frame(height: shiftSize * 1.15)
        // Lift the two corner legends and keep their ink near the inside edge.
        let bottom = width * (inward ? 0.11 : 0.05)
        let edge = width * 0.045
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
                .overlay {
                    Text("EEX")
                        .font(.system(size: width * 0.16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.52))
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                        .offset(x: -width * 0.27)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 0)
                legend
                    .padding(.leading, spec.legendAnchor == .leading ? edge : 0)
                    .padding(.trailing, spec.legendAnchor == .trailing ? edge : 0)
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
                    // g's descender drops its ink below f. Lift it so the two letters occupy the same band.
                    .offset(y: spec.role == .g ? -height * titleScale * 0.25 : 0)
                Spacer(minLength: 0)
                legend
                    .padding(.leading, spec.legendAnchor == .leading ? edge : 0)
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
    /// Pulls a wide pair in from the key edges without shortening the letters.
    var squeeze: CGFloat = 1

    @State private var naturalWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let available = max(geo.size.width, 1)
            let fit = naturalWidth > 1 ? min(1, available / naturalWidth) : 1
            let scale = fit * (skinny ? 0.82 : 1) * squeeze
            marks
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

    @ViewBuilder
    private var marks: some View {
        if fLabel == "▶" {
            MacroCues(kind: .play, size: size)
        } else if fLabel == "●" {
            MacroCues(kind: .record, size: size)
        } else {
            HStack(spacing: tight ? 0 : 2) {
                if !fLabel.isEmpty {
                    Text(fLabel)
                        .foregroundStyle(fColor)
                }
                if !gLabel.isEmpty {
                    Text(gLabel)
                        .foregroundStyle(gColor)
                }
            }
        }
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

/// The f key's play triangle plus an iterate mark, or the g key's record dot plus stop square.
private struct MacroCues: View {
    enum Kind { case play, record }
    var kind: Kind
    var size: CGFloat

    var body: some View {
        let mark = size * 0.663
        HStack(spacing: mark * 0.28) {
            switch kind {
            case .play:
                PlayTriangle()
                    .fill(Theme.program)
                    .frame(width: mark * 0.86, height: mark)
                IterateMark()
                    .fill(Theme.gShadow)
                    .frame(width: mark * 1.06, height: mark)
            case .record:
                Circle()
                    .fill(Theme.program)
                    .frame(width: mark, height: mark)
                Rectangle()
                    .fill(Theme.fShadow)
                    .frame(width: mark, height: mark)
            }
        }
        .offset(y: -size * 0.08)
    }
}

private struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Two play marks, the "do it again" cue for g then f then a letter.
private struct IterateMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let gap = rect.width * 0.16
        let width = (rect.width - gap) / 2
        triangle(in: &path, from: rect.minX, width: width, rect: rect)
        triangle(in: &path, from: rect.minX + width + gap, width: width, rect: rect)
        return path
    }

    private func triangle(in path: inout Path, from x: CGFloat, width: CGFloat, rect: CGRect) {
        path.move(to: CGPoint(x: x, y: rect.minY))
        path.addLine(to: CGPoint(x: x + width, y: rect.midY))
        path.addLine(to: CGPoint(x: x, y: rect.maxY))
        path.closeSubpath()
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
    /// Stack labels and the name keep their own width.
    var expands: Bool = true
    @ViewBuilder var label: () -> Label
    @State private var gate = PressGate()

    var body: some View {
        Button(action: { gate.pressUp(action) }) {
            label()
                .frame(maxWidth: expands ? .infinity : nil, maxHeight: .infinity)
        }
        .buttonStyle(ImmediatePressStyle(onPress: { gate.pressDown(action) }))
        .focusable(false)
        .buttonBorderShape(.roundedRectangle)
    }
}

private struct ImmediatePressStyle: ButtonStyle {
    var onPress: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { onPress() }
            }
    }
}

/// A pushed key loses its top highlight and picks up a soft pool of light.
/// The light is clipped to the key face, so it reads as the plastic, not a badge.
private struct KeyDepression: View {
    var down: Bool

    var body: some View {
        GeometryReader { geo in
            let shape = RoundedRectangle(
                cornerRadius: min(geo.size.width, geo.size.height) * 0.18,
                style: .continuous
            )
            if down {
                ZStack {
                    shape.fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.55), Color.black.opacity(0.16), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.multiply)
                    shape.fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1, green: 0.93, blue: 0.78).opacity(0.42),
                                Color(red: 1, green: 0.86, blue: 0.62).opacity(0.12),
                                Color.clear,
                            ],
                            center: UnitPoint(x: 0.5, y: 0.46),
                            startRadius: 0,
                            endRadius: min(geo.size.width, geo.size.height) * 0.75
                        )
                    )
                    .blendMode(.plusLighter)
                }
                .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(false)
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
