// The watch calculator. Key codes are column + row * 5, the same numbers
// the watch stores in a programmable function. Kept in a function so the
// names do not collide with the page script.
(function () {

// One calculator step per paint, so a click can land between iterations.
function yieldFrame(work) {
  if (typeof requestAnimationFrame === "function") requestAnimationFrame(work);
  else setTimeout(work, 0);
}

const EXPONENT_KEY = 20;

const KEY_LABELS = {
  0: "÷",
  1: "7",
  2: "8",
  3: "9",
  4: "f",
  5: "×",
  6: "4",
  7: "5",
  8: "6",
  9: "g",
  10: "−",
  11: "1",
  12: "2",
  13: "3",
  14: "ENTER",
  15: "+",
  16: "0",
  17: "·",
  18: "+/−",
  [EXPONENT_KEY]: "EX",
};

function freshModel() {
  return {
    x: 0,
    y: 0,
    z: 0,
    t: 0,
    display: "0",
    editing: true,
    hasTypedMantissa: false,
    fMode: false,
    gMode: false,
    recMode: false,
    fullscreen: false,
    stored: 0,
    programs: [[], [], [], []],
    values: [0, 0, 0, 0],
    letterStore: false,
    letterRecall: false,
    // The next number raises the stack. ENTER, clear X, and store turn this
    // off, so that number replaces X instead. X and Y already hold their values.
    lift: true,
    progNum: 0,
  };
}

function cloneModel(model) {
  return {
    x: model.x,
    y: model.y,
    z: model.z,
    t: model.t,
    display: model.display,
    editing: model.editing,
    hasTypedMantissa: model.hasTypedMantissa,
    fMode: model.fMode,
    gMode: model.gMode,
    recMode: model.recMode,
    fullscreen: model.fullscreen,
    stored: model.stored,
    programs: model.programs.map((program) => program.slice()),
    values: model.values.slice(),
    letterStore: model.letterStore,
    letterRecall: model.letterRecall,
    lift: model.lift,
    progNum: model.progNum,
  };
}

function sameModel(a, b) {
  return (
    Object.is(a.x, b.x) &&
    Object.is(a.y, b.y) &&
    Object.is(a.z, b.z) &&
    Object.is(a.t, b.t) &&
    a.display === b.display &&
    a.editing === b.editing &&
    a.hasTypedMantissa === b.hasTypedMantissa &&
    a.fMode === b.fMode &&
    a.gMode === b.gMode &&
    a.recMode === b.recMode &&
    a.fullscreen === b.fullscreen &&
    Object.is(a.stored, b.stored) &&
    a.progNum === b.progNum &&
    a.letterStore === b.letterStore &&
    a.letterRecall === b.letterRecall &&
    a.lift === b.lift &&
    a.programs.every((program, index) => sameKeys(program, b.programs[index])) &&
    a.values.every((value, index) => Object.is(value, b.values[index]))
  );
}

function sameKeys(a, b) {
  return a.length === b.length && a.every((key, index) => key === b[index]);
}

class RPNCalculator {
  constructor() {
    const initial = freshModel();
    this.model = initial;
    this.state = cloneModel(initial);
    this.randomSource = () => Math.random();
    this.suppressPublish = false;
    this.playDepth = 0;
    this.past = [];
    this.future = [];
    this.pastKeys = [];
    this.futureKeys = [];
    this.tapeLimit = 400;
    this.previousRecording = [];
    this.replayedKey = null;
    this.repeatArmed = false;
    this.repeatJob = null;
    this.playFrames = [];
    this.suspendPlayback = false;
    this.idleWaiters = [];
    this.yieldRepeats = true;
    this.onUpdate = null;
  }

  cancelRepeat() {
    const job = this.repeatJob;
    if (job) {
      job.cancelled = true;
      this.repeatJob = null;
      if (job.finish) job.finish();
    }
    while (this.playFrames.length) {
      const frame = this.playFrames.pop();
      if (frame.insertingPrevious) this.state.recMode = frame.wasRecording;
      this.suppressPublish = frame.wasSuppressed;
      this.playDepth = Math.max(0, this.playDepth - 1);
    }
    this.suspendPlayback = false;
    this.settleIdle();
  }

  whenIdle() {
    if (!this.repeatJob && this.playFrames.length === 0) return Promise.resolve();
    return new Promise((resolve) => this.idleWaiters.push(resolve));
  }

  settleIdle() {
    if (this.repeatJob || this.playFrames.length > 0) return;
    const waiters = this.idleWaiters;
    this.idleWaiters = [];
    waiters.forEach((resolve) => resolve());
  }

  press(row, column) {
    if (row >= 0) this.cancelRepeat();
    this.applyKey(row, column);
  }

  applyKey(row, column) {
    const publish = !this.suppressPublish;
    // Opening the stack is not a key. A running macro keeps going so the
    // stack can be watched. A real key, even one that only closes the
    // stack, still stops it.
    // A display tap opens the stack even while a macro is mid-play.
    // Keys of that macro must still run, so only a real key closes it.
    const stackGesture = row < 0 || (this.playDepth === 0 && this.state.fullscreen && row >= 0);
    const armed = this.repeatArmed;
    this.repeatArmed = false;
    const before = cloneModel(this.state);
    const requested = column + row * 5;
    const code = requested === EXPONENT_KEY && (this.state.fMode || this.state.gMode) ? 14 : requested;
    // A macro played while recording is stored as the call. Its own keys
    // run with playDepth > 0 and must not be copied into the new macro.
    // Opening the stack is not a key, so it must not be stored either.
    if (this.state.recMode && this.playDepth === 0 && row >= 0) {
      this.state.programs[this.state.progNum].push(code);
    }
    if (stackGesture) {
      this.state.fullscreen = !this.state.fullscreen;
    } else if (this.state.letterStore || this.state.letterRecall) {
      this.finishLetter(code);
    } else if (this.state.fMode && this.state.gMode) {
      if (armed) this.fChord(code);
      else this.gChord(code);
    } else if (this.state.fMode) {
      const keep = code === 9 && !this.state.recMode;
      this.state.fMode = false;
      if (armed && code >= 0 && code <= 3) this.repeatProgram(code);
      else this.fShift(code);
      if (keep) this.state.fMode = true;
    } else if (this.state.gMode) {
      const keep = code === 4;
      this.state.gMode = false;
      this.gShift(code);
      if (keep) this.state.gMode = true;
    } else {
      this.primary(code);
    }
    if (publish) {
      if (this.state.display === "NaN") this.state.x = 0;
      if (!sameModel(before, this.state) && !isStackToggle(before, this.state)) {
        this.past.push(before);
        this.pastKeys.push(code);
        if (this.past.length > this.tapeLimit) {
          this.past.shift();
          this.pastKeys.shift();
        }
        this.future = [];
        this.futureKeys = [];
      }
      this.model = cloneModel(this.state);
    } else if (row < 0) {
      this.model = cloneModel(this.state);
    }
  }

  undo() {
    this.cancelRepeat();
    const previous = this.past.pop();
    if (!previous) return false;
    const key = this.pastKeys.pop();
    this.future.push(cloneModel(this.state));
    if (key !== undefined) this.futureKeys.push(key);
    const viewingStack = this.state.fullscreen;
    this.state = previous;
    this.state.fullscreen = viewingStack;
    this.model = cloneModel(this.state);
    this.replayedKey = key === undefined ? null : key;
    return true;
  }

  redo() {
    this.cancelRepeat();
    const next = this.future.pop();
    if (!next) return false;
    const key = this.futureKeys.pop();
    this.past.push(cloneModel(this.state));
    if (key !== undefined) this.pastKeys.push(key);
    const viewingStack = this.state.fullscreen;
    this.state = next;
    this.state.fullscreen = viewingStack;
    this.model = cloneModel(this.state);
    this.replayedKey = key === undefined ? null : key;
    return true;
  }

  pressDisplay() {
    this.press(-1, 0);
  }

  readout(register) {
    if (register === 1) return renderReadout(this.model.y, displayValue(this.model.y));
    if (register === 2) return renderReadout(this.model.z, displayValue(this.model.z));
    if (register === 3) return renderReadout(this.model.t, displayValue(this.model.t));
    if (register === 4) return renderReadout(this.model.stored, displayValue(this.model.stored));
    return renderReadout(this.model.x, this.model.display);
  }

  primary(key) {
    const state = this.state;
    switch (key) {
      case 0:
        this.binOp(state.y / state.x);
        break;
      case 1:
        this.digit("7");
        break;
      case 2:
        this.digit("8");
        break;
      case 3:
        this.digit("9");
        break;
      case 4:
        state.fMode = true;
        break;
      case 5:
        this.binOp(state.y * state.x);
        break;
      case 6:
        this.digit("4");
        break;
      case 7:
        this.digit("5");
        break;
      case 8:
        this.digit("6");
        break;
      case 9:
        state.gMode = true;
        break;
      case 10:
        this.binOp(state.y - state.x);
        break;
      case 11:
        this.digit("1");
        break;
      case 12:
        this.digit("2");
        break;
      case 13:
        this.digit("3");
        break;
      case 14:
      case 19:
        this.push();
        this.disableLift();
        break;
      case 15:
        this.binOp(state.y + state.x);
        break;
      case 16:
        this.digit("0");
        break;
      case 17:
        this.decimalPoint();
        break;
      case 18:
        this.changeSign();
        break;
      case EXPONENT_KEY:
        this.beginExponent();
        break;
      default:
        break;
    }
  }

  fShift(key) {
    const state = this.state;
    switch (key) {
      case 0:
        this.playRecording(0);
        break;
      case 1:
        this.playRecording(1);
        break;
      case 2:
        this.playRecording(2);
        break;
      case 3:
        this.playRecording(3);
        break;
      case 5:
        this.binOp(Math.pow(state.y, state.x));
        break;
      case 6:
        this.unOp(Math.exp(state.x));
        break;
      case 7:
        this.unOp(Math.pow(10, state.x));
        break;
      case 8:
        this.unOp(1 / state.x);
        break;
      case 9:
        if (state.recMode) this.stopRecording();
        else state.gMode = true;
        break;
      case 10:
        this.constant(this.randomSource());
        break;
      case 11:
        this.unOp(Math.sin(state.x));
        break;
      case 12:
        this.unOp(Math.cos(state.x));
        break;
      case 13:
        this.unOp(Math.tan(state.x));
        break;
      case 14:
      case 19:
        state.x = 0;
        this.updateDisplay();
        this.disableLift();
        break;
      case 15:
        state.stored = state.x;
        this.disableLift();
        break;
      case 16:
        this.constant(Math.E);
        break;
      case 17:
        {
          const temp = state.x;
          state.x = state.y;
          state.y = temp;
          this.updateDisplay();
          state.editing = false;
          state.lift = true;
        }
        break;
      case 18:
        this.rotateDown();
        this.updateDisplay();
        state.editing = false;
        state.lift = true;
        break;
      default:
        break;
    }
  }

  gShift(key) {
    const state = this.state;
    switch (key) {
      case 0:
        if (state.recMode) this.stopRecording();
        else this.startRecording(0);
        break;
      case 1:
        if (state.recMode) this.stopRecording();
        else this.startRecording(1);
        break;
      case 2:
        if (state.recMode) this.stopRecording();
        else this.startRecording(2);
        break;
      case 3:
        if (state.recMode) this.stopRecording();
        else this.startRecording(3);
        break;
      case 4:
        state.fMode = true;
        this.repeatArmed = true;
        break;
      case 5:
        this.binOp(Math.pow(state.y, 1 / state.x));
        break;
      case 6:
        this.unOp(Math.log(state.x));
        break;
      case 7:
        this.unOp(Math.log10(state.x));
        break;
      case 8:
        this.unOp(truncatingToInt32(state.x));
        break;
      case 10:
        this.unOp(Math.abs(state.x));
        break;
      case 11:
        this.unOp(Math.asin(state.x));
        break;
      case 12:
        this.unOp(Math.acos(state.x));
        break;
      case 13:
        this.unOp(Math.atan(state.x));
        break;
      case 14:
      case 19:
        this.delete();
        break;
      case 15:
        this.finishEntry();
        this.constant(state.stored);
        break;
      case 16:
        this.constant(Math.PI);
        break;
      case 17:
        this.constant(state.y);
        break;
      case 18:
        this.rotateUp();
        this.updateDisplay();
        state.editing = false;
        state.lift = true;
        break;
      default:
        break;
    }
  }

  // F is the active shift. A letter repeats, ST waits for a letter, and G
  // leaves both lights on with G now active.
  fChord(code) {
    if (code === 9 && !this.state.recMode) return;
    if (code === 4) {
      this.state.fMode = false;
      this.state.gMode = false;
      return;
    }
    this.state.fMode = false;
    this.state.gMode = false;
    if (code >= 0 && code <= 3) this.repeatProgram(code);
    else if (code === 15) {
      this.state.letterStore = true;
      this.state.fMode = true;
      this.state.gMode = true;
      this.finishEntry();
    } else this.fShift(code);
  }

  // G is the active shift. RC waits for a letter, and F leaves both lights
  // on with the repeat armed.
  gChord(code) {
    if (code === 4) {
      this.repeatArmed = true;
      return;
    }
    if (code === 9) {
      this.state.fMode = false;
      this.state.gMode = false;
      return;
    }
    this.state.fMode = false;
    this.state.gMode = false;
    if (code === 15) {
      this.state.letterRecall = true;
      this.state.fMode = true;
      this.state.gMode = true;
      this.finishEntry();
    } else this.gShift(code);
  }

  // A letter picks A–D. Store treats any other key as if G was never pressed.
  // Recall ignores that key.
  finishLetter(code) {
    const state = this.state;
    const letter = code >= 0 && code <= 3 ? code : -1;
    const storing = state.letterStore;
    state.letterStore = false;
    state.letterRecall = false;
    state.fMode = false;
    state.gMode = false;
    if (storing) {
      this.finishEntry();
      state.lift = false;
      if (letter >= 0) state.values[letter] = state.x;
      else {
        state.stored = state.x;
        this.primary(code);
      }
    } else if (letter >= 0) {
      this.finishEntry();
      this.constant(state.values[letter]);
    }
  }

  startRecording(program) {
    this.finishEntry();
    this.previousRecording = this.state.programs[program].slice();
    this.state.recMode = true;
    this.state.progNum = program;
    this.state.programs[program] = [];
  }

  stopRecording() {
    const program = this.state.programs[this.state.progNum];
    if (program.length >= 2) program.splice(program.length - 2, 2);
    else this.state.programs[this.state.progNum] = [];
    this.state.recMode = false;
  }

  repeatProgram(program) {
    this.finishEntry();
    const raw = this.state.x;
    // Infinity survives decrementing, so it only stops on cancellation.
    const count = raw > 0 ? Math.trunc(raw) : 0;
    this.pop();
    this.updateDisplay();
    const playOnce = () => {
      const wasRecording = this.state.recMode;
      this.state.recMode = false;
      this.playRecording(program);
      this.state.recMode = wasRecording;
    };
    if (count === 0 || (!this.yieldRepeats && count !== Infinity)) {
      for (let i = 0; i < count; i += 1) playOnce();
      return;
    }
    // A repeat met while another macro is playing yields too, so each inner
    // pass can draw before the next one starts.
    if (this.playDepth > 0) this.suspendPlayback = true;
    let finish = () => {};
    const done = new Promise((resolve) => {
      finish = () => resolve();
    });
    const job = { cancelled: false, done, finish };
    const cursor = { left: count };
    this.repeatJob = job;
    const step = () => {
      if (job.cancelled || this.repeatJob !== job) return;
      const framesBefore = this.playFrames.length;
      playOnce();
      if (job.cancelled) return;
      if (this.playFrames.length > framesBefore) {
        this.playFrames[this.playFrames.length - 1].after = () => this.finishRepeatStep(job, cursor, step);
        return;
      }
      this.finishRepeatStep(job, cursor, step);
    };
    yieldFrame(step);
  }

  finishRepeatStep(job, cursor, step) {
    if (job.cancelled) return;
    cursor.left -= 1;
    if (this.state.display === "NaN") this.state.x = 0;
    this.model = cloneModel(this.state);
    if (this.onUpdate) this.onUpdate();
    if (cursor.left <= 0) {
      if (this.repeatJob === job) this.repeatJob = null;
      job.finish();
      if (this.playFrames.length > 0) yieldFrame(() => this.resumePlayback());
      else this.settleIdle();
      return;
    }
    this.repeatJob = job;
    yieldFrame(step);
  }

  playRecording(program) {
    if (this.playDepth >= 16) return;
    let keys = this.state.programs[program].slice();
    const insertingPrevious = this.state.recMode && this.state.progNum === program;
    if (insertingPrevious) {
      const recorded = keys;
      if (
        recorded.length >= 2 &&
        recorded[recorded.length - 2] === 4 &&
        recorded[recorded.length - 1] === program
      ) {
        recorded.splice(recorded.length - 2, 2);
      }
      recorded.push(...this.previousRecording);
      this.state.programs[program] = recorded;
      keys = this.previousRecording.slice();
    }
    this.playDepth += 1;
    const frame = {
      keys,
      index: 0,
      wasSuppressed: this.suppressPublish,
      wasRecording: this.state.recMode,
      insertingPrevious,
      after: null,
    };
    this.suppressPublish = true;
    if (insertingPrevious) this.state.recMode = false;
    this.finishEntry();
    this.runKeys(frame);
  }

  // Runs a macro until it ends or a nested repeat needs the screen.
  // The rest of the keys resume after that repeat draws each pass.
  runKeys(frame) {
    while (frame.index < frame.keys.length) {
      const key = frame.keys[frame.index];
      frame.index += 1;
      this.applyKey(Math.floor(key / 5), key % 5);
      if (this.suspendPlayback) {
        this.suspendPlayback = false;
        this.playFrames.push(frame);
        return;
      }
    }
    if (frame.insertingPrevious) this.state.recMode = frame.wasRecording;
    this.suppressPublish = frame.wasSuppressed;
    this.playDepth = Math.max(0, this.playDepth - 1);
    if (frame.after) frame.after();
    else this.settleIdle();
  }

  resumePlayback() {
    if (this.playFrames.length === 0) {
      this.settleIdle();
      return;
    }
    this.runKeys(this.playFrames.pop());
  }

  // Keep the raw editing display in the existing snapshot and undo format.
  exponentStart() {
    return this.state.editing ? this.state.display.indexOf("E") : -1;
  }

  exponentDigitsStart() {
    const start = this.exponentStart() + 1;
    if (start === 0) return -1;
    return this.state.display[start] === "-" ? start + 1 : start;
  }

  beginExponent() {
    const state = this.state;
    if (this.exponentStart() >= 0) this.finishEntry();
    if (!state.editing) {
      if (state.lift) this.push();
      state.display = "1";
      state.editing = true;
      state.lift = true;
    } else if (!state.hasTypedMantissa && state.display === "0") {
      state.display = "1";
    }
    state.hasTypedMantissa = true;
    if (state.display.endsWith(".")) state.display = state.display.slice(0, -1);
    state.display += "E0";
    this.updateValue();
  }

  finishEntry() {
    if (this.exponentStart() >= 0) this.updateDisplay();
    this.state.editing = false;
  }

  // ENTER, clear X, and store leave a finished X. The next number replaces it.
  disableLift() {
    this.finishEntry();
    this.state.lift = false;
  }

  digit(character) {
    const state = this.state;
    const digitsStart = this.exponentDigitsStart();
    if (digitsStart >= 0) {
      const digits = state.display.slice(digitsStart).replace(/^0+/, "");
      if (digits.length < 3) {
        state.display = state.display.slice(0, digitsStart) + digits + character;
        this.updateValue();
      }
      return;
    }
    if (!state.editing) {
      if (state.lift) this.push();
      state.display = "";
      state.editing = true;
      state.lift = true;
    }
    state.hasTypedMantissa = true;
    if (state.display === "0") state.display = "";
    if (state.display === "-0") state.display = "-";
    if (displayLength(state.display) < 7) {
      state.display += character;
      this.updateValue();
    }
  }

  decimalPoint() {
    if (this.exponentStart() >= 0) return;
    const state = this.state;
    if (!state.editing) {
      if (state.lift) this.push();
      state.display = "0";
      state.editing = true;
      state.lift = true;
    }
    state.hasTypedMantissa = true;
    if (!state.display.includes(".")) {
      state.display += ".";
      this.updateValue();
    }
  }

  changeSign() {
    const state = this.state;
    const start = this.exponentStart() + 1;
    if (start > 0) {
      const exponent = state.display.slice(start);
      state.display = state.display.slice(0, start) + (exponent.startsWith("-") ? exponent.slice(1) : "-" + exponent);
      this.updateValue();
      return;
    }
    if (!state.display) return;
    if (state.display[0] === "-") state.display = state.display.slice(1);
    else state.display = "-" + state.display;
    this.updateValue();
    if (!state.editing) state.lift = true;
  }

  delete() {
    const state = this.state;
    const digitsStart = this.exponentDigitsStart();
    if (digitsStart >= 0) {
      const last = state.display.length - 1;
      state.display = state.display.slice(0, last) + (last === digitsStart ? "0" : "");
      this.updateValue();
      return;
    }
    if (state.display === "0" || state.display === "-0") return;
    if (state.display.length > 1) state.display = state.display.slice(0, -1);
    else state.display = "0";
    this.updateValue();
  }

  push() {
    const state = this.state;
    state.t = state.z;
    state.z = state.y;
    state.y = state.x;
  }

  // Drop toward X. T is copied down and also left in place.
  pop() {
    const state = this.state;
    state.x = state.y;
    state.y = state.z;
    state.z = state.t;
  }

  unOp(value) {
    this.state.x = value;
    this.state.editing = false;
    this.state.lift = true;
    this.updateDisplay();
  }

  binOp(value) {
    this.pop();
    this.unOp(value);
  }

  constant(value) {
    const state = this.state;
    if (state.editing) {
      this.finishEntry();
      this.push();
    } else if (state.lift) {
      this.push();
    }
    state.x = value;
    state.editing = false;
    state.lift = true;
    this.updateDisplay();
  }

  // Toward X, the HP-35 roll down. 4, 3, 2, 1 becomes 2 in X.
  rotateDown() {
    const state = this.state;
    const temp = state.x;
    state.x = state.y;
    state.y = state.z;
    state.z = state.t;
    state.t = temp;
  }

  // Away from X. The reverse of roll down.
  rotateUp() {
    const state = this.state;
    const temp = state.t;
    state.t = state.z;
    state.z = state.y;
    state.y = state.x;
    state.x = temp;
  }

  updateDisplay() {
    this.state.display = displayValue(this.state.x);
  }

  updateValue() {
    this.state.x = parseDisplay(this.state.display);
  }
}

function isStackToggle(before, after) {
  const previous = cloneModel(before);
  const current = cloneModel(after);
  previous.fullscreen = false;
  current.fullscreen = false;
  return sameModel(previous, current);
}

function displayLength(text) {
  return [...text].reduce((count, character) => count + (character === "." ? 0 : 1), 0);
}

function parseDisplay(text) {
  switch (text) {
    case "":
    case "-":
    case ".":
    case "-.":
      return 0;
    case "NaN":
      return NaN;
    case "Infinity":
      return Infinity;
    case "-Infinity":
      return -Infinity;
    default: {
      const value = Number(text);
      return Number.isNaN(value) ? 0 : value;
    }
  }
}

function truncatingToInt32(value) {
  if (Number.isNaN(value)) return 0;
  if (value >= 2147483647) return 2147483647;
  if (value <= -2147483648) return -2147483648;
  return Math.trunc(value);
}

function displayValue(value) {
  if (Number.isNaN(value)) return "NaN";
  if (value === Infinity) return "Infinity";
  if (value === -Infinity) return "-Infinity";
  if (Number.isSafeInteger(value)) return String(value);
  return javaToString(value);
}

function javaToString(value) {
  if (Number.isNaN(value)) return "NaN";
  if (value === Infinity) return "Infinity";
  if (value === -Infinity) return "-Infinity";
  if (value === 0) return Object.is(value, -0) ? "-0.0" : "0.0";
  const negative = value < 0;
  const { digits, exponent } = significand(String(Math.abs(value)));
  const body =
    exponent < -3 || exponent >= 7
      ? formatScientific(digits, exponent)
      : formatPlain(digits, exponent);
  return negative ? "-" + body : body;
}

function decimalFormatScientific(value) {
  if (Number.isNaN(value)) return "NaN";
  if (value === Infinity) return "Infinity";
  if (value === -Infinity) return "-Infinity";
  if (value === 0) return "0.0E0";
  const negative = value < 0;
  const { digits, exponent } = significand(String(Math.abs(value)));
  const rounded = roundHalfEven(digits, 6);
  const body = formatScientific(rounded.digits, exponent + rounded.exponentDelta);
  return negative ? "-" + body : body;
}

function significand(swift) {
  let text = swift.toLowerCase();
  if (text.startsWith("-")) text = text.slice(1);
  let exponent = 0;
  const marker = text.indexOf("e");
  if (marker >= 0) {
    exponent = Number.parseInt(text.slice(marker + 1), 10) || 0;
    text = text.slice(0, marker);
  }
  const pieces = text.split(".");
  const whole = pieces[0] || "0";
  const fraction = pieces.length > 1 ? pieces[1] : "";
  if (whole !== "0" && whole !== "") {
    const lead = whole.length - 1 + exponent;
    const digits = trimZeros(whole + fraction);
    return { digits: digits || "0", exponent: lead };
  }
  let zeros = 0;
  for (const character of fraction) {
    if (character === "0") zeros += 1;
    else break;
  }
  const digits = trimZeros(fraction.slice(zeros));
  return { digits: digits || "0", exponent: exponent - zeros - 1 };
}

function formatScientific(digits, exponent) {
  const safe = digits || "0";
  const lead = safe[0];
  let fraction = trimZeros(safe.slice(1));
  if (!fraction) fraction = "0";
  return `${lead}.${fraction}E${exponent}`;
}

function formatPlain(digits, exponent) {
  const safe = digits || "0";
  if (exponent >= 0) {
    const integerCount = exponent + 1;
    let all = safe;
    if (all.length < integerCount) all += "0".repeat(integerCount - all.length);
    const integerPart = all.slice(0, integerCount);
    let fraction = trimZeros(all.slice(integerCount));
    if (!fraction) fraction = "0";
    return `${integerPart}.${fraction}`;
  }
  const zeros = "0".repeat(Math.max(0, -exponent - 1));
  return `0.${zeros}${safe}`;
}

function roundHalfEven(digits, maxDigits) {
  if (digits.length <= maxDigits) return { digits, exponentDelta: 0 };
  const kept = [...digits.slice(0, maxDigits)];
  const rest = digits.slice(maxDigits);
  const next = rest[0] || "0";
  const nonzeroRemainder = [...rest.slice(1)].some((character) => character !== "0");
  let roundUp = false;
  if (next > "5") roundUp = true;
  else if (next === "5") {
    const last = Number(kept[kept.length - 1]);
    if (nonzeroRemainder || last % 2 === 1) roundUp = true;
  }
  if (!roundUp) return { digits: trimZeros(kept.join("")), exponentDelta: 0 };
  let index = kept.length - 1;
  while (index >= 0) {
    if (kept[index] < "9") {
      kept[index] = String.fromCharCode(kept[index].charCodeAt(0) + 1);
      return { digits: trimZeros(kept.join("")), exponentDelta: 0 };
    }
    kept[index] = "0";
    index -= 1;
  }
  return { digits: "1", exponentDelta: 1 };
}

function trimZeros(digits) {
  let text = digits;
  while (text.length > 1 && text.endsWith("0")) text = text.slice(0, -1);
  return text;
}

function renderReadout(value, text) {
  const cells = Array.from({ length: 7 }, () => ({ glyph: " ", dot: false }));
  const put = (index, glyph) => {
    if (index >= 0 && index < 7) cells[index].glyph = glyph;
  };
  if (text === "Infinity") {
    put(2, "1");
    put(3, "n");
    put(4, "f");
    put(5, "i");
    put(6, "n");
    return cells;
  }
  if (text === "-Infinity") {
    put(1, "-");
    put(2, "1");
    put(3, "n");
    put(4, "f");
    put(5, "i");
    put(6, "n");
    return cells;
  }
  if (text === "NaN") {
    put(2, "e");
    put(3, "r");
    put(4, "r");
    put(5, "o");
    put(6, "r");
    return cells;
  }

  let parts = text.split("E");
  let exponentLength = 0;
  let index = 6;
  if (parts.length > 1) {
    exponentLength = measuredExponent(parts[1]);
    index -= exponentLength;
  } else if (needsScientific(value)) {
    const scientific = decimalFormatScientific(value);
    parts = scientific.split("E");
    if (parts.length > 1) {
      exponentLength = measuredExponent(parts[1]);
      index -= exponentLength;
    }
  }

  let mantissa = parts[0];
  const maxLength = (mantissa.includes(".") ? 8 : 7) - exponentLength;
  if (mantissa.length > maxLength) {
    mantissa = stripTrailingFractionZeros(mantissa.slice(0, maxLength));
  }
  for (const character of [...mantissa].reverse()) {
    if (character === ".") {
      if (index >= 0 && index < 7) cells[index].dot = true;
    } else if (index >= 0 && index < 7) {
      cells[index].glyph = character;
      index -= 1;
    }
  }

  if (parts.length > 1) {
    let exponentIndex = 6;
    let negative = false;
    for (const character of [...parts[1]].reverse()) {
      if (character === "-") negative = true;
      put(exponentIndex, character === "-" ? " " : character);
      if (character === "-") cells[exponentIndex].glyph = "-";
      exponentIndex -= 1;
    }
    if (!negative) put(exponentIndex, " ");
  }
  return cells;
}

function stripTrailingFractionZeros(mantissa) {
  const dot = mantissa.indexOf(".");
  if (dot < 0) return mantissa;
  let fraction = mantissa.slice(dot + 1);
  while (fraction.endsWith("0")) fraction = fraction.slice(0, -1);
  if (!fraction) return mantissa.slice(0, dot);
  return mantissa.slice(0, dot) + "." + fraction;
}

function needsScientific(value) {
  return (
    value > 9999999 ||
    value < -999999 ||
    (value > 0 && value < 0.000001) ||
    (value < 0 && value > -0.00001)
  );
}

function measuredExponent(exponent) {
  let length = exponent.length;
  if (!exponent.startsWith("-")) length += 1;
  return length;
}

function debugText(cells) {
  return cells.map((cell) => (cell.glyph === " " ? " " : cell.glyph) + (cell.dot ? "." : "")).join("");
}

const TYPE_CODES = {
  0: 16,
  1: 11,
  2: 12,
  3: 13,
  4: 6,
  5: 7,
  6: 8,
  7: 1,
  8: 2,
  9: 3,
  ".": 17,
  "±": 18,
  "+": 15,
  "-": 10,
  "×": 5,
  "÷": 0,
  f: 4,
  g: 9,
  E: 14,
  e: EXPONENT_KEY,
};

function typeKeys(calc, keys) {
  for (const character of keys) {
    const key = TYPE_CODES[character];
    calc.press(Math.floor(key / 5), key % 5);
  }
}

const RetroRPN = {
  RPNCalculator,
  KEY_LABELS,
  EXPONENT_KEY,
  displayValue,
  renderReadout,
  debugText,
  typeKeys,
};

if (typeof window !== "undefined") window.RetroRPN = RetroRPN;
if (typeof module !== "undefined" && module.exports) module.exports = RetroRPN;
})();
