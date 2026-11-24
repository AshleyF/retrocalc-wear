"""Regenerate the web, watchOS, and Wear OS display assets from the paths below."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "docs/face"
APPLE = ROOT / "apple/RetroRPN Watch App/Assets.xcassets"
WEAR = ROOT / "wear/src/main/res/drawable"

LCD = "#747f6e"
ACTIVE = "#282828"
INACTIVE = "#6c7667"
INK = "#ced4c6"
LED = "#301013"
LED_ACTIVE = "#ff382e"
LED_INACTIVE = "#4a191d"

# The original digit cell is 35 × 53. Clockwise from the top, then the middle.
# The slant and unequal chamfers are part of the original face.
SEGMENTS = {
    "a": "M8 1H28.5Q29.5 1 31 2.8L26 7.5H13L7 2.3Q6.7 1.4 8 1Z",
    "b": "M32 3.1 34.7 5.5 32.8 22.4 30.6 24.5 25.8 20.6 27.1 7.8Z",
    "c": "M29.8 25.6 32.6 28 30.7 46.6 28.2 49 23.5 44.5 25.1 30Z",
    "d": "M8.6 45.1H23.1L28 49.5Q27.3 51.6 25.4 51.8H5.5Q3.6 51.7 3 50.1Z",
    "e": "M3.8 25.6 9 30 7 44.7 2.2 49.4 0 46.8 1.9 28Z",
    "f": "M5.8 3.1 11 7.7 9.1 20.6 4.8 24 2.6 21.8 4.4 5.1Z",
    "g": "M9.9 21.3H25.3L29.8 24.7 25.1 28.6H9.1L5.4 24.4Z",
}
GLYPHS = {
    "display0": "abcdef",
    "display1": "bc",
    "display2": "abdeg",
    "display3": "abcdg",
    "display4": "bcfg",
    "display5": "acdfg",
    "display6": "acdefg",
    "display7": "abc",
    "display8": "abcdefg",
    "display9": "abcdfg",
    "display_e": "adefg",
    "display_f": "aefg",
    "display_i": "e",
    "display_n": "ceg",
    "display_o": "cdeg",
    "display_r": "eg",
    "display_neg": "g",
    "display_none": "",
}
DOT = "M3.2 0.7H8.3Q9.5 0.7 9.2 2L8.5 6.2Q8.4 7.2 7.4 7.2H2.3Q1.2 7.2 1.4 6L2.1 1.8Q2.3 0.7 3.2 0.7Z"
MARKS = {
    "sym_rec": (10, "M8 5A3 3 0 1 1 2 5 3 3 0 1 1 8 5Z"),
    "sym_f": (12, "M4.2 3.2V2.6Q4.2 0.7 6.5 0.7H8V2.5H7Q6.5 2.5 6.5 3.2H8V5.1H6.5V10.7H4.2V5.1H3V3.2Z"),
    "sym_g": (12, "M7 2H9.3V8Q9.3 11 6 11 4.4 11 3.2 10.3L3.9 8.6Q4.9 9.2 6 9.2 7 9.2 7 8V7.4Q6.4 8.1 5.2 8.1 2.3 8.1 2.3 5 2.3 1.8 5.4 1.8 6.5 1.8 7 2.5ZM7 5A1.2 1.5 0 1 0 4.6 5 1.2 1.5 0 1 0 7 5Z"),
    "sym_editing": (12, "M8.9 1V11L2.5 6Z"),
}


def svg(width, height, layers):
    paths = []
    for path, color, opacity, stroke in layers:
        if stroke:
            paint = f'fill="none" stroke="{color}" stroke-width="{stroke}" stroke-opacity="{opacity}" stroke-linejoin="round"'
        else:
            alpha = f' fill-opacity="{opacity}"' if opacity != 1 else ""
            paint = f'fill="{color}"{alpha}'
        paths.append(f'  <path {paint} d="{path}"/>')
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" preserveAspectRatio="none">\n'
        + "\n".join(paths) + "\n</svg>\n"
    )


def led_web_svg(width, height, layers, active_paths, blur):
    vector = svg(width, height, layers)
    if not active_paths:
        return vector
    # Blur a duplicate of the lit shapes and paint the original above it.
    paths = "".join(f'<path d="{path}"/>' for path in active_paths)
    glow = (
        f'  <defs><g id="lit" fill="{LED_ACTIVE}">{paths}</g>'
        f'<filter id="glow" filterUnits="userSpaceOnUse" x="0" y="0" width="{width}" height="{height}" '
        f'color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="{blur}"/></filter></defs>\n'
        '  <use href="#lit" filter="url(#glow)" opacity="0.50"/>\n'
        '  <use href="#lit"/>\n'
    )
    return vector.replace("</svg>", glow + "</svg>")


def android_vector(width, height, layers):
    paths = []
    for path, color, opacity, stroke in layers:
        if stroke:
            paint = f'android:strokeColor="{color}" android:strokeWidth="{stroke}" android:strokeAlpha="{opacity}" android:strokeLineJoin="round"'
        else:
            paint = f'android:fillColor="{color}"'
        paths.append(f'    <path {paint} android:pathData="{path}"/>')
    return (
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        f'    android:width="{width}dp" android:height="{height}dp"\n'
        f'    android:viewportWidth="{width}" android:viewportHeight="{height}">\n'
        + "\n".join(paths) + "\n</vector>\n"
    )


def write_vector(name, width, height, layers, *, web_vector=None):
    vector = svg(width, height, layers)
    if name != "dot_none":
        (WEB / f"{name}.svg").write_text(web_vector if web_vector is not None else vector)
        imageset = APPLE / f"{name}.imageset"
        imageset.mkdir(exist_ok=True)
        (imageset / f"{name}.svg").write_text(vector)
        contents = {
            "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True},
        }
        (imageset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    (WEAR / f"{name}.xml").write_text(android_vector(width, height, layers))


def write_lcd(name, width, height, shapes, *, background=True, ink=False):
    plate = f"M0 0H{width}V{height}H0Z"
    layers = [(plate, LCD, 1, 0)] if background else []
    layers.extend((path, ACTIVE if active else INACTIVE, 1, 0) for path, active in shapes)
    write_vector(name, width, height, layers)
    if ink:
        layers = [(path, INK, 0.965 if active else 0.031, 0) for path, active in shapes]
        (WEB / "ink" / f"{name}.svg").write_text(svg(width, height, layers))

    layers = [(plate, LED, 1, 0)] if background else []
    layers.extend((path, LED_INACTIVE, 1, 0) for path, active in shapes if not active)
    active_paths = [path for path, active in shapes if active]
    blur = 1.2 if width == 35 else 0.55
    web_vector = led_web_svg(width, height, layers, active_paths, blur)

    # Asset catalogs and Android vectors use translucent outlines for the halo.
    for scale, opacity in [(4.5, 0.018), (3.2, 0.035), (2.1, 0.075), (1.15, 0.14)]:
        layers.extend((path, LED_ACTIVE, opacity, round(scale * blur, 2)) for path in active_paths)
    layers.extend((path, LED_ACTIVE, 1, 0) for path in active_paths)
    write_vector("led_" + name, width, height, layers, web_vector=web_vector)


def main():
    for name, active_segments in GLYPHS.items():
        shapes = [(path, segment in active_segments) for segment, path in SEGMENTS.items()]
        write_lcd(name, 35, 53, shapes, ink=True)
    write_lcd("dot", 10, 8, [(DOT, True)], background=False, ink=True)
    write_lcd("dot_none", 10, 8, [(DOT, False)], background=False)
    for name, (size, path) in MARKS.items():
        write_lcd(name, size, size, [(path, True)])
        write_lcd(name + "_none", size, size, [(path, False)])

    resources = [*GLYPHS, "dot", "dot_none"]
    for name in MARKS:
        resources.extend([name, name + "_none"])
    cases = "\n".join(
        f"        if (lcd == R.drawable.{name}) return R.drawable.led_{name};" for name in resources
    )
    mapper = WEAR.parents[1] / "java/org/feniello/retrocalc/LedDisplay.java"
    mapper.write_text(
        "// Generated by art/generate_lcd.py.\n"
        "package org.feniello.retrocalc;\n\n"
        "final class LedDisplay {\n"
        "    private LedDisplay() {}\n\n"
        "    static int drawable(int lcd) {\n"
        + cases + "\n"
        "        return lcd;\n"
        "    }\n"
        "}\n"
    )


if __name__ == "__main__":
    main()
