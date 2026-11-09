import XCTest
@testable import RetroRPNEngine

final class RPNCalculatorTests: XCTestCase {
    private func makeCalc() -> RPNCalculator { RPNCalculator() }

    /// Key legends, so tests read as keystrokes. E is ENTER.
    private func type(_ calc: RPNCalculator, _ keys: String) {
        let code: [Character: Int] = [
            "0": 16, "1": 11, "2": 12, "3": 13, "4": 6,
            "5": 7, "6": 8, "7": 1, "8": 2, "9": 3,
            ".": 17, "±": 18,
            "+": 15, "-": 10, "×": 5, "÷": 0,
            "f": 4, "g": 9, "E": 14,
        ]
        for character in keys {
            let key = code[character]!
            calc.press(row: key / 5, column: key % 5)
        }
    }

    func testEntryStopsAtSevenDigits() {
        let calc = makeCalc()
        type(calc, "12345678")
        XCTAssertEqual(calc.model.display, "1234567")
        XCTAssertEqual(calc.model.x, 1_234_567)
        XCTAssertEqual(calc.readout(for: 0).debugText, "1234567")
    }

    func testDecimalSignAndDelete() {
        let calc = makeCalc()
        type(calc, "1.5±")
        XCTAssertEqual(calc.model.display, "-1.5")
        type(calc, "gE")
        XCTAssertEqual(calc.model.display, "-1.")
        XCTAssertEqual(calc.model.x, -1)
    }

    func testSecondDecimalIsIgnored() {
        let calc = makeCalc()
        type(calc, "1.5.6")
        XCTAssertEqual(calc.model.display, "1.56")
    }

    func testArithmeticStackLiftAndDuplicate() {
        let calc = makeCalc()
        type(calc, "6E3+")
        XCTAssertEqual(calc.model.display, "9")
        XCTAssertEqual(calc.model.y, 0)

        type(calc, "E")
        XCTAssertEqual(calc.model.x, 9)
        XCTAssertEqual(calc.model.y, 9)

        type(calc, "2×")
        XCTAssertEqual(calc.model.display, "18")
        XCTAssertEqual(calc.model.y, 9)
    }

    func testDivideAndPower() {
        let calc = makeCalc()
        type(calc, "8E2÷")
        XCTAssertEqual(calc.model.display, "4")

        type(calc, "2E8f×")
        XCTAssertEqual(calc.model.display, "256")
    }

    func testReciprocalLogAndRoot() {
        let calc = makeCalc()
        type(calc, "5Ef6")
        XCTAssertEqual(calc.model.display, "0.2")

        type(calc, "100Eg5")
        XCTAssertEqual(calc.model.x, 2, accuracy: 1e-9)

        let roots = makeCalc()
        type(roots, "256E2g×")
        XCTAssertEqual(roots.model.x, 16, accuracy: 1e-9)
    }

    func testConstantsMemoryAndSwap() {
        let calc = makeCalc()
        type(calc, "g0")
        XCTAssertEqual(calc.model.x, Double.pi, accuracy: 1e-12)
        XCTAssertEqual(calc.readout(for: 0).debugText, "3.141592")

        type(calc, "f+")
        let stored = calc.model.stored
        type(calc, "3g+")
        XCTAssertEqual(calc.model.x, stored, accuracy: 1e-12)
        XCTAssertEqual(calc.model.y, 3)

        type(calc, "2E3f.")
        XCTAssertEqual(calc.model.x, 2)
        XCTAssertEqual(calc.model.y, 3)
    }

    func testTrigAndIntegerPart() {
        let calc = makeCalc()
        type(calc, "0f1")
        XCTAssertEqual(calc.model.x, 0, accuracy: 1e-12)

        type(calc, "3.14±g6")
        XCTAssertEqual(calc.model.display, "-3")
    }

    func testRoll() {
        let calc = makeCalc()
        type(calc, "1E2E3")
        XCTAssertEqual(calc.model.x, 3)
        XCTAssertEqual(calc.model.y, 2)
        XCTAssertEqual(calc.model.z, 1)

        type(calc, "f±")
        XCTAssertEqual(calc.model.x, 0)
        XCTAssertEqual(calc.model.y, 3)
        XCTAssertEqual(calc.model.z, 2)
        XCTAssertEqual(calc.model.t, 1)

        type(calc, "g±")
        XCTAssertEqual(calc.model.x, 3)
        XCTAssertEqual(calc.model.y, 2)
        XCTAssertEqual(calc.model.z, 1)
    }

    func testOverDuplicatesY() {
        let calc = makeCalc()
        type(calc, "2E3g.")
        XCTAssertEqual(calc.model.x, 2)
        XCTAssertEqual(calc.model.y, 3)
        XCTAssertEqual(calc.model.z, 2)
    }

    func testProgramRecordsKeysAndDropsTheStopChord() {
        let calc = makeCalc()
        type(calc, "g÷2+g÷")
        XCTAssertFalse(calc.model.recMode)
        XCTAssertEqual(calc.model.programs[0], [12, 15])

        type(calc, "5Ef÷")
        XCTAssertEqual(calc.model.display, "7")
    }

    func testRandomPushesTheStack() {
        let calc = makeCalc()
        calc.randomSource = { 0.25 }
        type(calc, "6Ef-")
        XCTAssertEqual(calc.model.x, 0.25)
        XCTAssertEqual(calc.model.y, 6)
        XCTAssertFalse(calc.model.editing)
    }

    func testShiftModesCancelAndChain() {
        let calc = makeCalc()
        type(calc, "ff")
        XCTAssertFalse(calc.model.fMode)
        type(calc, "fg")
        XCTAssertTrue(calc.model.gMode)
        XCTAssertFalse(calc.model.fMode)
        type(calc, "g")
        XCTAssertFalse(calc.model.gMode)
    }

    func testFullscreenConsumesTheNextKey() {
        let calc = makeCalc()
        type(calc, "1")
        calc.pressDisplay()
        XCTAssertTrue(calc.model.fullscreen)
        type(calc, "+")
        XCTAssertFalse(calc.model.fullscreen)
        XCTAssertEqual(calc.model.display, "1")
        XCTAssertEqual(calc.model.y, 0)
    }

    func testReadoutShapes() {
        let calc = makeCalc()
        XCTAssertEqual(calc.readout(for: 0).debugText, "      0")

        type(calc, "42")
        XCTAssertEqual(calc.readout(for: 0).debugText, "     42")

        type(calc, "E2503.03±")
        XCTAssertEqual(calc.model.display, "-2503.03")
        XCTAssertEqual(calc.readout(for: 0).debugText, "-2503.03")

        let fraction = makeCalc()
        type(fraction, "1E3÷")
        XCTAssertEqual(fraction.model.display, "0.3333333333333333")
        XCTAssertEqual(fraction.readout(for: 0).debugText, "0.333333")
    }

    func testScientificNotation() {
        XCTAssertEqual(
            LCDRenderer.render(value: 10_000_000, text: "10000000").debugText,
            "   1.0 7"
        )
        XCTAssertEqual(
            LCDRenderer.render(value: -1_000_000, text: "-1000000").debugText,
            "  -1.0 6"
        )
        XCTAssertEqual(
            LCDRenderer.render(value: 0.0001, text: DoubleFormat.displayValue(0.0001)).debugText,
            "   1.0-4"
        )
        XCTAssertEqual(
            LCDRenderer.render(value: .infinity, text: "Infinity").debugText,
            "  1nfin"
        )
        XCTAssertEqual(
            LCDRenderer.render(value: .nan, text: "NaN").debugText,
            "  error"
        )
    }

    func testDivisionByZeroShowsInfinity() {
        let calc = makeCalc()
        type(calc, "1E0÷")
        XCTAssertEqual(calc.model.display, "Infinity")
        XCTAssertTrue(calc.model.x.isInfinite)
        XCTAssertEqual(calc.readout(for: 0).debugText, "  1nfin")
    }

    func testNaNDisplayClearsTheValue() {
        let calc = makeCalc()
        type(calc, "0E0÷")
        XCTAssertEqual(calc.model.display, "NaN")
        XCTAssertEqual(calc.model.x, 0)
        XCTAssertEqual(calc.readout(for: 0).debugText, "  error")
    }

    func testSnapshotRoundTrip() throws {
        let calc = makeCalc()
        type(calc, "g÷2+fg")
        type(calc, "6f+")
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        let data = try encoder.encode(calc.model)
        let restored = try decoder.decode(RPNCalculator.Model.self, from: data)
        let other = RPNCalculator()
        other.restore(restored)
        XCTAssertEqual(other.model.programs[0], [12, 15])
        XCTAssertEqual(other.model.stored, 6)
        XCTAssertEqual(other.model.display, "6")
        XCTAssertFalse(other.undo())
    }

    func testStackViewIsNotAnUndoStep() {
        let calc = makeCalc()
        type(calc, "12")
        calc.pressDisplay()
        XCTAssertTrue(calc.model.fullscreen)

        XCTAssertTrue(calc.undo())
        XCTAssertEqual(calc.model.display, "1")
        XCTAssertTrue(calc.model.fullscreen)

        calc.pressDisplay()
        XCTAssertFalse(calc.model.fullscreen)
        XCTAssertTrue(calc.redo())
        XCTAssertEqual(calc.model.display, "12")
        XCTAssertFalse(calc.model.fullscreen)

        calc.pressDisplay()
        type(calc, "+")
        XCTAssertFalse(calc.model.fullscreen)
        XCTAssertEqual(calc.model.display, "12")
        XCTAssertTrue(calc.undo())
        XCTAssertEqual(calc.model.display, "1")
    }

    func testUndoRedoEachKeystroke() {
        let calc = makeCalc()
        type(calc, "12+3")
        XCTAssertEqual(calc.model.display, "3")
        XCTAssertEqual(calc.model.y, 12)

        XCTAssertTrue(calc.undo())
        XCTAssertEqual(calc.model.display, "12")
        XCTAssertEqual(calc.model.y, 0)
        XCTAssertFalse(calc.model.editing)

        XCTAssertTrue(calc.undo())
        XCTAssertEqual(calc.model.display, "12")
        XCTAssertTrue(calc.model.editing)

        XCTAssertTrue(calc.undo())
        XCTAssertEqual(calc.model.display, "1")
        XCTAssertTrue(calc.undo())
        XCTAssertEqual(calc.model.display, "0")
        XCTAssertFalse(calc.undo())

        XCTAssertTrue(calc.redo())
        XCTAssertEqual(calc.model.display, "1")
        XCTAssertTrue(calc.redo())
        XCTAssertEqual(calc.model.display, "12")
        XCTAssertTrue(calc.model.editing)
    }

    func testNewKeystrokeDropsRedo() {
        let calc = makeCalc()
        type(calc, "12")
        XCTAssertTrue(calc.undo())
        type(calc, "9")
        XCTAssertFalse(calc.redo())
        XCTAssertEqual(calc.model.display, "19")
    }

    func testIgnoredDigitIsNotAnUndoStep() {
        let calc = makeCalc()
        type(calc, "12345678")
        XCTAssertEqual(calc.model.display, "1234567")
        XCTAssertTrue(calc.undo())
        XCTAssertEqual(calc.model.display, "123456")
    }

    func testMacroCompletesTheNumberBeingTyped() {
        let calc = makeCalc()
        type(calc, "212g÷")
        XCTAssertFalse(calc.model.editing)
        XCTAssertEqual(calc.model.x, 212)
        XCTAssertEqual(calc.model.y, 0)
        XCTAssertEqual(calc.model.programs[0], [])

        type(calc, "32-1.8÷g÷")
        XCTAssertEqual(calc.model.programs[0], [13, 12, 10, 11, 17, 2, 0])

        let play = makeCalc()
        play.restore(calc.model)
        type(play, "212f÷")
        XCTAssertEqual(play.model.x, 100, accuracy: 1e-9)
        XCTAssertFalse(play.model.editing)

        let square = makeCalc()
        type(square, "g÷E×g÷")
        XCTAssertEqual(square.model.programs[0], [14, 5])
        type(square, "5f÷")
        XCTAssertEqual(square.model.x, 25)
        XCTAssertEqual(square.model.y, 0)
    }

    func testUndoOfProgramPlayIsOneKeystroke() {
        let calc = makeCalc()
        type(calc, "g÷2+g÷")
        type(calc, "5Ef÷")
        XCTAssertEqual(calc.model.display, "7")

        XCTAssertTrue(calc.undo())
        XCTAssertEqual(calc.model.display, "5")
        XCTAssertTrue(calc.model.fMode)

        XCTAssertTrue(calc.undo())
        XCTAssertFalse(calc.model.fMode)
        XCTAssertEqual(calc.model.display, "5")
    }
}
