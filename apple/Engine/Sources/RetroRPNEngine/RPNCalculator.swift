import Combine
import Foundation

/// Four-level RPN calculator ported from the Android Wear activity.
///
/// Key codes are `column + row * 5`, the same numbering the Wear app records
/// into its programs. The square legend layout is the one drawn on the watch,
/// so program A lives on divide and `1/x` lives on 6.
public final class RPNCalculator: ObservableObject {
    public struct Model: Equatable, Codable {
        public var x: Double = 0
        public var y: Double = 0
        public var z: Double = 0
        public var t: Double = 0
        public var display: String = "0"
        public var editing: Bool = true
        public var fMode: Bool = false
        public var gMode: Bool = false
        public var recMode: Bool = false
        public var fullscreen: Bool = false
        public var stored: Double = 0
        public var programs: [[Int]] = [[], [], [], []]
        public var progNum: Int = 0

        public init() {}
    }

    @Published public private(set) var model: Model
    /// Replaces `Math.random` so tests can pin the value.
    public var randomSource: () -> Double = { Double.random(in: 0..<1) }

    private var state: Model
    private var suppressPublish = false
    private var playDepth = 0
    private var past: [Model] = []
    private var future: [Model] = []
    private let tapeLimit = 400

    public init() {
        let initial = Model()
        model = initial
        state = initial
    }

    public func press(row: Int, column: Int) {
        let publish = !suppressPublish
        let before = state
        if state.recMode {
            state.programs[state.progNum].append(column + row * 5)
        }
        if state.fullscreen || row < 0 {
            state.fullscreen.toggle()
        } else if state.fMode {
            state.fMode = false
            fShift(column + row * 5)
        } else if state.gMode {
            state.gMode = false
            gShift(column + row * 5)
        } else {
            primary(column + row * 5)
        }
        if publish {
            if state.display == "NaN" {
                state.x = 0
            }
            // Showing or hiding the stack does not change the calculation.
            if before != state && !isStackToggle(from: before, to: state) {
                past.append(before)
                if past.count > tapeLimit { past.removeFirst() }
                future.removeAll()
            }
            model = state
        }
    }

    /// One user keystroke back. Playing a program is a single step.
    /// The stack view stays as the user currently has it.
    @discardableResult
    public func undo() -> Bool {
        guard let previous = past.popLast() else { return false }
        future.append(state)
        let viewingStack = state.fullscreen
        state = previous
        state.fullscreen = viewingStack
        model = state
        return true
    }

    /// Puts back the keystroke most recently undone.
    @discardableResult
    public func redo() -> Bool {
        guard let next = future.popLast() else { return false }
        past.append(state)
        let viewingStack = state.fullscreen
        state = next
        state.fullscreen = viewingStack
        model = state
        return true
    }

    /// True when the press only opened or closed the stack view.
    private func isStackToggle(from before: Model, to after: Model) -> Bool {
        var previous = before
        var current = after
        previous.fullscreen = false
        current.fullscreen = false
        return previous == current
    }

    public func pressDisplay() {
        press(row: -1, column: 0)
    }

    public func restore(_ snapshot: Model) {
        state = snapshot
        state.x = parse(state.display)
        past.removeAll()
        future.removeAll()
        model = state
    }

    public func readout(for register: Int) -> LCDReadout {
        switch register {
        case 1:
            return LCDRenderer.render(value: model.y, text: DoubleFormat.displayValue(model.y))
        case 2:
            return LCDRenderer.render(value: model.z, text: DoubleFormat.displayValue(model.z))
        case 3:
            return LCDRenderer.render(value: model.t, text: DoubleFormat.displayValue(model.t))
        default:
            return LCDRenderer.render(value: model.x, text: model.display)
        }
    }

    private func primary(_ key: Int) {
        switch key {
        case 0:
            binOp(state.y / state.x)
        case 1:
            digit("7")
        case 2:
            digit("8")
        case 3:
            digit("9")
        case 4:
            state.fMode = true
        case 5:
            binOp(state.y * state.x)
        case 6:
            digit("4")
        case 7:
            digit("5")
        case 8:
            digit("6")
        case 9:
            state.gMode = true
        case 10:
            binOp(state.y - state.x)
        case 11:
            digit("1")
        case 12:
            digit("2")
        case 13:
            digit("3")
        case 14, 19:
            if !state.editing { push() }
            state.editing = false
        case 15:
            binOp(state.y + state.x)
        case 16:
            digit("0")
        case 17:
            decimalPoint()
        case 18:
            changeSign()
        default:
            break
        }
    }

    private func fShift(_ key: Int) {
        switch key {
        case 0:
            playRecording(0)
        case 1:
            playRecording(1)
        case 2:
            playRecording(2)
        case 3:
            playRecording(3)
        case 4:
            break
        case 5:
            binOp(pow(state.y, state.x))
        case 6:
            unOp(exp(state.x))
        case 7:
            unOp(pow(10, state.x))
        case 8:
            unOp(1 / state.x)
        case 9:
            if state.recMode { stopRecording() }
            else { state.gMode = true }
        case 10:
            constant(randomSource())
        case 11:
            unOp(sin(state.x))
        case 12:
            unOp(cos(state.x))
        case 13:
            unOp(tan(state.x))
        case 14, 19:
            state.x = 0
            updateDisplay()
            state.editing = false
        case 15:
            state.stored = state.x
        case 16:
            constant(exp(1))
        case 17:
            let temp = state.x
            state.x = state.y
            state.y = temp
            updateDisplay()
            state.editing = false
        case 18:
            rotateDown()
            updateDisplay()
            state.editing = false
        default:
            break
        }
    }

    private func gShift(_ key: Int) {
        switch key {
        case 0:
            if state.recMode { stopRecording() }
            else { startRecording(0) }
        case 1:
            if state.recMode { stopRecording() }
            else { startRecording(1) }
        case 2:
            if state.recMode { stopRecording() }
            else { startRecording(2) }
        case 3:
            if state.recMode { stopRecording() }
            else { startRecording(3) }
        case 4:
            state.fMode = true
        case 5:
            binOp(pow(state.y, 1 / state.x))
        case 6:
            unOp(log(state.x))
        case 7:
            unOp(log10(state.x))
        case 8:
            unOp(truncatingToInt32(state.x))
        case 9:
            break
        case 10:
            unOp(abs(state.x))
        case 11:
            unOp(asin(state.x))
        case 12:
            unOp(acos(state.x))
        case 13:
            unOp(atan(state.x))
        case 14, 19:
            delete()
        case 15:
            constant(state.stored)
        case 16:
            constant(Double.pi)
        case 17:
            constant(state.y)
        case 18:
            rotateUp()
            updateDisplay()
            state.editing = false
        default:
            break
        }
    }

    private func startRecording(_ program: Int) {
        finishEntry()
        state.recMode = true
        state.progNum = program
        state.programs[program] = []
    }

    private func stopRecording() {
        if state.programs[state.progNum].count >= 2 {
            state.programs[state.progNum].removeLast(2)
        } else {
            state.programs[state.progNum] = []
        }
        state.recMode = false
    }

    private func playRecording(_ program: Int) {
        guard playDepth < 16 else { return }
        guard !state.recMode || state.progNum != program else { return }
        playDepth += 1
        let wasSuppressed = suppressPublish
        suppressPublish = true
        finishEntry()
        let keys = state.programs[program]
        for key in keys {
            press(row: key / 5, column: key % 5)
        }
        suppressPublish = wasSuppressed
        playDepth -= 1
    }

    /// Operators finish the number in X. Recording and playing do the same,
    /// so a macro can assume X is already entered. ENTER inside a macro still
    /// duplicates, which is how a square is "enter, multiply."
    private func finishEntry() {
        state.editing = false
    }

    private func digit(_ character: Character) {
        if !state.editing {
            push()
            state.display = ""
            state.editing = true
        }
        if state.display == "0" { state.display = "" }
        if state.display == "-0" { state.display = "-" }
        if displayLength() < 7 {
            state.display.append(character)
            updateValue()
        }
    }

    private func decimalPoint() {
        if !state.editing {
            push()
            state.x = 0
            updateDisplay()
            state.editing = true
        }
        if !state.display.contains(".") {
            state.display.append(".")
            updateValue()
        }
    }

    private func changeSign() {
        guard let first = state.display.first else { return }
        if first == "-" {
            state.display = String(state.display.dropFirst())
        } else {
            state.display = "-" + state.display
        }
        updateValue()
    }

    private func delete() {
        guard state.display != "0", state.display != "-0" else { return }
        if state.display.count > 1 {
            state.display.removeLast()
        } else {
            state.display = "0"
        }
        updateValue()
    }

    private func push() {
        state.t = state.z
        state.z = state.y
        state.y = state.x
    }

    private func pop() {
        state.x = state.y
        state.y = state.z
        state.z = state.t
    }

    private func unOp(_ value: Double) {
        state.x = value
        state.editing = false
        updateDisplay()
    }

    private func binOp(_ value: Double) {
        pop()
        unOp(value)
    }

    private func constant(_ value: Double) {
        push()
        state.x = value
        state.editing = false
        updateDisplay()
    }

    private func rotateDown() {
        let temp = state.t
        state.t = state.z
        state.z = state.y
        state.y = state.x
        state.x = temp
    }

    private func rotateUp() {
        let temp = state.x
        state.x = state.y
        state.y = state.z
        state.z = state.t
        state.t = temp
    }

    private func displayLength() -> Int {
        state.display.reduce(0) { count, character in
            count + (character == "." ? 0 : 1)
        }
    }

    private func updateDisplay() {
        state.display = DoubleFormat.displayValue(state.x)
    }

    private func updateValue() {
        state.x = parse(state.display)
    }

    private func parse(_ text: String) -> Double {
        switch text {
        case "", "-", ".", "-.":
            return 0
        case "NaN":
            return .nan
        case "Infinity":
            return .infinity
        case "-Infinity":
            return -.infinity
        default:
            return Double(text) ?? 0
        }
    }

    private func truncatingToInt32(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        if value >= Double(Int32.max) { return Double(Int32.max) }
        if value <= Double(Int32.min) { return Double(Int32.min) }
        return Double(Int32(value))
    }
}
