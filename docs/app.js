const { RPNCalculator, KEY_LABELS } = window.RetroRPN;

const KEYS = [
  { code: 0, title: "÷", f: "a", g: "", role: "normal" },
  { code: 1, title: "7", f: "b", g: "", role: "normal" },
  { code: 2, title: "8", f: "c", g: "", role: "normal" },
  { code: 3, title: "9", f: "d", g: "", role: "normal" },
  { code: 4, title: "f", f: "▶", g: "", role: "f" },
  { code: 5, title: "×", f: "yˣ", g: "ˣ√y", role: "normal" },
  { code: 6, title: "4", f: "eˣ", g: "ln", role: "normal" },
  { code: 7, title: "5", f: "10ˣ", g: "log", role: "normal" },
  { code: 8, title: "6", f: "1/x", g: "int", role: "normal" },
  { code: 9, title: "g", f: "●", g: "", role: "g" },
  { code: 10, title: "−", f: "ran", g: "abs", role: "normal" },
  { code: 11, title: "1", f: "sin", g: "⁻¹", role: "normal", tight: true },
  { code: 12, title: "2", f: "cos", g: "⁻¹", role: "normal", tight: true },
  { code: 13, title: "3", f: "tan", g: "⁻¹", role: "normal", tight: true },
  { code: 14, title: "ENTER", f: "Cx", g: "⌫", role: "enter", anchor: "leading" },
  { code: 15, title: "+", f: "ST", g: "RC", role: "normal", anchor: "trailing" },
  { code: 16, title: "0", f: "e", g: "π", role: "normal" },
  { code: 17, title: "·", f: "x↔y", g: "over", role: "normal" },
  { code: 18, title: "+/−", f: "R↓", g: "R↑", role: "normal" },
];

const PROGRAMS = [
  { name: "a", where: "÷" },
  { name: "b", where: "7" },
  { name: "c", where: "8" },
  { name: "d", where: "9" },
];

const GROUPS = [
  {
    title: "Warm-up",
    problems: [
      {
        title: "Reciprocal",
        tex: String.raw`\htmlClass{at2}{\dfrac{\htmlClass{at2}{1}}{\htmlClass{at1}{4}}}`,
        answer: "0.25",
        keys: "4f6",
      },
      {
        title: "Reciprocal of a sum",
        tex: String.raw`\htmlClass{at6}{\dfrac{\htmlClass{at6}{1}}{\htmlClass{at2}{\dfrac{\htmlClass{at2}{1}}{\htmlClass{at1}{3}}}\htmlClass{at5}{+}\htmlClass{at4}{\dfrac{\htmlClass{at4}{1}}{\htmlClass{at3}{6}}}}}`,
        answer: "2",
        keys: "3f66f6+f6",
      },
      {
        title: "A chain",
        tex: String.raw`\htmlClass{at4}{(}\htmlClass{at1}{3}\htmlClass{at4}{\times}\htmlClass{at3}{4}\htmlClass{at4}{)}\htmlClass{at9}{+}\htmlClass{at8}{\dfrac{\htmlClass{at5}{8}}{\htmlClass{at7}{4}}}`,
        answer: "14",
        keys: "3E4×8E4÷+",
      },
    ],
  },
  {
    title: "Scientific notation",
    problems: [
      {
        title: "A billion",
        tex: String.raw`\htmlClass{at13}{\htmlClass{at7}{1000000}\times\htmlClass{at12}{1000}=1.0\times10^{9}}\quad\htmlClass{at18}{\htmlClass{at15}{10}^{\htmlClass{at17}{9}}=1.0\times10^{9}}`,
        answer: "1.0 × 10⁹, either way",
        note: "A billion does not fit in seven digits. The display shows 1.0 with an exponent of 9.",
        keys: "1000000E1000×10E9f×",
      },
      {
        title: "A billionth",
        tex: String.raw`\htmlClass{at8}{\dfrac{\htmlClass{at1}{1}}{\htmlClass{at7}{\htmlClass{at4}{10}^{\htmlClass{at6}{9}}}}=1.0\times10^{-9}}\quad\htmlClass{at14}{\htmlClass{at10}{10}^{\htmlClass{at13}{-}\htmlClass{at12}{9}}=1.0\times10^{-9}}`,
        answer: "1.0 × 10⁻⁹, either way",
        note: "Too small for seven digits as well. The display shows 1.0 with an exponent of −9.",
        keys: "1E10E9f×÷10E9±f×",
      },
    ],
  },
  {
    title: "From the HP-35 handbook",
    problems: [
      {
        title: "1. Add, then multiply",
        tex: String.raw`\htmlClass{at6}{\htmlClass{at4}{(}\htmlClass{at1}{3}\htmlClass{at4}{+}\htmlClass{at3}{4}\htmlClass{at4}{)}\htmlClass{at6}{\times}\htmlClass{at5}{5}}`,
        answer: "35",
        keys: "3E4+5×",
      },
      {
        title: "2. Multiply, then add",
        tex: String.raw`\htmlClass{at7}{\htmlClass{at1}{3}\htmlClass{at7}{+}\htmlClass{at6}{(}\htmlClass{at3}{4}\htmlClass{at6}{\times}\htmlClass{at5}{5}\htmlClass{at6}{)}=23}\quad\htmlClass{at13}{\htmlClass{at11}{(}\htmlClass{at8}{4}\htmlClass{at11}{\times}\htmlClass{at10}{5}\htmlClass{at11}{)}\htmlClass{at13}{+}\htmlClass{at12}{3}=23}`,
        answer: "23, then 23",
        note: "Addition is symmetric, so the 3 can come before the product or after it.",
        keys: "3E4E5×+4E5×3+",
      },
      {
        title: "3. Three sums",
        tex: String.raw`\htmlClass{at4}{(}\htmlClass{at1}{3}\htmlClass{at4}{+}\htmlClass{at3}{4}\htmlClass{at4}{)}\htmlClass{at9}{\cdot}\htmlClass{at8}{(}\htmlClass{at5}{5}\htmlClass{at8}{+}\htmlClass{at7}{6}\htmlClass{at8}{)}\htmlClass{at14}{\cdot}\htmlClass{at13}{(}\htmlClass{at10}{7}\htmlClass{at13}{+}\htmlClass{at12}{8}\htmlClass{at13}{)}`,
        answer: "1,155",
        keys: "3E4+5E6+×7E8+×",
      },
      {
        title: "4. Two sums of quotients",
        tex: String.raw`\htmlClass{at15}{\Biggl(}\htmlClass{at6}{\dfrac{\htmlClass{at1}{4}\htmlClass{at4}{\times}\htmlClass{at3}{5}}{\htmlClass{at5}{2}}}\htmlClass{at15}{+}\htmlClass{at14}{\dfrac{\htmlClass{at7}{2}\htmlClass{at8}{4}}{\htmlClass{at10}{3}\htmlClass{at13}{\times}\htmlClass{at12}{4}}}\htmlClass{at15}{\Biggr)}\htmlClass{at31}{\times}\htmlClass{at30}{\Biggl(}\htmlClass{at23}{\dfrac{\htmlClass{at16}{1}\htmlClass{at17}{8}}{\htmlClass{at19}{2}\htmlClass{at22}{+}\htmlClass{at21}{4}}}\htmlClass{at30}{+}\htmlClass{at29}{\dfrac{\htmlClass{at24}{2}\htmlClass{at27}{+}\htmlClass{at26}{6}}{\htmlClass{at28}{4}}}\htmlClass{at30}{\Biggr)}`,
        answer: "60",
        keys: "4E5×2÷24E3E4×÷+18E2E4+÷2E6+4÷+×",
      },
      {
        title: "5. Sine of π/6",
        tex: String.raw`\htmlClass{at4}{\sin}\htmlClass{at3}{\dfrac{\htmlClass{at1}{\pi}}{\htmlClass{at2}{6}}}`,
        answer: "0.499999",
        keys: "g06÷f1",
      },
      {
        title: "6. A spherical angle",
        tex: String.raw`\htmlClass{at29}{\arccos\htmlClass{at28}{(\htmlClass{at11}{\htmlClass{at4}{\cos}\htmlClass{at3}{\dfrac{\htmlClass{at1}{\pi}}{\htmlClass{at2}{4}}}\htmlClass{at11}{\cdot}\htmlClass{at10}{\cos}\htmlClass{at9}{\dfrac{\htmlClass{at7}{\htmlClass{at5}{5}\htmlClass{at6}{\pi}}}{\htmlClass{at8}{6}}}}\htmlClass{at28}{+}\htmlClass{at22}{\htmlClass{at15}{\sin}\htmlClass{at14}{\dfrac{\htmlClass{at12}{\pi}}{\htmlClass{at13}{4}}}\htmlClass{at22}{\cdot}\htmlClass{at21}{\sin}\htmlClass{at20}{\dfrac{\htmlClass{at18}{\htmlClass{at16}{5}\htmlClass{at17}{\pi}}}{\htmlClass{at19}{6}}}}\htmlClass{at27}{\cdot}\htmlClass{at26}{\cos}\htmlClass{at25}{\dfrac{\htmlClass{at23}{\pi}}{\htmlClass{at24}{3}}})}}`,
        answer: "2.021496",
        keys: "g04÷f25g0×6÷f2×g04÷f15g0×6÷f1×g03÷f2×+g2",
      },
      {
        title: "7a. A right triangle",
        tex: String.raw`\theta=\htmlClass{at3}{\dfrac{\htmlClass{at1}{\pi}}{\htmlClass{at2}{6}}},\ R=\htmlClass{at5}{5},\quad \htmlClass{at8}{x}=\htmlClass{at5}{R}\htmlClass{at8}{\htmlClass{at7}{\cos}\htmlClass{at6}{\theta}},\ \htmlClass{at12}{y}=\htmlClass{at8}{x}\htmlClass{at12}{\htmlClass{at11}{\tan}\htmlClass{at10}{\theta}}`,
        answer: "x = 4.330127, y = 2.5",
        keys: "g06÷f+5g+f2×Eg+f3×f.",
      },
      {
        title: "7b. The same triangle, backwards",
        tex: String.raw`x=\htmlClass{at3}{4},\ y=\htmlClass{at1}{3},\quad \htmlClass{at5}{\theta}=\htmlClass{at5}{\arctan}\htmlClass{at4}{\dfrac{\htmlClass{at1}{3}}{\htmlClass{at3}{4}}},\ R=\htmlClass{at10}{\dfrac{\htmlClass{at8}{3}}{\htmlClass{at10}{\htmlClass{at7}{\sin}\htmlClass{at5}{\theta}}}}`,
        answer: "θ = 0.643501, R = 5",
        keys: "3E4÷g3Ef13f.÷",
      },
      {
        title: "8. Five feet, three inches, in centimeters",
        tex: String.raw`\htmlClass{at12}{\left(\htmlClass{at7}{\htmlClass{at5}{\left(\htmlClass{at1}{5}\htmlClass{at5}{\times}\htmlClass{at3}{1}\htmlClass{at4}{2}\right)}\htmlClass{at7}{+}\htmlClass{at6}{3}}\right)\htmlClass{at12}{\times}\htmlClass{at8}{2}\htmlClass{at9}{.}\htmlClass{at10}{5}\htmlClass{at11}{4}\,\mathrm{cm}}`,
        answer: "160.02",
        keys: "5E12×3+2.54×",
      },
      {
        title: "9. Return after tax",
        tex: String.raw`\htmlClass{at30}{\dfrac{\htmlClass{at10}{(\htmlClass{at1}{2}\htmlClass{at2}{6}\htmlClass{at3}{7}\htmlClass{at4}{2}\htmlClass{at10}{-}\htmlClass{at6}{2}\htmlClass{at7}{3}\htmlClass{at8}{4}\htmlClass{at9}{1})}\htmlClass{at17}{\times}\htmlClass{at16}{(\htmlClass{at11}{1}\htmlClass{at16}{-}\htmlClass{at13}{0.}\htmlClass{at14}{3}\htmlClass{at15}{5})}\htmlClass{at20}{\times}\htmlClass{at18}{1}\htmlClass{at19}{2}}{\htmlClass{at21}{2}\htmlClass{at22}{3}\htmlClass{at23}{4}\htmlClass{at24}{1}\htmlClass{at29}{\times}\htmlClass{at26}{6}\htmlClass{at27}{.}\htmlClass{at28}{5}}}\htmlClass{at34}{\times}\htmlClass{at31}{1}\htmlClass{at32}{0}\htmlClass{at33}{0}`,
        answer: "16.9671",
        keys: "2672E2341-1E.35-×12×2341E6.5×÷100×",
      },
    ],
  },
  {
    title: "Memory",
    problems: [
      {
        title: "When the stack is full",
        tex: String.raw`\htmlClass{at41}{\htmlClass{at19}{\bigl(\htmlClass{at9}{(}\htmlClass{at1}{1}\htmlClass{at4}{+}\htmlClass{at3}{2}\htmlClass{at9}{)}\htmlClass{at9}{\times}\htmlClass{at8}{(}\htmlClass{at5}{3}\htmlClass{at8}{+}\htmlClass{at7}{4}\htmlClass{at8}{)}\htmlClass{at19}{+}\htmlClass{at18}{(}\htmlClass{at10}{5}\htmlClass{at13}{+}\htmlClass{at12}{6}\htmlClass{at18}{)}\htmlClass{at18}{\times}\htmlClass{at17}{(}\htmlClass{at14}{7}\htmlClass{at17}{+}\htmlClass{at16}{8}\htmlClass{at17}{)}\bigr)}\htmlClass{at41}{\times}\htmlClass{at39}{\bigl(\htmlClass{at29}{(}\htmlClass{at21}{2}\htmlClass{at24}{+}\htmlClass{at23}{3}\htmlClass{at29}{)}\htmlClass{at29}{\times}\htmlClass{at28}{(}\htmlClass{at25}{4}\htmlClass{at28}{+}\htmlClass{at27}{5}\htmlClass{at28}{)}\htmlClass{at39}{+}\htmlClass{at38}{(}\htmlClass{at30}{6}\htmlClass{at33}{+}\htmlClass{at32}{7}\htmlClass{at38}{)}\htmlClass{at38}{\times}\htmlClass{at37}{(}\htmlClass{at34}{8}\htmlClass{at37}{+}\htmlClass{at36}{9}\htmlClass{at37}{)}\bigr)}}`,
        answer: "49,476",
        keys: "1E2+3E4+×5E6+7E8+×+f+2E3+4E5+×6E7+8E9+×+g+×",
      },
    ],
  },
  {
    title: "Macros",
    problems: [
      {
        title: "Fahrenheit to Celsius",
        tex: String.raw`\htmlClass{at11}{\dfrac{\htmlClass{at7}{(\htmlClass{at3}{\htmlClass{at1}{2}\htmlClass{at2}{1}\htmlClass{at3}{2}}\htmlClass{at7}{-}\htmlClass{at6}{\htmlClass{at5}{3}\htmlClass{at6}{2}})}\htmlClass{at9}{\times}\htmlClass{at8}{5}}{\htmlClass{at10}{9}}=100}\quad\htmlClass{at16}{\htmlClass{at15}{\htmlClass{at13}{2}\htmlClass{at14}{1}\htmlClass{at15}{2}}=100}\quad\htmlClass{at19}{\htmlClass{at18}{\htmlClass{at17}{3}\htmlClass{at18}{2}}=0}\quad\htmlClass{at24}{\htmlClass{at23}{\htmlClass{at20}{7}\htmlClass{at21}{0}\htmlClass{at22}{.}\htmlClass{at23}{7}}=21.5}\quad\htmlClass{at29}{\htmlClass{at28}{\htmlClass{at25}{9}\htmlClass{at26}{8}\htmlClass{at27}{.}\htmlClass{at28}{6}}=37}`,
        answer: "100, 0, 21.5, 37",
        keys: "212g832-5×9÷g8212f832f870.7f898.6f8",
      },
      {
        title: "Celsius to Fahrenheit",
        tex: String.raw`\htmlClass{at11}{\htmlClass{at3}{\htmlClass{at1}{1}\htmlClass{at2}{0}\htmlClass{at3}{0}}\htmlClass{at6}{\times}\htmlClass{at8}{\dfrac{\htmlClass{at5}{9}}{\htmlClass{at7}{5}}}\htmlClass{at11}{+}\htmlClass{at10}{\htmlClass{at9}{3}\htmlClass{at10}{2}}=212}\quad\htmlClass{at16}{\htmlClass{at15}{\htmlClass{at13}{1}\htmlClass{at14}{0}\htmlClass{at15}{0}}=212}\quad\htmlClass{at18}{\htmlClass{at17}{0}=32}\quad\htmlClass{at23}{\htmlClass{at22}{\htmlClass{at19}{2}\htmlClass{at20}{1}\htmlClass{at21}{.}\htmlClass{at22}{5}}=70.7}\quad\htmlClass{at26}{\htmlClass{at25}{\htmlClass{at24}{3}\htmlClass{at25}{7}}=98.6}`,
        answer: "212, 32, 70.7, 98.6",
        keys: "100g89×5÷32+g8100f80f821.5f837f8",
      },
      {
        title: "A 15% tip",
        tex: String.raw`\htmlClass{at22}{\htmlClass{at4}{\htmlClass{at1}{4}\htmlClass{at2}{.}\htmlClass{at3}{8}\htmlClass{at4}{5}}\htmlClass{at10}{\times}\htmlClass{at8}{\htmlClass{at6}{.}\htmlClass{at7}{1}\htmlClass{at8}{5}}=0.73}\quad\htmlClass{at24}{5.58}\qquad\htmlClass{at30}{\htmlClass{at29}{\htmlClass{at25}{1}\htmlClass{at26}{4}\htmlClass{at27}{.}\htmlClass{at28}{7}\htmlClass{at29}{5}}=2.21}\quad\htmlClass{at31}{16.96}\qquad\htmlClass{at37}{\htmlClass{at36}{\htmlClass{at32}{2}\htmlClass{at33}{7}\htmlClass{at34}{.}\htmlClass{at35}{8}\htmlClass{at36}{5}}=4.18}\quad\htmlClass{at38}{32.03}\qquad\htmlClass{at44}{\htmlClass{at43}{\htmlClass{at39}{3}\htmlClass{at40}{6}\htmlClass{at41}{.}\htmlClass{at42}{7}\htmlClass{at43}{5}}=5.51}\quad\htmlClass{at45}{42.26}`,
        answer: "0.73, then 5.58; 2.21, then 16.96; 4.18, then 32.03; 5.51, then 42.26",
        keys: "4.85g÷.15g.×100×.5+g6100÷g÷+14.75f÷+27.85f÷+36.75f÷+",
      },
      {
        title: "Count to a million",
        tex: String.raw`\htmlClass{at3}{\htmlClass{at2}{1}+}\qquad\htmlClass{at13}{\htmlClass{at12}{\htmlClass{at6}{1}\htmlClass{at7}{0}\htmlClass{at8}{0}\htmlClass{at9}{0}\htmlClass{at10}{0}\htmlClass{at11}{0}\htmlClass{at12}{0}}\to 1000000}`,
        answer: "1000000",
        note: "It counts to a million on its own. Press any key to stop it.",
        keys: "g÷1+g÷fE1000000gf÷",
      },
      {
        title: "Roll a die",
        tex: String.raw`\htmlClass{at7}{\operatorname{int}(\htmlClass{at2}{\mathrm{ran}}\htmlClass{at4}{\times}\htmlClass{at3}{6}\htmlClass{at6}{+}\htmlClass{at5}{1})}\quad\htmlClass{at9}{1\text{–}6}\quad\htmlClass{at10}{1\text{–}6}\quad\htmlClass{at11}{1\text{–}6}\quad\htmlClass{at12}{1\text{–}6}\quad\htmlClass{at13}{1\text{–}6}\quad\htmlClass{at16}{c=\htmlClass{at15}{d}+}\quad\htmlClass{at22}{\htmlClass{at21}{\htmlClass{at19}{1}\htmlClass{at20}{0}\htmlClass{at21}{0}}\to 100\text{–}600}`,
        answer: "five rolls from 1 to 6, then a sum from 100 to 600",
        note: "C rolls the die and adds it. A hundred plays of C sums a hundred rolls.",
        keys: "g9f-6×1+g6g9f9f9f9f9f9g8f9+g8fE100gf8",
      },
      {
        title: "Iterated cosine",
        tex: String.raw`\htmlClass{at1}{1}\to\htmlClass{at3}{0.540302}\to\htmlClass{at5}{0.857553}\to\htmlClass{at6}{0.654289}\qquad\htmlClass{at9}{\htmlClass{at8}{\htmlClass{at7}{2}\htmlClass{at8}{9}}\to 0.739085}`,
        answer: "1, then 0.540302, then 0.857553, then 0.654289, then 0.739085",
        keys: "f2g÷f2g÷f÷f÷29gf÷",
      },
      {
        title: "e to the minus x",
        tex: String.raw`\htmlClass{at2}{1}\to\htmlClass{at5}{0.367879}\to\htmlClass{at7}{0.6922}\to\htmlClass{at8}{0.500473}\qquad\htmlClass{at11}{\htmlClass{at10}{\htmlClass{at9}{2}\htmlClass{at10}{1}}\to 0.567143}`,
        answer: "1, then 0.367879, then 0.6922, then 0.500473, then 0.567143",
        keys: "±f4g÷±f4g÷f÷f÷21gf÷",
      },
      {
        title: "The golden ratio",
        tex: String.raw`\htmlClass{at5}{\htmlClass{at4}{\htmlClass{at3}{\htmlClass{at1}{1}\to 1,1}\to 1,1,1}\to 1,2}\to\htmlClass{at9}{3}\qquad\htmlClass{at15}{\htmlClass{at12}{\htmlClass{at11}{2}\htmlClass{at12}{0}}\to 1.618033\approx\varphi}`,
        answer: "1, 2, then 3, then 1.618033",
        keys: "1EEE+g÷f.g.+g÷20gf÷f.÷",
      },
      {
        title: "Square root by iteration",
        tex: String.raw`\htmlClass{at1}{1}\to\htmlClass{at9}{1.5}\to\htmlClass{at11}{1.416666}\to\htmlClass{at12}{1.414215}\to\htmlClass{at13}{1.414213\approx\sqrt{2}}`,
        answer: "1.5, then 1.416666, then 1.414215, then 1.414213",
        keys: "1g÷Ef62×+2÷g÷f÷f÷f÷",
      },
    ],
  },
];

const GRID = {
  0: [1, 1], 1: [2, 1], 2: [3, 1], 3: [4, 1], 4: [5, 1],
  5: [1, 2], 6: [2, 2], 7: [3, 2], 8: [4, 2], 9: [5, 2],
  10: [1, 3], 11: [2, 3], 12: [3, 3], 13: [4, 3], 14: [5, 3],
  15: [1, 4], 16: [2, 4], 17: [3, 4], 18: [4, 4],
};

const calc = new RPNCalculator();
calc.onUpdate = () => render();
const buttons = {};
const held = new Set();
let flashed = null;
let flashTimer = 0;
let showsPortrait = false;

const watch = document.getElementById("watch");
const face = document.createElement("div");
face.className = "face";
const lcd = document.createElement("div");
lcd.className = "lcd";
lcd.setAttribute("role", "button");
lcd.tabIndex = 0;
lcd.setAttribute("aria-label", "display, show the stack");
const keypad = document.createElement("div");
keypad.className = "keypad";
face.append(lcd, keypad);
watch.append(face);

for (const spec of KEYS) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "key" + (spec.role === "f" || spec.role === "g" ? " shift" : "") + (spec.code === 18 ? " sign" : "");
  if (spec.role === "f") button.classList.add("f");
  if (spec.role === "g") button.classList.add("g");
  const [column, row] = GRID[spec.code];
  button.style.gridColumn = String(column);
  button.style.gridRow = spec.code === 14 ? "3 / span 2" : String(row);
  button.setAttribute("aria-label", labelFor(spec));
  const inner = document.createElement("span");
  inner.className = "key-face";
  if (spec.role === "enter") {
    const word = document.createElement("span");
    word.className = "enter-word";
    for (const character of "ENTER") {
      const line = document.createElement("span");
      line.textContent = character;
      word.append(line);
    }
    inner.append(word);
  } else {
    const title = document.createElement("span");
    title.className = "title";
    title.textContent = spec.title;
    inner.append(title);
  }
  const legend = document.createElement("span");
  legend.className = "legend" + (spec.anchor ? " " + spec.anchor : "") + (spec.tight ? " tight" : "");
  if (spec.role === "f") {
    legend.append(cuePair([playTriangle(), iterateMark()]));
  } else if (spec.role === "g") {
    legend.append(cuePair([recordDot(), stopSquare()]));
  } else {
    if (spec.f) {
      const fLab = document.createElement("span");
      fLab.className = "f-lab" + (programColor(spec) ? " program" : "");
      fLab.textContent = spec.f;
      legend.append(fLab);
    }
    if (spec.g) {
      const gLab = document.createElement("span");
      gLab.className = "g-lab";
      gLab.textContent = spec.g;
      legend.append(gLab);
    }
  }
  inner.append(legend);
  button.append(inner);
  button.addEventListener("pointerdown", (event) => {
    event.preventDefault();
    held.add(spec.code);
    syncKeys();
    userPress(spec.code);
  });
  const release = () => {
    held.delete(spec.code);
    syncKeys();
  };
  button.addEventListener("pointerup", release);
  button.addEventListener("pointerleave", release);
  button.addEventListener("pointercancel", release);
  keypad.append(button);
  buttons[spec.code] = button;
}

lcd.addEventListener("pointerdown", (event) => {
  event.preventDefault();
  if (showsPortrait) {
    showsPortrait = false;
    if (calc.model.fullscreen) calc.pressDisplay();
  } else if (calc.model.fullscreen && event.target.closest(".credit-name")) {
    showsPortrait = true;
  } else {
    calc.pressDisplay();
  }
  render();
});

function svgEl(viewBox) {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("viewBox", viewBox);
  svg.setAttribute("aria-hidden", "true");
  return svg;
}

function cuePair(marks) {
  const pair = document.createElement("span");
  pair.className = "cue";
  pair.setAttribute("aria-hidden", "true");
  marks.forEach((mark) => pair.append(mark));
  return pair;
}

function filled(tag, attrs, color) {
  const el = document.createElementNS("http://www.w3.org/2000/svg", tag);
  Object.entries(attrs).forEach(([key, value]) => el.setAttribute(key, value));
  el.setAttribute("fill", color);
  return el;
}

function playTriangle() {
  const svg = svgEl("0 0 9 10");
  svg.append(filled("path", { d: "M0 0.3 L8.4 5 L0 9.7 Z" }, "var(--program)"));
  return svg;
}

function iterateMark() {
  const svg = svgEl("0 0 12 10");
  svg.append(filled("path", { d: "M0 0.3 L4.8 5 L0 9.7 Z M5.6 0.3 L10.4 5 L5.6 9.7 Z" }, "var(--g-shadow)"));
  return svg;
}

function recordDot() {
  const svg = svgEl("0 0 10 10");
  svg.append(filled("circle", { cx: "5", cy: "5", r: "4.35" }, "var(--program)"));
  return svg;
}

function stopSquare() {
  const svg = svgEl("0 0 10 10");
  svg.append(filled("rect", { x: "0.7", y: "0.7", width: "8.6", height: "8.6" }, "var(--f-shadow)"));
  return svg;
}

function programColor(spec) {
  if (spec.role === "enter") return false;
  return spec.role === "f" || spec.role === "g" || !spec.g;
}

function labelFor(spec) {
  if (spec.code === 4) return "f, play, iterate";
  if (spec.code === 9) return "g, record, stop";
  if (spec.code === 14) return "enter, f clear x, g delete";
  if (spec.code === 15) return "plus, f store, g recall";
  const parts = [spec.title];
  if (spec.f) parts.push("f " + spec.f);
  if (spec.g) parts.push("g " + spec.g);
  return parts.join(", ");
}

function layoutWatch() {
  const size = watch.clientWidth;
  const inset = Math.max(12, size * 0.045);
  const gap = Math.max(1.5, (size - inset * 2) * 0.008) + 1;
  const width = Math.max(1, size - inset * 2);
  const keyWidth = (width - gap * 4) / 5;
  const keypadWidth = keyWidth * 5 + gap * 4;
  const full = calc.model.fullscreen;
  const labelWidth = full ? Math.min(28, Math.max(16, keypadWidth * 0.09)) : 0;
  const fullCell = Math.max(1, (keypadWidth - 6 - 13 - 2) / 7);
  const cellWidth = Math.max(1, fullCell - labelWidth / 7);
  const digitNatural = cellWidth * (53 / 43);
  const displayHeight = fullCell * (53 / 43) + 8;
  const stackHeight = Math.max(1, size - inset * 2);
  const lcdHeight = full ? stackHeight : displayHeight;
  const creditH = full ? Math.max(14, keypadWidth * 0.075) : 0;
  const rows = full ? 5 : 1;
  const rowArea = Math.max(1, lcdHeight - 4 - creditH);
  const digitH = Math.min(digitNatural, (rowArea - (rows - 1)) / rows);
  face.style.left = (size - keypadWidth) / 2 + "px";
  face.style.width = keypadWidth + "px";
  face.style.top = inset + "px";
  face.style.gap = full ? "0px" : gap + "px";
  face.style.height = (full ? stackHeight : Math.max(1, size - inset * 2)) + "px";
  lcd.style.height = lcdHeight + "px";
  lcd.style.flex = "none";
  lcd.style.setProperty("--cell-w", cellWidth + "px");
  lcd.style.setProperty("--digit-h", digitH + "px");
  lcd.style.setProperty("--label-w", labelWidth + "px");
  lcd.style.setProperty("--label-size", Math.min(13, Math.max(8, labelWidth * 0.46)) + "px");
  lcd.style.setProperty("--credit-h", creditH + "px");
  lcd.style.setProperty("--credit-size", Math.max(7, keypadWidth * 0.042) + "px");
  keypad.style.display = full ? "none" : "grid";
  keypad.style.height = Math.max(1, size - inset * 2 - displayHeight - gap) + "px";
  keypad.style.gap = gap + "px";
}

function glyphSource(glyph) {
  if (glyph === " " || glyph === "") return "face/display_none.png";
  if (glyph === "-") return "face/display_neg.png";
  if (glyph >= "0" && glyph <= "9") return "face/display" + glyph + ".png";
  return "face/display_" + glyph + ".png";
}

// Held so the browser keeps the decoded sprites after the zeroed screen has painted.
const preloadedFaces = [];

function preloadFaces() {
  const names = [
    "display0", "display1", "display2", "display3", "display4",
    "display5", "display6", "display7", "display8", "display9",
    "display_none", "display_neg", "display_e", "display_f", "display_i",
    "display_n", "display_o", "display_r", "dot",
    "sym_editing", "sym_editing_none", "sym_f", "sym_f_none",
    "sym_g", "sym_g_none", "sym_rec", "sym_rec_none",
  ];
  const urls = [];
  for (const name of names) {
    urls.push("face/" + name + ".png");
    if (!name.startsWith("sym_")) urls.push("face/ink/" + name + ".png");
  }
  for (const src of urls) {
    const image = new Image();
    image.decoding = "async";
    preloadedFaces.push(image);
    image.src = src;
    if (image.decode) image.decode().catch(() => {});
  }
}

function sameFace(img, src) {
  const current = img.getAttribute("src") || "";
  return current === src || current.endsWith(src);
}

function syncRows(root, rows, ink) {
  const digitRows = root.querySelectorAll(".lcd-row");
  for (let register = 0; register < rows; register += 1) {
    const readout = calc.readout(register);
    const cells = digitRows[register].querySelectorAll(".cell");
    for (let index = 0; index < readout.length; index += 1) {
      const cell = cells[index];
      const shown = readout[index];
      let src = glyphSource(shown.glyph);
      if (ink) src = src.replace("face/", "face/ink/");
      const glyph = cell.querySelector(".glyph");
      if (!sameFace(glyph, src)) glyph.src = src;
      let dot = cell.querySelector(".dot");
      if (shown.dot) {
        const dotSrc = ink ? "face/ink/dot.png" : "face/dot.png";
        if (!dot) {
          dot = document.createElement("img");
          dot.className = "dot";
          dot.alt = "";
          cell.append(dot);
        }
        if (!sameFace(dot, dotSrc)) dot.src = dotSrc;
      } else if (dot) {
        dot.remove();
      }
    }
    if (!ink && register === 0) {
      const images = digitRows[register].querySelectorAll(".annunciators img");
      const names = annunciatorNames();
      for (let index = 0; index < names.length; index += 1) {
        const src = "face/" + names[index] + ".png";
        if (images[index] && !sameFace(images[index], src)) images[index].src = src;
      }
    }
  }
}

function renderLcd() {
  if (!calc.model.fullscreen) showsPortrait = false;
  const view = showsPortrait ? "portrait" : (calc.model.fullscreen ? "stack" : "x");
  lcd.setAttribute("aria-label", showsPortrait ? "picture, close the display" : "display, show the stack");
  if (lcd.dataset.view !== view) {
    lcd.replaceChildren();
    lcd.dataset.view = view;
    if (showsPortrait) {
      const canvas = document.createElement("canvas");
      canvas.className = "portrait";
      lcd.append(canvas);
      drawPortrait(canvas);
      return;
    }
    lcd.append(lcdStack(calc.model.fullscreen ? 5 : 1));
    if (calc.model.fullscreen) {
      const credit = document.createElement("div");
      credit.className = "credit";
      const version = document.createElement("span");
      version.textContent = "RetroRPN 1.6";
      const author = document.createElement("span");
      author.className = "credit-name";
      author.textContent = "Ashley Nathan Feniello";
      credit.append(version, author);
      lcd.append(credit);
    }
    return;
  }
  if (!showsPortrait) syncRows(lcd, calc.model.fullscreen ? 5 : 1, false);
}

function portraitLevels() {
  const raw = atob(window.FACE_PORTRAIT);
  const levels = new Uint8Array(80 * 80);
  for (let i = 0; i < levels.length; i += 1) {
    const shift = (3 - (i % 4)) * 2;
    levels[i] = (raw.charCodeAt(i >> 2) >> shift) & 3;
  }
  return levels;
}

function drawPortrait(canvas) {
  const scale = window.devicePixelRatio || 1;
  const cssW = Math.max(1, canvas.clientWidth);
  const cssH = Math.max(1, canvas.clientHeight);
  canvas.width = Math.max(1, Math.floor(cssW * scale));
  canvas.height = Math.max(1, Math.floor(cssH * scale));
  const ctx = canvas.getContext("2d");
  const pitch = Math.min(canvas.width, canvas.height) / 80;
  const gap = Math.max(scale, pitch * 0.2);
  const side = Math.max(scale, pitch - gap);
  const ox = (canvas.width - pitch * 80) / 2;
  const oy = (canvas.height - pitch * 80) / 2;
  const colors = ["#60695b", "#4a5045", "#282828"];
  const levels = portraitLevels();
  for (let i = 0; i < levels.length; i += 1) {
    const x = i % 80;
    const y = (i / 80) | 0;
    ctx.fillStyle = colors[levels[i]];
    ctx.fillRect(ox + x * pitch, oy + y * pitch, side, side);
  }
}

function annunciatorNames() {
  const model = calc.model;
  return [
    model.recMode ? "sym_rec" : "sym_rec_none",
    model.fMode ? "sym_f" : "sym_f_none",
    model.gMode ? "sym_g" : "sym_g_none",
    model.editing ? "sym_editing" : "sym_editing_none",
  ];
}

function syncKeys() {
  for (const code of Object.keys(buttons)) {
    const id = Number(code);
    buttons[id].classList.toggle("down", held.has(id) || flashed === id);
  }
}

function clearHighlights() {
  flashed = null;
  clearTimeout(flashTimer);
  syncKeys();
}

function flash(code) {
  flashed = code;
  syncKeys();
  clearTimeout(flashTimer);
  flashTimer = setTimeout(() => {
    if (flashed === code) clearHighlights();
  }, 450);
}

const STACK_LABELS = ["x", "y", "z", "t", "ST"];

function lcdStack(rows, ink) {
  const wrap = document.createElement("div");
  wrap.className = "lcd-rows";
  for (let register = 0; register < rows; register += 1) {
    const row = document.createElement("div");
    row.className = "lcd-row";
    const digits = document.createElement("div");
    digits.className = "digits";
    for (const cell of calc.readout(register)) {
      const box = document.createElement("div");
      box.className = "cell";
      const src = glyphSource(cell.glyph);
      const glyph = document.createElement("img");
      glyph.className = "glyph";
      glyph.alt = "";
      glyph.src = ink ? src.replace("face/", "face/ink/") : src;
      box.append(glyph);
      if (cell.dot) {
        const dot = document.createElement("img");
        dot.className = "dot";
        dot.alt = "";
        dot.src = ink ? "face/ink/dot.png" : "face/dot.png";
        box.append(dot);
      }
      digits.append(box);
    }
    if (rows > 1) {
      const label = document.createElement("div");
      label.className = "lcd-label";
      label.textContent = STACK_LABELS[register];
      row.append(label);
    }
    row.append(digits);
    if (!ink && (register === 0 || rows > 1)) {
      const marks = document.createElement("div");
      marks.className = "annunciators";
      if (register === 0) {
        for (const name of annunciatorNames()) {
          const image = document.createElement("img");
          image.alt = "";
          image.src = "face/" + name + ".png";
          marks.append(image);
        }
      }
      row.append(marks);
    }
    wrap.append(row);
  }
  return wrap;
}

function fitReadout(readout) {
  const style = getComputedStyle(readout);
  const pad = (parseFloat(style.paddingLeft) || 0) + (parseFloat(style.paddingRight) || 0);
  const width = Math.max(1, (readout.clientWidth || 280) - pad);
  const labelWidth = Math.min(28, Math.max(16, width * 0.09));
  const cellWidth = Math.max(1, (width - labelWidth) / 7);
  readout.style.setProperty("--cell-w", cellWidth + "px");
  readout.style.setProperty("--digit-h", cellWidth * (53 / 43) + "px");
  readout.style.setProperty("--label-w", labelWidth + "px");
  readout.style.setProperty("--label-size", Math.min(13, Math.max(8, labelWidth * 0.46)) + "px");
}

let statePane = "stack";

function renderState() {
  const model = calc.model;
  const root = document.getElementById("state");
  const scroll = root.scrollTop;
  let card = root.querySelector(":scope > .state-card");
  if (!card) {
    card = document.createElement("section");
    card.className = "panel state-card";
    const tabs = document.createElement("div");
    tabs.className = "state-tabs";
    tabs.setAttribute("role", "tablist");
    for (const pane of [["stack", "Stack"], ["registers", "Registers"]]) {
      const tab = document.createElement("button");
      tab.type = "button";
      tab.className = "state-tab";
      tab.dataset.pane = pane[0];
      tab.setAttribute("role", "tab");
      tab.textContent = pane[1];
      tab.addEventListener("pointerdown", (event) => {
        event.preventDefault();
        if (statePane === pane[0]) return;
        statePane = pane[0];
        renderState();
      });
      tabs.append(tab);
    }
    const body = document.createElement("div");
    body.className = "state-body";
    card.append(tabs, body);
    root.append(card);
  }
  for (const tab of card.querySelectorAll(".state-tab")) {
    tab.setAttribute("aria-selected", tab.dataset.pane === statePane ? "true" : "false");
  }
  const registers = card.querySelector('.state-tab[data-pane="registers"]');
  let live = registers.querySelector(".state-tab-live");
  if (model.recMode && !live) {
    live = document.createElement("span");
    live.className = "state-tab-live";
    live.setAttribute("aria-hidden", "true");
    registers.append(live);
  } else if (!model.recMode && live) {
    live.remove();
  }
  const body = card.querySelector(".state-body");
  if (statePane === "stack") {
    let readout = body.querySelector(":scope > .stack-readout");
    if (!readout) {
      body.replaceChildren();
      body.dataset.pane = "stack";
      readout = document.createElement("div");
      readout.className = "stack-readout";
      body.append(readout);
      readout.append(lcdStack(5, true));
      fitReadout(readout);
    }
    syncRows(readout, 5, true);
  } else {
    const signature = model.programs.map((program) => program.join(",")).join("|")
      + (model.recMode ? ":" + model.progNum : "");
    if (body.dataset.pane !== "registers" || body.dataset.signature !== signature) {
      body.replaceChildren();
      body.dataset.pane = "registers";
      body.dataset.signature = signature;
      const macros = document.createElement("div");
      macros.className = "macros";
      model.programs.forEach((program, index) => {
        const row = document.createElement("div");
        row.className = "macro";
        const title = document.createElement("div");
        title.className = "macro-name" + (model.recMode && model.progNum === index ? " live" : "");
        title.textContent = PROGRAMS[index].name;
        const keys = document.createElement("div");
        keys.className = "keys";
        if (program.length === 0) {
          const empty = document.createElement("span");
          empty.className = "empty";
          empty.textContent = "empty";
          keys.append(empty);
        } else {
          for (const token of foldCodes(program)) appendTokenChips(keys, token);
        }
        row.append(title, keys);
        macros.append(row);
      });
      body.append(macros);
    }
  }
  root.scrollTop = scroll;
}

// f or g and the key after it are one function. The stored codes stay as pressed.
const F_FN = {
  0: [["a", "program"]],
  1: [["b", "program"]],
  2: [["c", "program"]],
  3: [["d", "program"]],
  5: [["yˣ", "f"]],
  6: [["eˣ", "f"]],
  7: [["10ˣ", "f"]],
  8: [["1/x", "f"]],
  10: [["ran", "f"]],
  11: [["sin", "f"]],
  12: [["cos", "f"]],
  13: [["tan", "f"]],
  14: [["Cx", "f"]],
  15: [["ST", "f"]],
  16: [["e", "f"]],
  17: [["x↔y", "f"]],
  18: [["R↓", "f"]],
};

const G_FN = {
  0: [["rec", "g"], ["a", "program"]],
  1: [["rec", "g"], ["b", "program"]],
  2: [["rec", "g"], ["c", "program"]],
  3: [["rec", "g"], ["d", "program"]],
  4: [["f", "f"]],
  5: [["ˣ√y", "g"]],
  6: [["ln", "g"]],
  7: [["log", "g"]],
  8: [["int", "g"]],
  10: [["abs", "g"]],
  11: [["sin", "f"], ["⁻¹", "g"]],
  12: [["cos", "f"], ["⁻¹", "g"]],
  13: [["tan", "f"], ["⁻¹", "g"]],
  14: [["⌫", "g"]],
  15: [["RC", "g"]],
  16: [["π", "g"]],
  17: [["over", "g"]],
  18: [["R↑", "g"]],
};

function foldCodes(codes) {
  const tokens = [];
  for (let i = 0; i < codes.length; i += 1) {
    const code = codes[i];
    // g then f holds f, so the key after it is the f function.
    // g then f then a letter iterates that macro. The arrow is the g-f key, then the letter.
    if (code === 9 && codes[i + 1] === 4 && F_FN[codes[i + 2]]) {
      const fn = F_FN[codes[i + 2]];
      tokens.push({
        codes: [code, codes[i + 1], codes[i + 2]],
        parts: fn,
        tight: fn.some((part) => part[0] === "⁻¹"),
        iterate: codes[i + 2] <= 3,
      });
      i += 2;
      continue;
    }
    const table = code === 4 ? F_FN : code === 9 ? G_FN : null;
    if (table) {
      const fn = i + 1 < codes.length ? table[codes[i + 1]] : null;
      if (fn) {
        tokens.push({
          codes: [code, codes[i + 1]],
          parts: fn,
          tight: fn.some((part) => part[0] === "⁻¹"),
        });
        i += 1;
      }
      continue;
    }
    tokens.push({ codes: [code], parts: plainParts(code) });
  }
  return tokens;
}

function plainParts(code) {
  if (code === 4) return [["f", "f"]];
  if (code === 9) return [["g", "g"]];
  return [[KEY_LABELS[code] || String(code), "plain"]];
}

function functionChip(token, tag = "span") {
  const node = document.createElement(tag);
  node.type = tag === "button" ? "button" : undefined;
  const tones = new Set(token.parts.map((part) => part[1]));
  const plain = token.parts.length === 1 && tones.has("plain");
  node.className = "chip" + (plain ? "" : " fn") + (token.tight ? " tight" : "");
  if (plain) {
    node.textContent = token.parts[0][0];
    return node;
  }
  for (const [text, tone] of token.parts) {
    const part = document.createElement("span");
    part.className = "part " + tone;
    part.textContent = text;
    node.append(part);
  }
  return node;
}

// The iterate mark stands for g then f, and the letter is the key after it.
function appendTokenChips(parent, token, tag = "span", onClick, step) {
  const chips = token.iterate ? [iterateChip(tag), functionChip(token, tag)] : [functionChip(token, tag)];
  for (const chip of chips) {
    if (step !== undefined) chip.dataset.step = String(step);
    if (onClick) chip.addEventListener("click", onClick);
    parent.append(chip);
  }
}

function iterateChip(tag) {
  const node = document.createElement(tag);
  node.type = tag === "button" ? "button" : undefined;
  node.className = "chip mark";
  node.setAttribute("aria-label", "iterate");
  const mark = iterateMark();
  mark.classList.add("iterate");
  node.append(mark);
  return node;
}

let selected = null;
let stepIndex = 0;
let showingIndex = -1;
let playTimer = 0;
let chordTimer = 0;
let stepGeneration = 0;
let chordMark = null;

function renderProblems() {
  const root = document.getElementById("problems");
  root.replaceChildren();
  for (const group of GROUPS) {
    const section = document.createElement("section");
    section.className = "group";
    const heading = document.createElement("h2");
    heading.textContent = group.title;
    section.append(heading);
    for (const problem of group.problems) {
      section.append(problemCard(problem));
    }
    root.append(section);
  }
}

function problemCard(problem) {
  const card = document.createElement("article");
  card.className = "problem";
  card._problem = problem;
  const title = document.createElement("h3");
  title.textContent = problem.title;
  const expr = document.createElement("div");
  expr.className = "expr";
  if (problem.tex && window.katex) {
    try {
      katex.render(problem.tex, expr, { throwOnError: false, displayMode: true, trust: true, strict: "ignore" });
    } catch (error) {
      expr.textContent = problem.tex;
    }
  } else {
    expr.textContent = problem.tex || "";
  }
  card.append(title, expr);
  if (problem.note) {
    const note = document.createElement("p");
    note.className = "note";
    note.textContent = problem.note;
    card.append(note);
  }
  const answer = document.createElement("p");
  answer.className = "answer";
  answer.append("Result ");
  const strong = document.createElement("strong");
  strong.textContent = problem.answer;
  answer.append(strong);
  card.append(answer);

  const script = document.createElement("div");
  script.className = "script";
  const tokens = foldCodes(codesFor(problem.keys));
  tokens.forEach((token, index) => {
    const onClick = () => {
      stopPlay();
      if (selected === problem && stepIndex === index + 1) {
        syncProblems();
        return;
      }
      selected = problem;
      replaceCalc();
      stepIndex = 0;
      const generation = stepGeneration;
      const run = async () => {
        while (stepIndex <= index) {
          if (generation !== stepGeneration) return;
          takeStep();
          await calc.whenIdle();
        }
        if (generation !== stepGeneration) return;
        render();
        syncProblems();
      };
      run();
    };
    appendTokenChips(script, token, "button", onClick, index);
  });
  card.append(script);

  const actions = document.createElement("div");
  actions.className = "actions";
  const play = document.createElement("button");
  play.type = "button";
  play.className = "primary";
  play.addEventListener("click", () => {
    if (playTimer && selected === problem) {
      stopPlay();
      render();
      syncProblems();
      return;
    }
    if (selected !== problem) choose(problem);
    if (stepIndex === 0 || stepIndex >= tokens.length) {
      replaceCalc();
      stepIndex = 0;
      render();
    }
    startPlay();
  });
  const step = document.createElement("button");
  step.type = "button";
  step.textContent = "Step";
  step.addEventListener("click", () => {
    stopPlay();
    if (selected !== problem) choose(problem);
    if (stepIndex >= tokens.length) {
      syncProblems();
      return;
    }
    beginChord();
  });
  const reset = document.createElement("button");
  reset.type = "button";
  reset.textContent = "Reset";
  reset.addEventListener("click", () => {
    stopPlay();
    selected = problem;
    replaceCalc();
    stepIndex = 0;
    render();
    syncProblems();
  });
  actions.append(play, step, reset);
  card.append(actions);
  return card;
}

function syncProblems() {
  for (const card of document.querySelectorAll(".problem")) {
    const problem = card._problem;
    const on = problem === selected;
    card.classList.toggle("selected", on);
    const current = showingIndex >= 0 ? showingIndex : stepIndex - 1;
    card.querySelectorAll(".script .chip").forEach((chip) => {
      chip.classList.toggle("now", on && Number(chip.dataset.step) === current);
    });
    for (const node of card.querySelectorAll(".expr .katex-html [class]")) {
      for (const name of node.classList) {
        const match = /^at(\d+)$/.exec(name);
        if (match) node.classList.toggle("done", on && stepIndex >= Number(match[1]));
      }
    }
    const play = card.querySelector(".actions .primary");
    if (play) {
      play.textContent = playTimer && on ? "Stop" : "Play";
    }
  }
}

function choose(problem) {
  if (selected === problem) return;
  selected = problem;
  stepIndex = 0;
  replaceCalc();
}

function codesFor(keys) {
  const codes = [];
  for (const character of keys) {
    const code = {
      0: 16, 1: 11, 2: 12, 3: 13, 4: 6, 5: 7, 6: 8, 7: 1, 8: 2, 9: 3,
      ".": 17, "±": 18, "+": 15, "-": 10, "×": 5, "÷": 0, f: 4, g: 9, E: 14,
    }[character];
    codes.push(code);
  }
  return codes;
}

function takeStep() {
  if (!selected) return;
  const tokens = foldCodes(codesFor(selected.keys));
  if (stepIndex >= tokens.length) return;
  const token = tokens[stepIndex];
  stepIndex += 1;
  for (const code of token.codes) calc.press(Math.floor(code / 5), code % 5);
  flash(token.codes[token.codes.length - 1]);
}

function beginChord(done) {
  if (!selected) {
    if (done) done(false);
    return;
  }
  const tokens = foldCodes(codesFor(selected.keys));
  if (stepIndex >= tokens.length) {
    if (done) done(false);
    return;
  }
  const codes = tokens[stepIndex].codes;
  const generation = stepGeneration;
  chordMark = {
    stepIndex,
    pastLength: calc.past.length,
    pastKeyLength: calc.pastKeys.length,
    state: JSON.parse(JSON.stringify(calc.state)),
  };
  showingIndex = stepIndex;
  let index = 0;
  const down = () => {
    if (generation !== stepGeneration) return;
    const code = codes[index];
    calc.press(Math.floor(code / 5), code % 5);
    const last = index === codes.length - 1;
    const proceed = () => {
      if (generation !== stepGeneration) return;
      if (last) {
        stepIndex += 1;
        showingIndex = -1;
        chordMark = null;
      }
      flash(code);
      render();
      syncProblems();
      const hold = codes.length > 1 && !last ? 280 : 200;
      chordTimer = setTimeout(up, hold);
    };
    Promise.resolve(calc.whenIdle()).then(proceed);
  };
  const up = () => {
    if (generation !== stepGeneration) return;
    clearHighlights();
    index += 1;
    if (index < codes.length) {
      chordTimer = setTimeout(down, 220);
      return;
    }
    if (done) done(true);
  };
  down();
}

function abortChord() {
  if (!chordMark) return;
  calc.past.length = chordMark.pastLength;
  calc.pastKeys.length = chordMark.pastKeyLength;
  calc.future = [];
  calc.futureKeys = [];
  calc.state = chordMark.state;
  calc.model = JSON.parse(JSON.stringify(chordMark.state));
  stepIndex = chordMark.stepIndex;
  showingIndex = -1;
  chordMark = null;
}

function startPlay() {
  stopPlay();
  const generation = stepGeneration;
  playTimer = 1;
  syncProblems();
  const tick = () => {
    if (generation !== stepGeneration || !selected) return;
    const tokens = foldCodes(codesFor(selected.keys));
    if (stepIndex >= tokens.length) {
      stopPlay();
      render();
      syncProblems();
      return;
    }
    beginChord(() => {
      if (generation !== stepGeneration) return;
      playTimer = setTimeout(tick, 160);
    });
  };
  tick();
}

function stopPlay() {
  calc.cancelRepeat();
  stepGeneration += 1;
  clearTimeout(playTimer);
  clearTimeout(chordTimer);
  playTimer = 0;
  abortChord();
  showingIndex = -1;
  clearHighlights();
}

function replaceCalc() {
  calc.cancelRepeat();
  calc.repeatArmed = false;
  const fresh = new RPNCalculator();
  calc.state = fresh.state;
  calc.model = fresh.model;
  calc.past = [];
  calc.future = [];
  calc.pastKeys = [];
  calc.futureKeys = [];
  calc.previousRecording = [];
  calc.replayedKey = null;
  calc.playDepth = 0;
}

function userPress(code) {
  stopPlay();
  calc.press(Math.floor(code / 5), code % 5);
  render();
}

function undoOne() {
  stopPlay();
  if (!calc.undo()) return;
  if (calc.replayedKey != null) flash(calc.replayedKey);
  render();
}

function redoOne() {
  stopPlay();
  if (!calc.redo()) return;
  if (calc.replayedKey != null) flash(calc.replayedKey);
  render();
}

function render() {
  layoutWatch();
  renderLcd();
  renderState();
}

const KEYBOARD = {
  0: 16, 1: 11, 2: 12, 3: 13, 4: 6, 5: 7, 6: 8, 7: 1, 8: 2, 9: 3,
  ".": 17, ",": 17, "+": 15, "-": 10, "*": 5, "/": 0, x: 5, Enter: 14, f: 4, g: 9,
};

document.addEventListener("keydown", (event) => {
  if (event.metaKey || event.ctrlKey || event.altKey) {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "z") {
      event.preventDefault();
      if (event.shiftKey) redoOne();
      else undoOne();
    }
    return;
  }
  const target = event.target;
  if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")) return;
  const code = KEYBOARD[event.key];
  if (code === undefined) return;
  event.preventDefault();
  userPress(code);
  flash(code);
});

const crown = document.getElementById("crown");
let crownY = null;
let crownAccum = 0;
crown.addEventListener("pointerdown", (event) => {
  crownY = event.clientY;
  crownAccum = 0;
  crown.setPointerCapture(event.pointerId);
});
crown.addEventListener("pointermove", (event) => {
  if (crownY == null) return;
  crownAccum += event.clientY - crownY;
  crownY = event.clientY;
  while (crownAccum >= 16) {
    crownAccum -= 16;
    undoOne();
  }
  while (crownAccum <= -16) {
    crownAccum += 16;
    redoOne();
  }
});
const crownEnd = () => {
  crownY = null;
};
crown.addEventListener("pointerup", crownEnd);
crown.addEventListener("pointercancel", crownEnd);

let wheelAccum = 0;
watch.addEventListener("wheel", (event) => {
  event.preventDefault();
  wheelAccum += event.deltaY;
  while (wheelAccum >= 40) {
    wheelAccum -= 40;
    undoOne();
  }
  while (wheelAccum <= -40) {
    wheelAccum += 40;
    redoOne();
  }
}, { passive: false });

new ResizeObserver(() => {
  layoutWatch();
  const canvas = lcd.querySelector(".portrait");
  if (canvas) drawPortrait(canvas);
  const readout = document.querySelector(".stack-readout");
  if (readout) fitReadout(readout);
}).observe(watch);
render();
renderProblems();
syncProblems();
requestAnimationFrame(() => preloadFaces());
