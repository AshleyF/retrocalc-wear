"""Draw the RetroRPN launcher icon and export the active app icon sizes."""

from pathlib import Path

from PIL import Image, ImageDraw

from generate_lcd import GLYPHS

ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024


# Beveled polygons for the icon's seven-segment readout.
SEGMENTS = {
    "a": [(9, 0), (32, 0), (35, 3), (30, 6), (12, 6), (6, 3)],
    "b": [(36, 4), (39, 7), (37, 23), (33, 26), (30, 22), (32, 8)],
    "c": [(33, 28), (36, 31), (34, 47), (30, 51), (27, 47), (29, 32)],
    "d": [(6, 47), (26, 47), (29, 51), (25, 54), (5, 54), (1, 51)],
    "e": [(4, 28), (8, 32), (6, 45), (1, 49), (-2, 45), (0, 32)],
    "f": [(7, 5), (11, 8), (9, 22), (4, 26), (1, 22), (3, 8)],
    "g": [(10, 24), (28, 24), (32, 27), (27, 30), (8, 30), (4, 27)],
}


def draw_readout(draw, y=248):
    x = 259
    for character in "2.718281":
        if character == ".":
            draw.rounded_rectangle((x - 8, y + 83, x + 5, y + 96), 3, fill="#ff5248")
            x += 10
            continue
        for segment in GLYPHS["display" + character]:
            points = SEGMENTS[segment]
            draw.polygon([(x + px * 1.8, y + py * 1.8) for px, py in points], fill="#ff5248")
        x += 73


def draw_icon():
    image = Image.new("RGB", (SIZE, SIZE), "#121411")
    draw = ImageDraw.Draw(image)
    # A soft radial field keeps the calculator legible in a round launcher mask.
    for radius in range(720, 0, -2):
        shade = round(22 + 37 * max(0, 1 - radius / 720))
        draw.ellipse((512-radius, 435-radius, 512+radius, 435+radius),
                     fill=(shade, shade + 3, shade - 3))

    draw.rounded_rectangle((193, 176, 831, 819), 83, fill="#131612",
                           outline="#51584b", width=7)
    draw.rounded_rectangle((224, 209, 800, 370), 30, fill="#17090a")
    draw.rounded_rectangle((234, 218, 790, 360), 24, fill="#301013")
    draw.rounded_rectangle((245, 230, 779, 247), 7, fill="#48171b")

    draw_readout(draw)

    for row in range(4):
        for column in range(5):
            if row == 3 and column == 4:
                continue
            x, y = 231 + column * 115, 394 + row * 99
            height = 183 if row == 2 and column == 4 else 84
            draw_key(draw, x, y, height, row, column)
    return image


def draw_key(draw, x, y, height, row, column):
    highlight, face = {
        (0, 4): ("#ffce7d", "#edaa46"),
        (1, 4): ("#94cbf2", "#549cc9"),
    }.get((row, column), ("#3d423d", "#262a27"))
    draw.rounded_rectangle((x, y, x + 103, y + height), 17, fill="#0f100f")
    draw.rounded_rectangle((x + 3, y + 2, x + 100, y + height - 9), 15, fill=face)
    draw.rounded_rectangle((x + 13, y + 6, x + 90, y + 11), 2, fill=highlight)
    if height > 84:
        for dy in (29, 57, 85, 113):
            draw.rounded_rectangle((x + 44, y + dy, x + 59, y + dy + 15), 4, fill="#eeefe4")
        legend_y = y + height - 31
    else:
        mark = "#262a27" if column == 4 else "#eeefe4"
        draw.rounded_rectangle((x + 41, y + 24, x + 62, y + 45), 5, fill=mark)
        legend_y = y + 61
    if row == 0 or (row == 1 and column == 4):
        draw.rectangle((x + 46, legend_y, x + 57, legend_y + 7), fill="#ce5e59")
    else:
        draw.rectangle((x + 36, legend_y, x + 46, legend_y + 7), fill="#eaa66a")
        draw.rectangle((x + 57, legend_y, x + 67, legend_y + 7), fill="#76bbdb")


def draw_rpn_icon(led=False, left_handed=False, rectangular=False):
    image = Image.new("RGB", (SIZE, SIZE), "#20251e")
    draw = ImageDraw.Draw(image)
    panel, glass, highlight, ink = (
        ("#17090a", "#301013", "#48171b", "#ff5248") if led
        else ("#111510", "#87977c", "#95a48a", "#222822")
    )

    if rectangular:
        draw.rounded_rectangle((48, 48, 976, 976), 72, fill="#262c24", outline="#50594b", width=9)
        draw.rounded_rectangle((70, 70, 954, 277), 41, fill=panel)
        draw.rounded_rectangle((80, 80, 944, 266), 34, fill=glass)
        draw.rounded_rectangle((96, 93, 928, 108), 7, fill=highlight)
    else:
        # The watch launcher mask supplies the curved edge of the display.
        draw.rectangle((0, 0, SIZE, 277), fill=panel)
        draw.rectangle((0, 0, SIZE, 265), fill=glass)
        draw.rectangle((0, 4, SIZE, 19), fill=highlight)

    # Extra diagonals give the letters the same beveled strokes as the numbers.
    letters = [
        (264, "abefg", [(16, 28), (22, 27), (34, 48), (30, 54), (25, 50)]),
        (444, "abefg", None),
        (624, "bcef", [(7, 4), (13, 3), (33, 47), (30, 53), (25, 50)]),
    ]
    for x, segments, diagonal in letters:
        strokes = [SEGMENTS[segment] for segment in segments]
        if diagonal:
            strokes.append(diagonal)
        for points in strokes:
            draw.polygon([(x + px * 3.4, (89 if rectangular else 77) + py * 3.1) for px, py in points], fill=ink)

    # Draw the entire keypad oversize, including the tall Enter key.
    keypad = Image.new("RGB", (574, 381), "#262c24" if rectangular else "#20251e")
    keys = ImageDraw.Draw(keypad)
    for row in range(4):
        for column in range(5):
            if row == 3 and column == 4:
                continue
            height = 183 if (row, column) == (2, 4) else 84
            visual_column = 4 - column if left_handed and column in (0, 4) else column
            draw_key(keys, 5 + visual_column * 115, row * 99, height, row, column)
    if rectangular:
        image.paste(keypad.resize((884, 640), Image.Resampling.LANCZOS), (70, 293))
        mask = Image.new("L", image.size)
        ImageDraw.Draw(mask).rounded_rectangle((48, 48, 976, 976), 72, fill=255)
        image.putalpha(mask)
    else:
        image.paste(keypad.resize((1044, 680), Image.Resampling.LANCZOS), (-10, 293))
    return image


if __name__ == "__main__":
    icon = draw_icon()
    for led in (False, True):
        for left_handed in (False, True):
            suffix = ("-led" if led else "") + ("-left" if left_handed else "")
            favicon = draw_rpn_icon(led, left_handed, rectangular=True)
            favicon.resize((64, 64), Image.Resampling.LANCZOS).save(ROOT / f"docs/favicon{suffix}.png")
    watch_icon = draw_rpn_icon(led=True)
    for target in ("RetroRPN Watch App", "RetroRPN"):
        watch_icon.save(ROOT / "apple" / target / "Assets.xcassets/AppIcon.appiconset/icon-1024.png")
    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        target = ROOT / "wear/src/main/res" / f"mipmap-{density}/ic_launcher.png"
        icon.resize((size, size), Image.Resampling.LANCZOS).save(target)
