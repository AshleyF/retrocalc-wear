package org.feniello.retrocalc;

import org.junit.Test;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class CalculatorTest {
    private void type(Calculator calc, String keys) {
        Map<Character, Integer> code = new HashMap<>();
        code.put('0', 16); code.put('1', 11); code.put('2', 12); code.put('3', 13); code.put('4', 6);
        code.put('5', 7); code.put('6', 8); code.put('7', 1); code.put('8', 2); code.put('9', 3);
        code.put('.', 17); code.put('±', 18);
        code.put('+', 15); code.put('-', 10); code.put('×', 5); code.put('÷', 0);
        code.put('f', 4); code.put('g', 9); code.put('E', 14); code.put('e', Calculator.EXPONENT_KEY);
        for (int i = 0; i < keys.length(); i++) {
            int key = code.get(keys.charAt(i));
            calc.press(key / 5, key % 5);
        }
    }

    @Test
    public void exponentEntryKeepsTheStackUntilEnter() {
        Calculator calc = new Calculator();
        type(calc, "8E7E2E45e");
        assertEquals("45E0", calc.getDisplay());
        assertEquals(45, calc.getX(), 0);
        assertEquals(2, calc.getY(), 0);
        assertEquals(7, calc.getZ(), 0);
        assertEquals(8, calc.getT(), 0);
        type(calc, "3E");
        assertEquals("45000", calc.getDisplay());
        assertEquals(45000, calc.getY(), 0);
        assertEquals(2, calc.getZ(), 0);
        assertEquals(7, calc.getT(), 0);
        assertTrue(calc.undo());
        assertEquals("45E3", calc.getDisplay());
        assertEquals(2, calc.getY(), 0);
        assertTrue(calc.redo());
        assertEquals("45000", calc.getDisplay());
    }

    @Test
    public void holdingEnterDuringExponentEntryStartsTheNextNumber() {
        Calculator calc = new Calculator();
        type(calc, "2Ee9e");
        assertEquals("1E0", calc.getDisplay());
        assertEquals(1e9, calc.getY(), 0);
        assertEquals(2, calc.getZ(), 0);
        assertTrue(calc.undo());
        assertEquals("1E9", calc.getDisplay());
        assertEquals(2, calc.getY(), 0);
        assertTrue(calc.redo());
        type(calc, "3+");
        assertEquals(1_000_001_000, calc.getX(), 0);
        assertEquals(2, calc.getY(), 0);
    }

    @Test
    public void exponentSignDeleteAndDirectOperation() {
        Calculator calc = new Calculator();
        type(calc, "2E45e23±gE");
        assertEquals("45E-2", calc.getDisplay());
        type(calc, "×");
        assertEquals(0.9, calc.getX(), 0.000001);

        Calculator threeDigits = new Calculator();
        type(threeDigits, "1e±123");
        assertEquals("1E-123", threeDigits.getDisplay());
        type(threeDigits, "E");
        assertEquals(1e-123, threeDigits.getX(), 0);

        Calculator implicit = new Calculator();
        type(implicit, "e4E");
        assertEquals(10000, implicit.getX(), 0);

        Calculator completed = new Calculator();
        type(completed, "42Ee");
        assertEquals("1E0", completed.getDisplay());
        assertEquals(42, completed.getY(), 0);
        type(completed, "9");
        assertEquals(1e9, completed.getX(), 0);
        assertEquals(42, completed.getY(), 0);
        Calculator zero = new Calculator();
        type(zero, "0e4E");
        assertEquals(0, zero.getX(), 0);
    }

    @Test
    public void exponentEntryRecordsOneDistinctMacroKey() {
        Calculator calc = new Calculator();
        type(calc, "g÷45e3Eg÷");
        assertEquals(Arrays.asList(6, 7, Calculator.EXPONENT_KEY, 13, 14), calc.getProgram(0));
        type(calc, "fEf÷");
        assertEquals(45000, calc.getX(), 0);
        assertEquals(45000, calc.getY(), 0);
    }

    @Test
    public void enterDuplicatesForASquareAndTheNextNumberReplacesX() {
        Calculator squared = new Calculator();
        type(squared, "5E×");
        assertEquals(25, squared.getX(), 0);
        assertEquals(0, squared.getY(), 0);

        Calculator replaced = new Calculator();
        type(replaced, "5E7");
        assertEquals(7, replaced.getX(), 0);
        assertEquals(5, replaced.getY(), 0);
        assertEquals(0, replaced.getZ(), 0);

        Calculator e = new Calculator();
        type(e, "5Ef0");
        assertEquals(5, e.getY(), 0);
        assertEquals(Math.E, e.getX(), 1e-12);

        Calculator pi = new Calculator();
        type(pi, "5Eg0");
        assertEquals(5, pi.getY(), 0);
        assertEquals(Math.PI, pi.getX(), 1e-12);

        Calculator cleared = new Calculator();
        type(cleared, "5fE3");
        assertEquals(3, cleared.getX(), 0);
        assertEquals(0, cleared.getY(), 0);

        Calculator stored = new Calculator();
        type(stored, "5f+3");
        assertEquals(5, stored.getStored(), 0);
        assertEquals(3, stored.getX(), 0);
        assertEquals(0, stored.getY(), 0);

        Calculator lifted = new Calculator();
        type(lifted, "5E×3");
        assertEquals(3, lifted.getX(), 0);
        assertEquals(25, lifted.getY(), 0);
    }

    @Test
    public void popDuplicatesT() {
        Calculator calc = new Calculator();
        type(calc, "4E3E2E1×");
        assertEquals(2, calc.getX(), 0);
        assertEquals(3, calc.getY(), 0);
        assertEquals(4, calc.getZ(), 0);
        assertEquals(4, calc.getT(), 0);
    }

    @Test
    public void entryStopsAtSevenDigits() {
        Calculator calc = new Calculator();
        type(calc, "12345678");
        assertEquals("1234567", calc.getDisplay());
        assertEquals(1234567, calc.getX(), 0);
    }

    @Test
    public void displayTapIsNotRecorded() {
        Calculator calc = new Calculator();
        type(calc, "g÷2");
        calc.pressDisplay();
        assertTrue(calc.isFullscreen());
        assertEquals(Arrays.asList(12), calc.getProgram(0));
        calc.pressDisplay();
        assertFalse(calc.isFullscreen());
        assertEquals(Arrays.asList(12), calc.getProgram(0));
        type(calc, "+g÷");
        assertFalse(calc.isRecMode());
        assertEquals(Arrays.asList(12, 15), calc.getProgram(0));
    }

    @Test
    public void recordingDropsTheStopChord() {
        Calculator calc = new Calculator();
        type(calc, "g÷2+g÷");
        assertFalse(calc.isRecMode());
        assertEquals(Arrays.asList(12, 15), calc.getProgram(0));
        type(calc, "5Ef÷");
        assertEquals("7", calc.getDisplay());
    }

    @Test
    public void recordingACallDoesNotCopyTheOtherProgram() {
        Calculator calc = new Calculator();
        type(calc, "g91g9");
        assertEquals(Arrays.asList(11), calc.getProgram(3));
        type(calc, "g8f9+g8");
        assertEquals(Arrays.asList(4, 3, 15), calc.getProgram(2));
        type(calc, "10f8");
        assertEquals(11, calc.getX(), 0);
    }

    @Test
    public void rerecordingInsertsThePreviousMacroOnce() {
        Calculator calc = new Calculator();
        type(calc, "g82×g8");
        assertEquals(Arrays.asList(12, 5), calc.getProgram(2));
        type(calc, "g8+");
        assertEquals(Arrays.asList(15), calc.getProgram(2));
        type(calc, "f8");
        assertTrue(calc.isRecMode());
        assertEquals(Arrays.asList(15, 12, 5), calc.getProgram(2));
        type(calc, "g8");
        assertFalse(calc.isRecMode());
        type(calc, "10f8");
        assertEquals(20, calc.getX(), 0);
    }

    @Test
    public void macroCompletesTheNumberBeingTyped() {
        Calculator calc = new Calculator();
        type(calc, "212g÷");
        assertFalse(calc.isEditing());
        assertEquals(212, calc.getX(), 0);
        assertEquals(0, calc.getY(), 0);
        type(calc, "32-1.8÷g÷");
        assertEquals(Arrays.asList(13, 12, 10, 11, 17, 2, 0), calc.getProgram(0));
        Calculator play = new Calculator();
        type(play, "g÷32-1.8÷g÷");
        type(play, "212f÷");
        assertEquals(100, play.getX(), 1e-9);
    }

    @Test
    public void repeatRunsTheProgramAndPopsTheCount() {
        Calculator calc = new Calculator();
        type(calc, "g÷1+g÷");
        calc.yieldsRepeats = false;
        type(calc, "8E5gf÷");
        assertEquals(13, calc.getX(), 0);
        assertEquals(1, calc.getY(), 0);
        assertFalse(calc.isFMode());
    }

    @Test
    public void infiniteRepeatStopsOnAKeyEvenInsideAnotherMacro() {
        for (String chord : new String[]{"gf÷", "f7"}) {
            Calculator calc = new Calculator();
            calc.getProgram(0).addAll(Arrays.asList(11, 15)); // 1 +
            calc.getProgram(1).addAll(Arrays.asList(9, 4, 0, 3)); // G F A, then 9
            java.util.ArrayDeque<Runnable> pending = new java.util.ArrayDeque<>();
            calc.setScheduler(pending::add);
            calc.yieldsRepeats = false;
            type(calc, "8E1E0÷");
            assertEquals(Double.POSITIVE_INFINITY, calc.getX(), 0);
            type(calc, chord);
            assertEquals(8, calc.getX(), 0);

            for (int step = 0; step < 3; step++) pending.removeFirst().run();
            assertEquals(11, calc.getX(), 0);
            type(calc, "f");
            pending.removeFirst().run();
            assertTrue(pending.isEmpty());
            assertEquals(11, calc.getX(), 0);
            assertTrue(calc.isFMode());
        }
    }

    @Test
    public void clippedFractionDropsTrailingZeros() {
        assertEquals("66.6", LcdText.clipMantissa("66.60000000000001", 8));
        assertEquals("0.333333", LcdText.clipMantissa("0.3333333333333333", 8));
    }

    @Test
    public void letterRegistersStoreAndRecall() {
        Calculator calc = new Calculator();
        type(calc, "g72+g7");
        type(calc, "3Egf+7");
        assertEquals(3, calc.getValue(1), 0);
        assertEquals(0, calc.getStored(), 0);
        assertEquals(Arrays.asList(12, 15), calc.getProgram(1));
        assertFalse(calc.isFMode());
        assertFalse(calc.isGMode());

        type(calc, "9Efg+7");
        assertEquals(3, calc.getX(), 0);
        assertEquals(9, calc.getY(), 0);
        assertEquals(Arrays.asList(12, 15), calc.getProgram(1));
    }

    @Test
    public void recordingCanStoreAndRecallLetterRegisters() {
        Calculator calc = new Calculator();
        type(calc, "g÷7gf+74gfg+7+");
        assertTrue(calc.isRecMode());
        assertEquals(11, calc.getX(), 0);
        assertEquals(7, calc.getValue(1), 0);

        type(calc, "fg");
        assertFalse(calc.isRecMode());
        assertEquals(Arrays.asList(1, 9, 4, 15, 1, 6, 9, 4, 9, 15, 1, 15), calc.getProgram(0));
        type(calc, "2gf+7f÷");
        assertEquals(11, calc.getX(), 0);
        assertEquals(7, calc.getValue(1), 0);
    }

    @Test
    public void letterStoreFallsBackToST() {
        Calculator calc = new Calculator();
        type(calc, "4Egf+2");
        assertEquals(4, calc.getStored(), 0);
        assertEquals(2, calc.getX(), 0);
        assertEquals(4, calc.getY(), 0);
        assertEquals(0, calc.getValue(0), 0);
        assertFalse(calc.isLetterStore());
    }

    @Test
    public void storeAndRecallCompleteTheNumber() {
        Calculator stored = new Calculator();
        type(stored, "42f+8");
        assertEquals(42, stored.getStored(), 0);
        assertEquals(8, stored.getX(), 0);
        assertEquals(0, stored.getY(), 0);
        assertEquals("8", stored.getDisplay());

        Calculator letter = new Calculator();
        type(letter, "42gf+÷8");
        assertEquals(42, letter.getValue(0), 0);
        assertEquals(8, letter.getX(), 0);
        assertEquals(0, letter.getY(), 0);

        Calculator letterDigit = new Calculator();
        type(letterDigit, "42gf+86");
        assertEquals(42, letterDigit.getValue(2), 0);
        assertEquals("6", letterDigit.getDisplay());
        assertEquals(6, letterDigit.getX(), 0);
        assertEquals(0, letterDigit.getY(), 0);

        Calculator fallback = new Calculator();
        type(fallback, "42gf+6");
        assertEquals(42, fallback.getStored(), 0);
        assertEquals(6, fallback.getX(), 0);
        assertEquals(0, fallback.getY(), 0);
        assertEquals("6", fallback.getDisplay());

        Calculator recall = new Calculator();
        type(recall, "7f+");
        type(recall, "42g+8");
        assertEquals(8, recall.getX(), 0);
        assertEquals(7, recall.getY(), 0);
        assertEquals(42, recall.getZ(), 0);

        Calculator letterRecall = new Calculator();
        type(letterRecall, "7gf+÷");
        type(letterRecall, "42fg+÷8");
        assertEquals(8, letterRecall.getX(), 0);
        assertEquals(7, letterRecall.getY(), 0);
        assertEquals(42, letterRecall.getZ(), 0);
    }

    @Test
    public void letterRecallIgnoresAnyOtherKey() {
        Calculator calc = new Calculator();
        type(calc, "4Efg+2");
        assertEquals(4, calc.getX(), 0);
        assertEquals(4, calc.getY(), 0);
        assertEquals("4", calc.getDisplay());
        assertFalse(calc.isLetterRecall());
        assertFalse(calc.isFMode());
        assertFalse(calc.isGMode());
    }

    @Test
    public void roundFaceStoresOnThePaintedLetters() {
        Calculator calc = new Calculator();
        calc.setRoundFace(true);
        type(calc, "5Egf+7");
        assertEquals(5, calc.getValue(0), 0);
        type(calc, "8Egf+÷");
        assertEquals(8, calc.getValue(3), 0);
        type(calc, "fg+7");
        assertEquals(5, calc.getX(), 0);
    }

    @Test
    public void bothShiftLightsStayOn() {
        Calculator calc = new Calculator();
        type(calc, "fg");
        assertTrue(calc.isFMode());
        assertTrue(calc.isGMode());
        type(calc, "g");
        assertFalse(calc.isFMode());
        assertFalse(calc.isGMode());
        type(calc, "gf");
        assertTrue(calc.isFMode());
        assertTrue(calc.isGMode());
    }

    @Test
    public void restoredStateKeepsProgramsAndDropsTheUndoTape() {
        Calculator calc = new Calculator();
        type(calc, "g÷2+g÷");
        type(calc, "6f+");
        Calculator.Snapshot saved = calc.exportState();
        Calculator again = new Calculator();
        type(again, "9");
        again.restoreState(saved);
        assertEquals(Arrays.asList(12, 15), again.getProgram(0));
        assertEquals(6, again.getStored(), 0);
        assertEquals("6", again.getDisplay());
        assertFalse(again.undo());
    }

    @Test
    public void closingTheStackDoesNotStopARunningMacro() {
        Calculator calc = new Calculator();
        type(calc, "g÷1+g÷");
        java.util.ArrayDeque<Runnable> pending = new java.util.ArrayDeque<>();
        calc.setScheduler(pending::add);
        type(calc, "8E5gf÷");
        calc.pressDisplay();
        assertTrue(calc.isFullscreen());
        calc.pressDisplay();
        assertFalse(calc.isFullscreen());
        while (!pending.isEmpty()) pending.removeFirst().run();
        assertEquals(13, calc.getX(), 0);
        assertEquals(1, calc.getY(), 0);
    }

    @Test
    public void plainPlayDoesNotRepeat() {
        Calculator calc = new Calculator();
        type(calc, "g÷1+g÷");
        type(calc, "8E5f÷");
        assertEquals(6, calc.getX(), 0);
        assertEquals(8, calc.getY(), 0);
    }

    @Test
    public void undoOfProgramPlayIsOneKeystroke() {
        Calculator calc = new Calculator();
        type(calc, "g÷2+g÷");
        type(calc, "5Ef÷");
        assertEquals("7", calc.getDisplay());
        assertTrue(calc.undo());
        assertEquals("5", calc.getDisplay());
        assertTrue(calc.isFMode());
        assertTrue(calc.undo());
        assertFalse(calc.isFMode());
        assertEquals("5", calc.getDisplay());
    }

    @Test
    public void integerPartTruncatesTowardZero() {
        Calculator calc = new Calculator();
        type(calc, "3.14±g6");
        assertEquals("-3", calc.getDisplay());
    }

    @Test
    public void stackViewIsNotAnUndoStep() {
        Calculator calc = new Calculator();
        type(calc, "12");
        calc.pressDisplay();
        assertTrue(calc.isFullscreen());
        assertTrue(calc.undo());
        assertEquals("1", calc.getDisplay());
        assertTrue(calc.isFullscreen());
    }

    @Test
    public void roundFacePutsProgramsOnSevenThroughDivide() {
        Calculator calc = new Calculator();
        calc.setRoundFace(true);
        // 6 still does 1/x. ÷ is program D, not 1/x.
        type(calc, "4f6");
        assertEquals(0.25, calc.getX(), 1e-12);
        type(calc, "4f÷");
        assertEquals("4", calc.getDisplay());
        // 7 is program A.
        Calculator again = new Calculator();
        again.setRoundFace(true);
        type(again, "g72+g7");
        assertEquals(Arrays.asList(12, 15), again.getProgram(0));
        type(again, "g8g8");
        assertEquals(Arrays.asList(), again.getProgram(1));
    }
}
