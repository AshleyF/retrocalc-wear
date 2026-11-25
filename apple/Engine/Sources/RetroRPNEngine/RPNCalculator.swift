import Combine
import Foundation

/// Four-level RPN calculator ported from the Android Wear activity.
///
/// Key codes are `column + row * 5`, the same numbering the Wear app records
/// into its programs. The square legend layout is the one drawn on the watch,
/// so program A lives on divide and `1/x` lives on 6.
public final class RPNCalculator: ObservableObject {
    public static let exponentKey = 20

    public struct Model: Equatable, Codable {
        public var x: Double = 0
        public var y: Double = 0
        public var z: Double = 0
        public var t: Double = 0
        public var display: String = "0"
        public var editing: Bool = true
        var hasTypedMantissa = false
        public var fMode: Bool = false
        public var gMode: Bool = false
        public var recMode: Bool = false
        public var fullscreen: Bool = false
        public var stored: Double = 0
        public var programs: [[Int]] = [[], [], [], []]
        /// A, B, C, and D, beside the four programs.
        public var values: [Double] = [0, 0, 0, 0]
        /// G F ST is waiting for a letter. Any other key stores into ST instead.
        public var letterStore: Bool = false
        /// F G RC is waiting for a letter. Any other key cancels the recall.
        public var letterRecall: Bool = false
        /// The next number raises the stack. ENTER, clear X, and store turn this
        /// off, so that number replaces X. X and Y already hold their values.
        public var lift: Bool = true
        public var progNum: Int = 0

        public init() {}

        private enum CodingKeys: String, CodingKey {
            case x, y, z, t, display, editing, fMode, gMode, recMode, fullscreen
            case stored, programs, progNum, values, letterStore, letterRecall, lift, hasTypedMantissa
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            x = try container.decode(Double.self, forKey: .x)
            y = try container.decode(Double.self, forKey: .y)
            z = try container.decode(Double.self, forKey: .z)
            t = try container.decode(Double.self, forKey: .t)
            display = try container.decode(String.self, forKey: .display)
            editing = try container.decode(Bool.self, forKey: .editing)
            hasTypedMantissa = try container.decodeIfPresent(Bool.self, forKey: .hasTypedMantissa) ?? (display != "0")
            fMode = try container.decode(Bool.self, forKey: .fMode)
            gMode = try container.decode(Bool.self, forKey: .gMode)
            recMode = try container.decode(Bool.self, forKey: .recMode)
            fullscreen = try container.decode(Bool.self, forKey: .fullscreen)
            stored = try container.decode(Double.self, forKey: .stored)
            programs = try container.decode([[Int]].self, forKey: .programs)
            progNum = try container.decode(Int.self, forKey: .progNum)
            let decoded = try container.decodeIfPresent([Double].self, forKey: .values) ?? [0, 0, 0, 0]
            values = decoded.count == 4 ? decoded : [0, 0, 0, 0]
            letterStore = try container.decodeIfPresent(Bool.self, forKey: .letterStore) ?? false
            letterRecall = try container.decodeIfPresent(Bool.self, forKey: .letterRecall) ?? false
            lift = try container.decodeIfPresent(Bool.self, forKey: .lift) ?? true
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
            try container.encode(z, forKey: .z)
            try container.encode(t, forKey: .t)
            try container.encode(display, forKey: .display)
            try container.encode(editing, forKey: .editing)
            try container.encode(hasTypedMantissa, forKey: .hasTypedMantissa)
            try container.encode(fMode, forKey: .fMode)
            try container.encode(gMode, forKey: .gMode)
            try container.encode(recMode, forKey: .recMode)
            try container.encode(fullscreen, forKey: .fullscreen)
            try container.encode(stored, forKey: .stored)
            try container.encode(programs, forKey: .programs)
            try container.encode(progNum, forKey: .progNum)
            try container.encode(values, forKey: .values)
            try container.encode(letterStore, forKey: .letterStore)
            try container.encode(letterRecall, forKey: .letterRecall)
            try container.encode(lift, forKey: .lift)
        }
    }

    @Published public private(set) var model: Model
    /// Replaces `Math.random` so tests can pin the value.
    public var randomSource: () -> Double = { Double.random(in: 0..<1) }

    private var state: Model
    private var suppressPublish = false
    private var playDepth = 0
    private var past: [Model] = []
    private var future: [Model] = []
    /// Key code for each snapshot in `past` and `future`, so undo can show that key.
    private var pastKeys: [Int] = []
    private var futureKeys: [Int] = []
    private let tapeLimit = 400
    /// What this macro held before the current recording started. Playing it
    /// while recording splices that in, so a macro can be rebuilt around its old steps.
    private var previousRecording: [Int] = []
    /// The key undone or redone by the latest crown step. Nil when that step was not a key.
    public private(set) var replayedKey: Int?
    /// G then F arms the next program letter to run that many times. Tests can turn yielding off.
    public var yieldsRepeats = true
    private var repeatArmed = false
    private var repeatGeneration = 0

    public init() {
        let initial = Model()
        model = initial
        state = initial
    }

    public func press(row: Int, column: Int) {
        if row >= 0 { cancelRepeat() }
        applyKey(row: row, column: column)
    }

    private func applyKey(row: Int, column: Int) {
        let publish = !suppressPublish
        // Opening the stack is not a key. A running macro keeps going so the
        // stack can be watched. A real key, even one that only closes the
        // stack, still stops it.
        // A display tap opens the stack even while a macro is mid-play.
        // Keys of that macro must still run, so only a real key closes it.
        let stackGesture = row < 0 || (playDepth == 0 && state.fullscreen && row >= 0)
        let armed = repeatArmed
        repeatArmed = false
        let before = state
        let requested = column + row * 5
        let code = requested == Self.exponentKey && (state.fMode || state.gMode) ? 14 : requested
        // A macro played while recording is stored as the call. Its own keys
        // run with playDepth > 0 and must not be copied into the new macro.
        // Opening the stack is not a key, so it must not be stored either.
        if state.recMode && playDepth == 0 && row >= 0 {
            state.programs[state.progNum].append(code)
        }
        if stackGesture {
            state.fullscreen.toggle()
        } else if state.letterStore || state.letterRecall {
            finishLetter(code)
        } else if state.fMode && state.gMode {
            if armed { fChord(code) }
            else { gChord(code) }
        } else if state.fMode {
            let keep = code == 9 && !state.recMode
            state.fMode = false
            if armed && (0...3).contains(code) {
                repeatProgram(code)
            } else {
                fShift(code)
            }
            if keep { state.fMode = true }
        } else if state.gMode {
            let keep = code == 4
            state.gMode = false
            gShift(code)
            if keep { state.gMode = true }
        } else {
            primary(code)
        }
        if publish {
            if state.display == "NaN" {
                state.x = 0
            }
            // Showing or hiding the stack does not change the calculation.
            if before != state && !isStackToggle(from: before, to: state) {
                past.append(before)
                pastKeys.append(code)
                if past.count > tapeLimit {
                    past.removeFirst()
                    pastKeys.removeFirst()
                }
                future.removeAll()
                futureKeys.removeAll()
            }
            model = state
        } else if row < 0 {
            model = state
        }
    }

    private func cancelRepeat() {
        repeatGeneration += 1
        while let frame = playFrames.popLast() {
            if frame.insertingPrevious {
                state.recMode = frame.wasRecording
            }
            suppressPublish = frame.wasSuppressed
            playDepth = max(0, playDepth - 1)
        }
        suspendPlayback = false
    }

    /// One user keystroke back. Playing a program is a single step.
    /// The stack view stays as the user currently has it.
    @discardableResult
    public func undo() -> Bool {
        cancelRepeat()
        guard let previous = past.popLast() else { return false }
        let key = pastKeys.popLast()
        future.append(state)
        if let key { futureKeys.append(key) }
        let viewingStack = state.fullscreen
        state = previous
        state.fullscreen = viewingStack
        model = state
        replayedKey = key
        return true
    }

    /// Puts back the keystroke most recently undone.
    @discardableResult
    public func redo() -> Bool {
        cancelRepeat()
        guard let next = future.popLast() else { return false }
        let key = futureKeys.popLast()
        past.append(state)
        if let key { pastKeys.append(key) }
        let viewingStack = state.fullscreen
        state = next
        state.fullscreen = viewingStack
        model = state
        replayedKey = key
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
        pastKeys.removeAll()
        futureKeys.removeAll()
        previousRecording = []
        replayedKey = nil
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
        case 4:
            return LCDRenderer.render(value: model.stored, text: DoubleFormat.displayValue(model.stored))
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
            push()
            disableLift()
        case 15:
            binOp(state.y + state.x)
        case 16:
            digit("0")
        case 17:
            decimalPoint()
        case 18:
            changeSign()
        case Self.exponentKey:
            beginExponent()
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
            disableLift()
        case 15:
            state.stored = state.x
            disableLift()
        case 16:
            constant(exp(1))
        case 17:
            let temp = state.x
            state.x = state.y
            state.y = temp
            updateDisplay()
            state.editing = false
            state.lift = true
        case 18:
            rotateDown()
            updateDisplay()
            state.editing = false
            state.lift = true
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
            repeatArmed = true
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
            finishEntry()
            constant(state.stored)
        case 16:
            constant(Double.pi)
        case 17:
            constant(state.y)
        case 18:
            rotateUp()
            updateDisplay()
            state.editing = false
            state.lift = true
        default:
            break
        }
    }

    /// F is the active shift. A letter repeats, ST waits for a letter, and G leaves both lights on.
    private func fChord(_ code: Int) {
        // G F G switches to recall without invoking the F G recording stop.
        if code == 9 { return }
        if code == 4 {
            state.fMode = false
            state.gMode = false
            return
        }
        state.fMode = false
        state.gMode = false
        if (0...3).contains(code) {
            repeatProgram(code)
        } else if code == 15 {
            state.letterStore = true
            state.fMode = true
            state.gMode = true
            finishEntry()
        } else {
            fShift(code)
        }
    }

    /// G is the active shift. RC waits for a letter, and F leaves both lights on with repeat armed.
    private func gChord(_ code: Int) {
        if code == 4 {
            repeatArmed = true
            return
        }
        if code == 9 {
            state.fMode = false
            state.gMode = false
            return
        }
        state.fMode = false
        state.gMode = false
        if code == 15 {
            state.letterRecall = true
            state.fMode = true
            state.gMode = true
            finishEntry()
        } else {
            gShift(code)
        }
    }

    /// A letter picks A–D. Store treats any other key as if G was never pressed. Recall ignores that key.
    private func finishLetter(_ code: Int) {
        let letter = (0...3).contains(code) ? code : -1
        let storing = state.letterStore
        state.letterStore = false
        state.letterRecall = false
        state.fMode = false
        state.gMode = false
        if storing {
            finishEntry()
            state.lift = false
            if letter >= 0 {
                state.values[letter] = state.x
            } else {
                state.stored = state.x
                primary(code)
            }
        } else if letter >= 0 {
            finishEntry()
            constant(state.values[letter])
        }
    }

    private func startRecording(_ program: Int) {
        finishEntry()
        previousRecording = state.programs[program]
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

    /// Pops X and runs the program that many times. A later key stops whatever is left.
    /// A repeat met while another macro is playing yields too, so each inner
    /// pass can draw before the next one starts.
    private func repeatProgram(_ program: Int) {
        finishEntry()
        // Nil has no countdown and always uses the cancellable scheduler.
        let count = state.x == .infinity ? nil : repeatCount(state.x)
        pop()
        updateDisplay()
        guard count != 0 else { return }
        if let count, !yieldsRepeats {
            for _ in 0..<count {
                playRepeat(program)
            }
            return
        }
        let generation = repeatGeneration
        if playDepth > 0 { suspendPlayback = true }
        scheduleRepeat { [weak self] in
            self?.stepRepeat(program, remaining: count, generation: generation)
        }
    }

    private func stepRepeat(_ program: Int, remaining: Int?, generation: Int) {
        guard generation == repeatGeneration else { return }
        guard remaining != 0 else {
            resumePlayback()
            return
        }
        let framesBefore = playFrames.count
        playRepeat(program)
        if playFrames.count > framesBefore {
            playFrames[playFrames.count - 1].after = { [weak self] in
                self?.finishRepeatStep(program, remaining: remaining, generation: generation)
            }
            return
        }
        finishRepeatStep(program, remaining: remaining, generation: generation)
    }

    private func finishRepeatStep(_ program: Int, remaining: Int?, generation: Int) {
        guard generation == repeatGeneration else { return }
        if state.display == "NaN" { state.x = 0 }
        model = state
        scheduleRepeat { [weak self] in
            self?.stepRepeat(program, remaining: remaining.map { $0 - 1 }, generation: generation)
        }
    }

    /// Leave a gap so the watch can draw this step before the next one runs.
    private func scheduleRepeat(_ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1), execute: work)
    }

    private func playRepeat(_ program: Int) {
        let wasRecording = state.recMode
        state.recMode = false
        playRecording(program)
        state.recMode = wasRecording
    }

    private func repeatCount(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        let truncated = value.rounded(.towardZero)
        guard truncated > 0 else { return 0 }
        if let exact = Int(exactly: truncated) { return exact }
        return Int.max
    }

    private struct PlayFrame {
        var keys: [Int]
        var index: Int
        var wasSuppressed: Bool
        var wasRecording: Bool
        var insertingPrevious: Bool
        var after: (() -> Void)?
    }

    private var playFrames: [PlayFrame] = []
    private var suspendPlayback = false

    private func playRecording(_ program: Int) {
        guard playDepth < 16 else { return }
        var keys = state.programs[program]
        let insertingPrevious = state.recMode && state.progNum == program
        if insertingPrevious {
            // f and this program's key were just stored. Drop that chord and
            // copy in the macro as it was before this recording. Run that
            // copy once, so the stack matches, without calling the new macro.
            var recorded = keys
            if recorded.count >= 2,
               recorded[recorded.count - 2] == 4,
               recorded[recorded.count - 1] == program {
                recorded.removeLast(2)
            }
            recorded.append(contentsOf: previousRecording)
            state.programs[program] = recorded
            keys = previousRecording
        }
        playDepth += 1
        let wasSuppressed = suppressPublish
        let wasRecording = state.recMode
        suppressPublish = true
        if insertingPrevious { state.recMode = false }
        finishEntry()
        runKeys(
            keys,
            from: 0,
            wasSuppressed: wasSuppressed,
            wasRecording: wasRecording,
            insertingPrevious: insertingPrevious,
            after: nil
        )
    }

    /// Runs a macro until it ends or a nested repeat needs the screen.
    /// The rest of the keys resume after that repeat draws each pass.
    private func runKeys(
        _ keys: [Int],
        from index: Int,
        wasSuppressed: Bool,
        wasRecording: Bool,
        insertingPrevious: Bool,
        after: (() -> Void)?
    ) {
        var cursor = index
        while cursor < keys.count {
            let key = keys[cursor]
            cursor += 1
            applyKey(row: key / 5, column: key % 5)
            if suspendPlayback {
                suspendPlayback = false
                playFrames.append(PlayFrame(
                    keys: keys,
                    index: cursor,
                    wasSuppressed: wasSuppressed,
                    wasRecording: wasRecording,
                    insertingPrevious: insertingPrevious,
                    after: after
                ))
                return
            }
        }
        if insertingPrevious { state.recMode = wasRecording }
        suppressPublish = wasSuppressed
        playDepth = max(0, playDepth - 1)
        after?()
    }

    private func resumePlayback() {
        guard !playFrames.isEmpty else { return }
        let frame = playFrames.removeLast()
        runKeys(
            frame.keys,
            from: frame.index,
            wasSuppressed: frame.wasSuppressed,
            wasRecording: frame.wasRecording,
            insertingPrevious: frame.insertingPrevious,
            after: frame.after
        )
    }

    /// Operators finish the number in X. Recording and playing do the same,
    /// so a macro can assume X is already entered. ENTER inside a macro still
    /// duplicates, which is how a square is "enter, multiply."
    // The raw entry already participates in snapshots and undo. An E in an
    // editing display marks exponent entry, while results may also contain E.
    private var exponentEntry: (mantissa: String, digits: String, negative: Bool)? {
        guard state.editing, let separator = state.display.firstIndex(of: "E") else { return nil }
        let exponent = state.display[state.display.index(after: separator)...]
        let negative = exponent.first == "-"
        let digits = negative ? exponent.dropFirst() : exponent
        return (String(state.display[..<separator]), String(digits), negative)
    }

    private func beginExponent() {
        if exponentEntry != nil { finishEntry() }
        if !state.editing {
            if state.lift { push() }
            state.display = "1"
            state.editing = true
            state.lift = true
        } else if !state.hasTypedMantissa && state.display == "0" {
            state.display = "1"
        }
        state.hasTypedMantissa = true
        if state.display.last == "." { state.display.removeLast() }
        state.display += "E0"
        updateValue()
    }

    private func setExponent(_ mantissa: String, _ digits: String, negative: Bool) {
        state.display = mantissa + "E" + (negative ? "-" : "") + digits
        updateValue()
    }

    private func finishEntry() {
        if exponentEntry != nil { updateDisplay() }
        state.editing = false
    }

    /// ENTER, clear X, and store leave a finished X. The next number replaces it.
    private func disableLift() {
        finishEntry()
        state.lift = false
    }

    private func digit(_ character: Character) {
        if let entry = exponentEntry {
            let digits = String(entry.digits.drop(while: { $0 == "0" }))
            guard digits.count < 3 else { return }
            setExponent(entry.mantissa, digits + String(character), negative: entry.negative)
            return
        }
        if !state.editing {
            if state.lift { push() }
            state.display = ""
            state.editing = true
            state.lift = true
        }
        state.hasTypedMantissa = true
        if state.display == "0" { state.display = "" }
        if state.display == "-0" { state.display = "-" }
        if displayLength() < 7 {
            state.display.append(character)
            updateValue()
        }
    }

    private func decimalPoint() {
        guard exponentEntry == nil else { return }
        if !state.editing {
            if state.lift { push() }
            state.display = "0"
            state.editing = true
            state.lift = true
        }
        state.hasTypedMantissa = true
        if !state.display.contains(".") {
            state.display.append(".")
            updateValue()
        }
    }

    private func changeSign() {
        if let entry = exponentEntry {
            setExponent(entry.mantissa, entry.digits, negative: !entry.negative)
            return
        }
        guard let first = state.display.first else { return }
        if first == "-" {
            state.display = String(state.display.dropFirst())
        } else {
            state.display = "-" + state.display
        }
        updateValue()
        if !state.editing { state.lift = true }
    }

    private func delete() {
        if let entry = exponentEntry {
            let digits = entry.digits.count > 1 ? String(entry.digits.dropLast()) : "0"
            setExponent(entry.mantissa, digits, negative: entry.negative)
            return
        }
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

    /// Drop toward X. T is copied down and also left in place.
    private func pop() {
        state.x = state.y
        state.y = state.z
        state.z = state.t
    }

    private func unOp(_ value: Double) {
        state.x = value
        state.editing = false
        state.lift = true
        updateDisplay()
    }

    private func binOp(_ value: Double) {
        pop()
        unOp(value)
    }

    private func constant(_ value: Double) {
        if state.editing {
            finishEntry()
            push()
        } else if state.lift {
            push()
        }
        state.x = value
        state.editing = false
        state.lift = true
        updateDisplay()
    }

    /// Toward X, the HP-35 roll down. 4, 3, 2, 1 becomes 2 in X.
    private func rotateDown() {
        let temp = state.x
        state.x = state.y
        state.y = state.z
        state.z = state.t
        state.t = temp
    }

    /// Away from X. The reverse of roll down.
    private func rotateUp() {
        let temp = state.t
        state.t = state.z
        state.z = state.y
        state.y = state.x
        state.x = temp
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
