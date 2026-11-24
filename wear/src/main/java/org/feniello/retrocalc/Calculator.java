package org.feniello.retrocalc;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.function.DoubleSupplier;

/**
 * Four-level RPN engine shared with the Apple Watch app.
 * Key codes are column + row * 5. Program A is divide, and 1/x is 6,
 * except on the round face, where those two f/g legends are swapped.
 */
public final class Calculator {
    public static final int EXPONENT_KEY = 20;

    public interface Listener {
        void onChanged();
    }

    public interface Scheduler {
        void schedule(Runnable work);
    }

    public static final class Snapshot {
        public double x;
        public double y;
        public double z;
        public double t;
        public String display;
        public boolean editing;
        public boolean hasTypedMantissa;
        public boolean fMode;
        public boolean gMode;
        public boolean recMode;
        public boolean fullscreen;
        public double stored;
        public List<List<Integer>> programs;
        public double[] values = new double[4];
        public boolean letterStore;
        public boolean letterRecall;
        /** The next number raises the stack. ENTER, clear X, and store turn this off. */
        public boolean lift = true;
        public int progNum;

        Snapshot copy() {
            Snapshot snap = new Snapshot();
            snap.x = x;
            snap.y = y;
            snap.z = z;
            snap.t = t;
            snap.display = display;
            snap.editing = editing;
            snap.hasTypedMantissa = hasTypedMantissa;
            snap.fMode = fMode;
            snap.gMode = gMode;
            snap.recMode = recMode;
            snap.fullscreen = fullscreen;
            snap.stored = stored;
            snap.progNum = progNum;
            snap.programs = copyPrograms(programs);
            snap.values = Arrays.copyOf(values, 4);
            snap.letterStore = letterStore;
            snap.letterRecall = letterRecall;
            snap.lift = lift;
            return snap;
        }
    }

    private static List<List<Integer>> copyPrograms(List<List<Integer>> source) {
        List<List<Integer>> copy = new ArrayList<>();
        for (List<Integer> program : source) {
            copy.add(new ArrayList<>(program));
        }
        return copy;
    }

    private static boolean samePrograms(List<List<Integer>> a, List<List<Integer>> b) {
        if (a.size() != b.size()) return false;
        for (int i = 0; i < a.size(); i++) {
            if (!a.get(i).equals(b.get(i))) return false;
        }
        return true;
    }

    private double x = 0;
    private double y = 0;
    private double z = 0;
    private double t = 0;
    private String display = "0";
    private boolean editing = true;
    private boolean hasTypedMantissa;
    private boolean fMode = false;
    private boolean gMode = false;
    private boolean recMode = false;
    private boolean fullscreen = false;
    private double stored = 0;
    private final List<List<Integer>> programs = new ArrayList<>();
    private final double[] values = new double[4];
    private boolean letterStore = false;
    private boolean letterRecall = false;
    /** The next number raises the stack. ENTER, clear X, and store turn this off. */
    private boolean lift = true;
    private int progNum = 0;

    private boolean suppressPublish = false;
    private int playDepth = 0;
    private final List<Snapshot> past = new ArrayList<>();
    private final List<Snapshot> future = new ArrayList<>();
    private final List<Integer> pastKeys = new ArrayList<>();
    private final List<Integer> futureKeys = new ArrayList<>();
    private static final int TAPE_LIMIT = 400;
    private List<Integer> previousRecording = new ArrayList<>();
    private Integer replayedKey = null;
    /** Tests run a repeat inline. The watch yields so each pass can draw. */
    public boolean yieldsRepeats = true;
    private boolean repeatArmed = false;
    private int repeatGeneration = 0;
    private boolean roundFace = false;
    public DoubleSupplier randomSource = Math::random;
    private Listener listener;
    private Scheduler scheduler;

    private final List<PlayFrame> playFrames = new ArrayList<>();
    private boolean suspendPlayback = false;

    public Calculator() {
        for (int i = 0; i < 4; i++) programs.add(new ArrayList<>());
    }

    public void setListener(Listener listener) {
        this.listener = listener;
    }

    public void setScheduler(Scheduler scheduler) {
        this.scheduler = scheduler;
    }

    public void setRoundFace(boolean roundFace) {
        this.roundFace = roundFace;
    }

    public void press(int row, int column) {
        boolean publish = !suppressPublish;
        boolean stackGesture = row < 0 || (playDepth == 0 && fullscreen && row >= 0);
        if (publish && row >= 0) cancelRepeat();
        boolean armed = repeatArmed;
        repeatArmed = false;
        Snapshot before = snapshot();
        int requested = column + row * 5;
        int code = requested == EXPONENT_KEY && (fMode || gMode) ? 14 : requested;
        if (recMode && playDepth == 0 && row >= 0) {
            programs.get(progNum).add(code);
        }
        if (stackGesture) {
            fullscreen = !fullscreen;
        } else if (letterStore || letterRecall) {
            finishLetter(code);
        } else if (fMode && gMode) {
            if (armed) fChord(code);
            else gChord(code);
        } else if (fMode) {
            boolean keep = faceCode(code) == 9 && !recMode;
            fMode = false;
            int shifted = faceCode(code);
            if (armed && shifted >= 0 && shifted <= 3) repeatProgram(shifted);
            else fShift(shifted);
            if (keep) fMode = true;
        } else if (gMode) {
            boolean keep = faceCode(code) == 4;
            gMode = false;
            gShift(faceCode(code));
            if (keep) gMode = true;
        } else {
            primary(code);
        }
        if (publish) {
            if ("NaN".equals(display)) x = 0;
            if (!sameCalculation(before, snapshot()) && !isStackToggle(before, snapshot())) {
                past.add(before);
                pastKeys.add(code);
                if (past.size() > TAPE_LIMIT) {
                    past.remove(0);
                    pastKeys.remove(0);
                }
                future.clear();
                futureKeys.clear();
            }
            notifyListener();
        } else if (row < 0) {
            notifyListener();
        }
    }

    public void pressDisplay() {
        press(-1, 0);
    }

    public boolean undo() {
        cancelRepeat();
        if (past.isEmpty()) return false;
        Snapshot previous = past.remove(past.size() - 1);
        Integer key = pastKeys.remove(pastKeys.size() - 1);
        future.add(snapshot());
        futureKeys.add(key);
        boolean viewingStack = fullscreen;
        restore(previous);
        fullscreen = viewingStack;
        replayedKey = key;
        notifyListener();
        return true;
    }

    public boolean redo() {
        cancelRepeat();
        if (future.isEmpty()) return false;
        Snapshot next = future.remove(future.size() - 1);
        Integer key = futureKeys.remove(futureKeys.size() - 1);
        past.add(snapshot());
        pastKeys.add(key);
        boolean viewingStack = fullscreen;
        restore(next);
        fullscreen = viewingStack;
        replayedKey = key;
        notifyListener();
        return true;
    }

    /**
     * The round artwork paints programs A–D on 7, 8, 9, and ÷.
     * Primary keys and the recorded codes stay put; only f and g follow the legend.
     */
    private int faceCode(int code) {
        if (!roundFace) return code;
        switch (code) {
            case 1: return 0; // 7
            case 2: return 1; // 8
            case 3: return 2; // 9
            case 0: return 3; // ÷
            default: return code;
        }
    }

    private void cancelRepeat() {
        repeatGeneration++;
        while (!playFrames.isEmpty()) {
            PlayFrame frame = playFrames.remove(playFrames.size() - 1);
            if (frame.insertingPrevious) recMode = frame.wasRecording;
            suppressPublish = frame.wasSuppressed;
            playDepth = Math.max(0, playDepth - 1);
        }
        suspendPlayback = false;
    }

    private void primary(int key) {
        switch (key) {
            case 0: binOp(y / x); break;
            case 1: digit('7'); break;
            case 2: digit('8'); break;
            case 3: digit('9'); break;
            case 4: fMode = true; break;
            case 5: binOp(y * x); break;
            case 6: digit('4'); break;
            case 7: digit('5'); break;
            case 8: digit('6'); break;
            case 9: gMode = true; break;
            case 10: binOp(y - x); break;
            case 11: digit('1'); break;
            case 12: digit('2'); break;
            case 13: digit('3'); break;
            case 14:
            case 19:
                push();
                disableLift();
                break;
            case 15: binOp(y + x); break;
            case 16: digit('0'); break;
            case 17: decimalPoint(); break;
            case 18: changeSign(); break;
            case EXPONENT_KEY: beginExponent(); break;
            default: break;
        }
    }

    private void fShift(int key) {
        switch (key) {
            case 0: playRecording(0); break;
            case 1: playRecording(1); break;
            case 2: playRecording(2); break;
            case 3: playRecording(3); break;
            case 4: break;
            case 5: binOp(Math.pow(y, x)); break;
            case 6: unOp(Math.exp(x)); break;
            case 7: unOp(Math.pow(10.0, x)); break;
            case 8: unOp(1.0 / x); break;
            case 9:
                if (recMode) stopRecording();
                else gMode = true;
                break;
            case 10: constant(randomSource.getAsDouble()); break;
            case 11: unOp(Math.sin(x)); break;
            case 12: unOp(Math.cos(x)); break;
            case 13: unOp(Math.tan(x)); break;
            case 14:
            case 19:
                x = 0;
                updateDisplay();
                disableLift();
                break;
            case 15: stored = x; disableLift(); break;
            case 16: constant(Math.E); break;
            case 17: {
                double temp = x;
                x = y;
                y = temp;
                updateDisplay();
                editing = false;
                lift = true;
                break;
            }
            case 18:
                rotateDown();
                updateDisplay();
                editing = false;
                lift = true;
                break;
            default: break;
        }
    }

    private void gShift(int key) {
        switch (key) {
            case 0:
                if (recMode) stopRecording();
                else startRecording(0);
                break;
            case 1:
                if (recMode) stopRecording();
                else startRecording(1);
                break;
            case 2:
                if (recMode) stopRecording();
                else startRecording(2);
                break;
            case 3:
                if (recMode) stopRecording();
                else startRecording(3);
                break;
            case 4:
                fMode = true;
                repeatArmed = true;
                break;
            case 5: binOp(Math.pow(y, 1.0 / x)); break;
            case 6: unOp(Math.log(x)); break;
            case 7: unOp(Math.log10(x)); break;
            case 8: unOp(truncatingToInt32(x)); break;
            case 9: break;
            case 10: unOp(Math.abs(x)); break;
            case 11: unOp(Math.asin(x)); break;
            case 12: unOp(Math.acos(x)); break;
            case 13: unOp(Math.atan(x)); break;
            case 14:
            case 19: delete(); break;
            case 15: finishEntry(); constant(stored); break;
            case 16: constant(Math.PI); break;
            case 17: constant(y); break;
            case 18:
                rotateUp();
                updateDisplay();
                editing = false;
                lift = true;
                break;
            default: break;
        }
    }

    /** F is the active shift. A letter repeats, ST waits for a letter, and G leaves both lights on. */
    private void fChord(int code) {
        int shifted = faceCode(code);
        if (shifted == 9 && !recMode) return;
        if (shifted == 4) {
            fMode = false;
            gMode = false;
            return;
        }
        fMode = false;
        gMode = false;
        if (shifted >= 0 && shifted <= 3) repeatProgram(shifted);
        else if (shifted == 15) {
            letterStore = true;
            fMode = true;
            gMode = true;
            finishEntry();
        } else fShift(shifted);
    }

    /** G is the active shift. RC waits for a letter, and F leaves both lights on with repeat armed. */
    private void gChord(int code) {
        int shifted = faceCode(code);
        if (shifted == 4) {
            repeatArmed = true;
            return;
        }
        if (shifted == 9) {
            fMode = false;
            gMode = false;
            return;
        }
        fMode = false;
        gMode = false;
        if (shifted == 15) {
            letterRecall = true;
            fMode = true;
            gMode = true;
            finishEntry();
        } else gShift(shifted);
    }

    /**
     * A letter picks A–D. Store treats any other key as if G was never pressed.
     * Recall ignores that key.
     */
    private void finishLetter(int code) {
        int shifted = faceCode(code);
        int letter = shifted >= 0 && shifted <= 3 ? shifted : -1;
        boolean storing = letterStore;
        letterStore = false;
        letterRecall = false;
        fMode = false;
        gMode = false;
        if (storing) {
            finishEntry();
            lift = false;
            if (letter >= 0) values[letter] = x;
            else {
                stored = x;
                primary(code);
            }
        } else if (letter >= 0) {
            finishEntry();
            constant(values[letter]);
        }
    }

    private void startRecording(int program) {
        finishEntry();
        previousRecording = new ArrayList<>(programs.get(program));
        recMode = true;
        progNum = program;
        programs.get(program).clear();
    }

    private void stopRecording() {
        List<Integer> program = programs.get(progNum);
        if (program.size() >= 2) {
            program.remove(program.size() - 1);
            program.remove(program.size() - 1);
        } else {
            program.clear();
        }
        recMode = false;
    }

    private void repeatProgram(int program) {
        finishEntry();
        int count = repeatCount(x);
        pop();
        updateDisplay();
        if (count <= 0) return;
        if (!yieldsRepeats) {
            for (int i = 0; i < count; i++) playRepeat(program);
            return;
        }
        int generation = repeatGeneration;
        if (playDepth > 0) suspendPlayback = true;
        schedule(() -> stepRepeat(program, count, generation));
    }

    private void stepRepeat(int program, int remaining, int generation) {
        if (generation != repeatGeneration) return;
        if (remaining <= 0) {
            resumePlayback();
            return;
        }
        int framesBefore = playFrames.size();
        playRepeat(program);
        if (playFrames.size() > framesBefore) {
            playFrames.get(playFrames.size() - 1).after = () ->
                    finishRepeatStep(program, remaining, generation);
            return;
        }
        finishRepeatStep(program, remaining, generation);
    }

    private void finishRepeatStep(int program, int remaining, int generation) {
        if (generation != repeatGeneration) return;
        if ("NaN".equals(display)) x = 0;
        notifyListener();
        schedule(() -> stepRepeat(program, remaining - 1, generation));
    }

    private void schedule(Runnable work) {
        if (scheduler != null) scheduler.schedule(work);
        else work.run();
    }

    private void playRepeat(int program) {
        boolean wasRecording = recMode;
        recMode = false;
        playRecording(program);
        recMode = wasRecording;
    }

    private int repeatCount(double value) {
        if (Double.isNaN(value) || Double.isInfinite(value)) return 0;
        double truncated = value < 0 ? Math.ceil(value) : Math.floor(value);
        if (truncated <= 0) return 0;
        if (truncated >= Integer.MAX_VALUE) return Integer.MAX_VALUE;
        return (int) truncated;
    }

    private static final class PlayFrame {
        final List<Integer> keys;
        int index;
        final boolean wasSuppressed;
        final boolean wasRecording;
        final boolean insertingPrevious;
        Runnable after;

        PlayFrame(List<Integer> keys, int index, boolean wasSuppressed, boolean wasRecording,
                  boolean insertingPrevious, Runnable after) {
            this.keys = keys;
            this.index = index;
            this.wasSuppressed = wasSuppressed;
            this.wasRecording = wasRecording;
            this.insertingPrevious = insertingPrevious;
            this.after = after;
        }
    }

    private void playRecording(int program) {
        if (playDepth >= 16) return;
        List<Integer> keys = new ArrayList<>(programs.get(program));
        boolean insertingPrevious = recMode && progNum == program;
        if (insertingPrevious) {
            List<Integer> recorded = new ArrayList<>(keys);
            int n = recorded.size();
            if (n >= 2 && recorded.get(n - 2) == 4 && recorded.get(n - 1) == program) {
                recorded.remove(n - 1);
                recorded.remove(n - 2);
            }
            recorded.addAll(previousRecording);
            programs.set(program, recorded);
            keys = new ArrayList<>(previousRecording);
        }
        playDepth++;
        boolean wasSuppressed = suppressPublish;
        boolean wasRecording = recMode;
        suppressPublish = true;
        if (insertingPrevious) recMode = false;
        finishEntry();
        runKeys(keys, 0, wasSuppressed, wasRecording, insertingPrevious, null);
    }

    private void runKeys(List<Integer> keys, int index, boolean wasSuppressed, boolean wasRecording,
                         boolean insertingPrevious, Runnable after) {
        int cursor = index;
        while (cursor < keys.size()) {
            int key = keys.get(cursor);
            cursor++;
            press(key / 5, key % 5);
            if (suspendPlayback) {
                suspendPlayback = false;
                playFrames.add(new PlayFrame(keys, cursor, wasSuppressed, wasRecording, insertingPrevious, after));
                return;
            }
        }
        if (insertingPrevious) recMode = wasRecording;
        suppressPublish = wasSuppressed;
        playDepth = Math.max(0, playDepth - 1);
        if (after != null) after.run();
    }

    private void resumePlayback() {
        if (playFrames.isEmpty()) return;
        PlayFrame frame = playFrames.remove(playFrames.size() - 1);
        runKeys(frame.keys, frame.index, frame.wasSuppressed, frame.wasRecording,
                frame.insertingPrevious, frame.after);
    }

    /** The raw editing string carries EEX through saved state and undo. */
    private int exponentStart() {
        return editing ? display.indexOf('E') : -1;
    }

    private int exponentDigitsStart() {
        int start = exponentStart() + 1;
        if (start == 0) return -1;
        return display.charAt(start) == '-' ? start + 1 : start;
    }

    private void beginExponent() {
        if (exponentStart() >= 0) finishEntry();
        if (!editing) {
            if (lift) push();
            display = "1";
            editing = true;
            lift = true;
        } else if (!hasTypedMantissa && "0".equals(display)) {
            display = "1";
        }
        hasTypedMantissa = true;
        if (display.endsWith(".")) display = display.substring(0, display.length() - 1);
        display += "E0";
        updateValue();
    }

    private void finishEntry() {
        if (exponentStart() >= 0) updateDisplay();
        editing = false;
    }

    /** ENTER, clear X, and store leave a finished X. The next number replaces it. */
    private void disableLift() {
        finishEntry();
        lift = false;
    }

    private void digit(char character) {
        int digitsStart = exponentDigitsStart();
        if (digitsStart >= 0) {
            String digits = display.substring(digitsStart).replaceFirst("^0+", "");
            if (digits.length() < 3) {
                display = display.substring(0, digitsStart) + digits + character;
                updateValue();
            }
            return;
        }
        if (!editing) {
            if (lift) push();
            display = "";
            editing = true;
            lift = true;
        }
        hasTypedMantissa = true;
        if ("0".equals(display)) display = "";
        if ("-0".equals(display)) display = "-";
        if (displayLength() < 7) {
            display = display + character;
            updateValue();
        }
    }

    private void decimalPoint() {
        if (exponentStart() >= 0) return;
        if (!editing) {
            if (lift) push();
            display = "0";
            editing = true;
            lift = true;
        }
        hasTypedMantissa = true;
        if (!display.contains(".")) {
            display = display + ".";
            updateValue();
        }
    }

    private void changeSign() {
        int start = exponentStart() + 1;
        if (start > 0) {
            display = display.substring(0, start)
                    + (display.charAt(start) == '-' ? display.substring(start + 1) : "-" + display.substring(start));
            updateValue();
            return;
        }
        if (display.isEmpty()) return;
        if (display.charAt(0) == '-') display = display.substring(1);
        else display = "-" + display;
        updateValue();
        if (!editing) lift = true;
    }

    private void delete() {
        int digitsStart = exponentDigitsStart();
        if (digitsStart >= 0) {
            int last = display.length() - 1;
            display = display.substring(0, last) + (last == digitsStart ? "0" : "");
            updateValue();
            return;
        }
        if ("0".equals(display) || "-0".equals(display)) return;
        if (display.length() > 1) display = display.substring(0, display.length() - 1);
        else display = "0";
        updateValue();
    }

    private void push() {
        t = z;
        z = y;
        y = x;
    }

    /** Drop toward X. T is copied down and also left in place. */
    private void pop() {
        x = y;
        y = z;
        z = t;
    }

    private void unOp(double value) {
        x = value;
        editing = false;
        lift = true;
        updateDisplay();
    }

    private void binOp(double value) {
        pop();
        unOp(value);
    }

    private void constant(double value) {
        if (editing) {
            finishEntry();
            push();
        } else if (lift) {
            push();
        }
        x = value;
        editing = false;
        lift = true;
        updateDisplay();
    }

    /** Toward X, the HP-35 roll down. 4, 3, 2, 1 becomes 2 in X. */
    private void rotateDown() {
        double temp = x;
        x = y;
        y = z;
        z = t;
        t = temp;
    }

    /** Away from X. The reverse of roll down. */
    private void rotateUp() {
        double temp = t;
        t = z;
        z = y;
        y = x;
        x = temp;
    }

    private int displayLength() {
        int len = display.length();
        if (display.indexOf('.') >= 0) len--;
        return len;
    }

    private void updateDisplay() {
        display = format(x);
    }

    private void updateValue() {
        x = parse(display);
    }

    public static String format(double value) {
        if (Double.isNaN(value)) return "NaN";
        if (value == Double.POSITIVE_INFINITY) return "Infinity";
        if (value == Double.NEGATIVE_INFINITY) return "-Infinity";
        if (value == Math.rint(value) && !Double.isInfinite(value) && Math.abs(value) <= Long.MAX_VALUE) {
            return Long.toString((long) value);
        }
        return Double.toString(value);
    }

    private static double parse(String text) {
        if (text.isEmpty() || "-".equals(text) || ".".equals(text) || "-.".equals(text)) return 0;
        if ("NaN".equals(text)) return Double.NaN;
        if ("Infinity".equals(text)) return Double.POSITIVE_INFINITY;
        if ("-Infinity".equals(text)) return Double.NEGATIVE_INFINITY;
        try {
            return Double.parseDouble(text);
        } catch (NumberFormatException ignored) {
            return 0;
        }
    }

    private static double truncatingToInt32(double value) {
        if (Double.isNaN(value)) return 0;
        if (value >= Integer.MAX_VALUE) return Integer.MAX_VALUE;
        if (value <= Integer.MIN_VALUE) return Integer.MIN_VALUE;
        return (int) value;
    }

    private Snapshot snapshot() {
        Snapshot snap = new Snapshot();
        snap.x = x;
        snap.y = y;
        snap.z = z;
        snap.t = t;
        snap.display = display;
        snap.editing = editing;
        snap.hasTypedMantissa = hasTypedMantissa;
        snap.fMode = fMode;
        snap.gMode = gMode;
        snap.recMode = recMode;
        snap.fullscreen = fullscreen;
        snap.stored = stored;
        snap.progNum = progNum;
        snap.programs = copyPrograms(programs);
        snap.values = Arrays.copyOf(values, 4);
        snap.letterStore = letterStore;
        snap.letterRecall = letterRecall;
        snap.lift = lift;
        return snap;
    }

    private void restore(Snapshot snap) {
        x = snap.x;
        y = snap.y;
        z = snap.z;
        t = snap.t;
        display = snap.display;
        editing = snap.editing;
        hasTypedMantissa = snap.hasTypedMantissa;
        fMode = snap.fMode;
        gMode = snap.gMode;
        recMode = snap.recMode;
        fullscreen = snap.fullscreen;
        stored = snap.stored;
        progNum = snap.progNum;
        programs.clear();
        programs.addAll(copyPrograms(snap.programs));
        System.arraycopy(snap.values == null ? new double[4] : snap.values, 0, values, 0, 4);
        letterStore = snap.letterStore;
        letterRecall = snap.letterRecall;
        lift = snap.lift;
    }

    private boolean isStackToggle(Snapshot before, Snapshot after) {
        Snapshot previous = before.copy();
        Snapshot current = after.copy();
        previous.fullscreen = false;
        current.fullscreen = false;
        return sameCalculation(previous, current);
    }

    private boolean sameCalculation(Snapshot a, Snapshot b) {
        return a.x == b.x && a.y == b.y && a.z == b.z && a.t == b.t
                && a.display.equals(b.display)
                && a.editing == b.editing
                && a.hasTypedMantissa == b.hasTypedMantissa
                && a.fMode == b.fMode
                && a.gMode == b.gMode
                && a.recMode == b.recMode
                && a.fullscreen == b.fullscreen
                && a.stored == b.stored
                && a.progNum == b.progNum
                && a.letterStore == b.letterStore
                && a.letterRecall == b.letterRecall
                && a.lift == b.lift
                && samePrograms(a.programs, b.programs)
                && sameValues(a.values, b.values);
    }

    private static boolean sameValues(double[] a, double[] b) {
        if (a == null || b == null || a.length != b.length) return false;
        for (int i = 0; i < a.length; i++) {
            if (a[i] != b[i]) return false;
        }
        return true;
    }

    private void notifyListener() {
        if (listener != null) listener.onChanged();
    }

    public Snapshot exportState() {
        return snapshot();
    }

    /** Puts a saved face back. The undo tape stays empty, as it does on a fresh Apple launch. */
    public void restoreState(Snapshot snap) {
        if (snap == null || snap.programs == null) return;
        restore(snap);
        past.clear();
        future.clear();
        pastKeys.clear();
        futureKeys.clear();
        replayedKey = null;
    }

    public double getX() { return x; }
    public double getY() { return y; }
    public double getZ() { return z; }
    public double getT() { return t; }
    public String getDisplay() { return display; }
    public boolean isEditing() { return editing; }
    public boolean isFMode() { return fMode; }
    public boolean isGMode() { return gMode; }
    public boolean isRecMode() { return recMode; }
    public boolean isFullscreen() { return fullscreen; }
    public double getStored() { return stored; }
    public double getValue(int index) { return values[index]; }
    public boolean isLetterStore() { return letterStore; }
    public boolean isLetterRecall() { return letterRecall; }
    public int getProgNum() { return progNum; }
    public List<Integer> getProgram(int index) { return programs.get(index); }
    public Integer getReplayedKey() { return replayedKey; }
}
