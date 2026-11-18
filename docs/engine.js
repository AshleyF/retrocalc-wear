// The watch calculator. Key codes are column + row * 5, the same numbers
// the watch stores in a programmable function. Kept in a function so the
// names do not collide with the page script.
(function () {

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
};

function freshModel() {
  return {
    x: 0,
    y: 0,
    z: 0,
    t: 0,
    display: "0",
    editing: true,
    fMode: false,
    gMode: false,
    recMode: false,
    fullscreen: false,
    stored: 0,
    programs: [[], [], [], []],
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
    fMode: model.fMode,
    gMode: model.gMode,
    recMode: model.recMode,
    fullscreen: model.fullscreen,
    stored: model.stored,
    programs: model.programs.map((program) => program.slice()),
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
    a.fMode === b.fMode &&
    a.gMode === b.gMode &&
    a.recMode === b.recMode &&
    a.fullscreen === b.fullscreen &&
    Object.is(a.stored, b.stored) &&
    a.progNum === b.progNum &&
    a.programs.every((program, index) => sameKeys(program, b.programs[index]))
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
  }

  press(row, column) {
    const publish = !this.suppressPublish;
    const before = cloneModel(this.state);
    const code = column + row * 5;
    if (this.state.recMode) {
      this.state.programs[this.state.progNum].push(code);
    }
    if (this.state.fullscreen || row < 0) {
      this.state.fullscreen = !this.state.fullscreen;
    } else if (this.state.fMode) {
      this.state.fMode = false;
      this.fShift(code);
    } else if (this.state.gMode) {
      this.state.gMode = false;
      this.gShift(code);
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
    }
  }

  undo() {
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
        if (!state.editing) this.push();
        state.editing = false;
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
        state.editing = false;
        break;
      case 15:
        state.stored = state.x;
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
        }
        break;
      case 18:
        this.rotateDown();
        this.updateDisplay();
        state.editing = false;
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
        break;
      default:
        break;
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
    const wasSuppressed = this.suppressPublish;
    const wasRecording = this.state.recMode;
    this.suppressPublish = true;
    if (insertingPrevious) this.state.recMode = false;
    this.finishEntry();
    for (const key of keys) this.press(Math.floor(key / 5), key % 5);
    if (insertingPrevious) this.state.recMode = wasRecording;
    this.suppressPublish = wasSuppressed;
    this.playDepth -= 1;
  }

  finishEntry() {
    this.state.editing = false;
  }

  digit(character) {
    const state = this.state;
    if (!state.editing) {
      this.push();
      state.display = "";
      state.editing = true;
    }
    if (state.display === "0") state.display = "";
    if (state.display === "-0") state.display = "-";
    if (displayLength(state.display) < 7) {
      state.display += character;
      this.updateValue();
    }
  }

  decimalPoint() {
    const state = this.state;
    if (!state.editing) {
      this.push();
      state.x = 0;
      this.updateDisplay();
      state.editing = true;
    }
    if (!state.display.includes(".")) {
      state.display += ".";
      this.updateValue();
    }
  }

  changeSign() {
    const state = this.state;
    if (!state.display) return;
    if (state.display[0] === "-") state.display = state.display.slice(1);
    else state.display = "-" + state.display;
    this.updateValue();
  }

  delete() {
    const state = this.state;
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

  pop() {
    const state = this.state;
    state.x = state.y;
    state.y = state.z;
    state.z = state.t;
    state.t = 0;
  }

  unOp(value) {
    this.state.x = value;
    this.state.editing = false;
    this.updateDisplay();
  }

  binOp(value) {
    this.pop();
    this.unOp(value);
  }

  constant(value) {
    this.push();
    this.state.x = value;
    this.state.editing = false;
    this.updateDisplay();
  }

  rotateDown() {
    const state = this.state;
    const temp = state.t;
    state.t = state.z;
    state.z = state.y;
    state.y = state.x;
    state.x = temp;
  }

  rotateUp() {
    const state = this.state;
    const temp = state.x;
    state.x = state.y;
    state.y = state.z;
    state.z = state.t;
    state.t = temp;
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
  displayValue,
  renderReadout,
  debugText,
  typeKeys,
};

if (typeof window !== "undefined") window.RetroRPN = RetroRPN;
if (typeof module !== "undefined" && module.exports) module.exports = RetroRPN;
})();
