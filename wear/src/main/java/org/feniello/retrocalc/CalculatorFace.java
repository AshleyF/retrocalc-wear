package org.feniello.retrocalc;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.view.MotionEvent;
import android.view.View;
import android.widget.RelativeLayout;

import java.util.ArrayList;
import java.util.List;
import java.util.function.IntConsumer;

/** The two Wear key layouts in the same 320-unit coordinate space as the LCD. */
final class CalculatorFace extends Drawable {
    static final int BACKGROUND = 0xFF1E211C;
    static final int LCD = 0xFF747F6E;
    static final int LED = 0xFF301013;
    static final int LCD_TEXT = 0xFF282828;
    static final int LED_TEXT = 0xFFFF382E;

    private static final String[] TITLES = {
        "÷", "7", "8", "9", "f", "×", "4", "5", "6", "g",
        "−", "1", "2", "3", "ENTER", "+", "0", "·", "+/−"
    };
    private static final String[] F_LABELS = {
        "a", "b", "c", "d", "", "yˣ", "eˣ", "10ˣ", "1/x", "",
        "ran", "sin", "cos", "tan", "Cx", "ST", "e", "x↔y", "R↓"
    };
    private static final String[] G_LABELS = {
        "", "", "", "", "", "ˣ√y", "ln", "log", "int", "",
        "|x|", "⁻¹", "⁻¹", "⁻¹", "⌫", "RC", "π", "over", "R↑"
    };

    private static final float FACE_CENTER = 160f;
    private static final int ROUND_DISPLAY_TOP = 58;
    private static final float KEY_EDGE_RADIUS = 156f;

    private final boolean round;
    private final IntConsumer onKey;
    private final Runnable onEnterDown;
    private final Paint plate = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final List<Key> keys = new ArrayList<>();
    private boolean expanded;
    private boolean led;
    private boolean xOnTop;
    private boolean leftHanded;

    CalculatorFace(RelativeLayout parent, boolean round, IntConsumer onKey, Runnable onEnterDown) {
        this.round = round;
        this.onKey = onKey;
        this.onEnterDown = onEnterDown;
        if (round) {
            add(parent, 4, 111, 12, 48, 45, 0);
            add(parent, 9, 161, 12, 48, 45, 0);
            row(parent, new int[] {1, 2, 3, 0, 18}, 35, 117, 49, 45, 51);
            row(parent, new int[] {6, 7, 8, 5}, 35, 164, 49, 45, 51);
            row(parent, new int[] {11, 12, 13, 10}, 35, 211, 49, 45, 51);
            row(parent, new int[] {16, 17, 15}, 86, 261, 49, 46, 51);
            add(parent, 14, 239, 164, 48, 92, 46);
        } else {
            row(parent, new int[] {0, 1, 2, 3, 4}, 1, 69, 62, 59, 64);
            row(parent, new int[] {5, 6, 7, 8, 9}, 1, 133, 62, 59, 64);
            row(parent, new int[] {10, 11, 12, 13}, 1, 197, 62, 59, 64);
            row(parent, new int[] {15, 16, 17, 18}, 1, 261, 62, 58, 64);
            add(parent, 14, 257, 197, 62, 122, 63);
        }
    }

    private void row(RelativeLayout parent, int[] codes, int x, int y, int w, int h, int pitch) {
        for (int i = 0; i < codes.length; i++) add(parent, codes[i], x + i * pitch, y, w, h, 0);
    }

    private void add(RelativeLayout parent, int code, int x, int y, int w, int h, int enterSplit) {
        Key key = new Key(parent.getContext(), code, enterSplit, x);
        RelativeLayout.LayoutParams layout = new RelativeLayout.LayoutParams(w, h);
        layout.leftMargin = x;
        layout.topMargin = y;
        parent.addView(key, layout);
        keys.add(key);
    }

    void update(boolean expanded, boolean led, boolean xOnTop, boolean leftHanded) {
        if (this.leftHanded != leftHanded) {
            this.leftHanded = leftHanded;
            for (Key key : keys) {
                RelativeLayout.LayoutParams layout = (RelativeLayout.LayoutParams) key.getLayoutParams();
                layout.leftMargin = leftHanded ? leftPosition(key) : key.rightX;
                key.setLayoutParams(layout);
            }
        }
        if (this.expanded != expanded) {
            for (Key key : keys) {
                key.setVisibility(expanded ? View.GONE : View.VISIBLE);
                if (expanded) key.setPressed(false);
            }
        }
        if (this.xOnTop != xOnTop) {
            this.xOnTop = xOnTop;
            for (Key key : keys) {
                if (key.code == 18) {
                    key.updateDescription();
                    key.invalidate();
                }
            }
        }
        if (this.expanded != expanded || this.led != led) {
            this.expanded = expanded;
            this.led = led;
            invalidateSelf();
        }
    }

    private int leftPosition(Key key) {
        if (!round) {
            if (key.rightX == 1) return 257;
            if (key.rightX == 257) return 1;
            return key.rightX;
        }
        // Enter and sign use the outside rail. The arithmetic column sits just inside it.
        switch (key.code) {
            case 4:
            case 9:
                return key.rightX;
            case 14:
            case 18:
                return 35;
            case 0:
            case 5:
            case 10:
            case 15:
                return 86;
            case 16: return 188;
            case 17: return 137;
            default: return key.rightX + 102;
        }
    }

    void flash(int code) {
        for (Key key : keys) {
            if (key.code == code || (key.code == 14 && (code == 19 || code == Calculator.EXPONENT_KEY))) {
                key.flash();
                return;
            }
        }
    }

    boolean isDisplay(float y) {
        return round ? y >= ROUND_DISPLAY_TOP && y < 117 : y < 69;
    }

    @Override
    public void draw(Canvas canvas) {
        plate.setColor(BACKGROUND);
        canvas.drawRect(getBounds(), plate);
        if (expanded) return;
        int checkpoint = canvas.save();
        canvas.translate(getBounds().left, getBounds().top);
        canvas.scale(getBounds().width() / 320f, getBounds().height() / 320f);
        plate.setColor(led ? 0xFF4A191D : 0xFF6C7667);
        if (round) {
            canvas.clipRect(0, ROUND_DISPLAY_TOP, 320, 117);
            canvas.drawCircle(160, 160, 160, plate);
            canvas.clipRect(0, ROUND_DISPLAY_TOP + 1, 320, 116);
            plate.setColor(led ? LED : LCD);
            canvas.drawCircle(160, 160, 159, plate);
        } else {
            canvas.drawRoundRect(2, 1, 318, 68, 4, 4, plate);
            plate.setColor(led ? LED : LCD);
            canvas.drawRoundRect(3, 2, 317, 67, 3, 3, plate);
        }
        canvas.restoreToCount(checkpoint);
    }

    @Override public void setAlpha(int alpha) {}
    @Override public void setColorFilter(ColorFilter filter) {}
    @Override public int getOpacity() { return PixelFormat.OPAQUE; }

    private final class Key extends View {
        private final int code;
        private final int enterSplit;
        private final int rightX;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF bounds = new RectF();
        private final Path triangle = new Path();
        private final Path keyOutline = new Path();
        private final Path screenOutline = new Path();
        private LinearGradient bevel;
        private boolean flashed;
        private int enterTapCode;
        private boolean didHoldEnter;
        private final Runnable holdEnter = () -> {
            didHoldEnter = true;
            onKey.accept(Calculator.EXPONENT_KEY);
        };
        private final Runnable clearFlash = () -> {
            flashed = false;
            invalidate();
        };

        Key(Context context, int code, int enterSplit, int rightX) {
            super(context);
            this.code = code;
            this.enterSplit = enterSplit;
            this.rightX = rightX;
            paint.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
            paint.setTextAlign(Paint.Align.CENTER);
            setFocusable(true);
            setOnClickListener(view -> onKey.accept(code));
            if (code == 14) setOnLongClickListener(view -> {
                onKey.accept(Calculator.EXPONENT_KEY);
                return true;
            });
            updateDescription();
        }

        private String fLabel() {
            if (round && code < 4) return F_LABELS[(code + 3) % 4];
            if (code == 18 && xOnTop) return "R↑";
            return F_LABELS[code];
        }

        private String gLabel() {
            return code == 18 && xOnTop ? "R↓" : G_LABELS[code];
        }

        private void updateDescription() {
            String label = code == 14 ? "Enter, hold for exponent entry" : TITLES[code];
            if (code == 4) label += ", play, iterate";
            else if (code == 9) label += ", record, stop";
            else {
                if (!fLabel().isEmpty()) label += ", f " + fLabel();
                if (!gLabel().isEmpty()) label += ", g " + gLabel();
            }
            setContentDescription(label);
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    if (!isInside(event)) return false;
                    setPressed(true);
                    if (code == 14) {
                        enterTapCode = event.getY() >= enterSplit ? 19 : 14;
                        didHoldEnter = false;
                        onEnterDown.run();
                        postDelayed(holdEnter, 450);
                    } else {
                        performClick();
                    }
                    invalidate();
                    return true;
                case MotionEvent.ACTION_MOVE:
                    if (code == 14 && !isInside(event)) {
                        removeCallbacks(holdEnter);
                        setPressed(false);
                        invalidate();
                    }
                    return true;
                case MotionEvent.ACTION_UP:
                    removeCallbacks(holdEnter);
                    if (code == 14 && isPressed() && !didHoldEnter && isInside(event)) {
                        onKey.accept(enterTapCode);
                    }
                    setPressed(false);
                    invalidate();
                    return true;
                case MotionEvent.ACTION_CANCEL:
                    removeCallbacks(holdEnter);
                    setPressed(false);
                    invalidate();
                    return true;
                default:
                    return true;
            }
        }

        private boolean isInside(MotionEvent event) {
            float x = event.getX();
            float y = event.getY();
            if (x < 0 || x >= getWidth() || y < 0 || y >= getHeight()) return false;
            if (!round) return true;
            float dx = getLeft() + x - FACE_CENTER;
            float dy = getTop() + y - FACE_CENTER;
            return dx * dx + dy * dy <= KEY_EDGE_RADIUS * KEY_EDGE_RADIUS;
        }

        private void flash() {
            removeCallbacks(clearFlash);
            flashed = true;
            invalidate();
            postDelayed(clearFlash, 450);
        }

        @Override
        protected void onSizeChanged(int w, int h, int oldw, int oldh) {
            bounds.set(0.5f, 0.5f, w - 0.5f, h - 0.5f);
            int[] colors;
            if (code == 4) colors = new int[] {0xFFEEA277, 0xFFE17E49, 0xFF964E24};
            else if (code == 9) colors = new int[] {0xFF8CC4E6, 0xFF4592D0, 0xFF1C4E7A};
            else colors = new int[] {0xFF4D4D4D, 0xFF292929, 0xFF1A1A1A};
            float skirt = 1 - w * 0.31f / h;
            bevel = new LinearGradient(0, 0, 0, h,
                    new int[] {colors[0], colors[1], colors[1], colors[2], colors[2]},
                    new float[] {0, 0.09f, skirt, skirt + 0.07f, 1}, Shader.TileMode.CLAMP);
        }

        @Override
        protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
            super.onLayout(changed, left, top, right, bottom);
            if (!changed) return;

            float radius = Math.min(getWidth(), getHeight()) * 0.16f;
            keyOutline.rewind();
            keyOutline.addRoundRect(bounds, radius, radius, Path.Direction.CW);
            if (round) {
                screenOutline.rewind();
                screenOutline.addCircle(FACE_CENTER - left, FACE_CENTER - top,
                        KEY_EDGE_RADIUS, Path.Direction.CW);
                keyOutline.op(screenOutline, Path.Op.INTERSECT);
            }
        }

        @Override
        protected void onDraw(Canvas canvas) {
            float w = getWidth();
            float h = getHeight();
            paint.setShader(bevel);
            canvas.drawPath(keyOutline, paint);
            paint.setShader(null);
            if (isPressed() || flashed) {
                paint.setColor(0x70000000);
                canvas.drawPath(keyOutline, paint);
            }
            if (code == 14) {
                for (int i = 0; i < 5; i++) {
                    text(canvas, TITLES[code].substring(i, i + 1), w / 2, h * (0.14f + i * 0.145f),
                            w * 0.28f, 0xFFF5F5F2);
                }
                canvas.save();
                canvas.rotate(-90, w * 0.23f, h * 0.43f);
                text(canvas, "EEX", w * 0.23f, h * 0.43f, w * 0.16f, 0xFF858585);
                canvas.restore();
            } else {
                int color = code == 4 || code == 9 ? 0xFF141414 : 0xFFF5F5F2;
                float size = h * (code == 18 ? 0.40f : 0.53f);
                text(canvas, TITLES[code], w / 2, h * 0.36f, size, color);
            }
            if (code == 4 || code == 9) {
                drawMacroCues(canvas, w, h);
            } else {
                drawLegends(canvas, w, h);
            }
        }

        private void drawMacroCues(Canvas canvas, float width, float height) {
            float mark = width * 0.18f;
            float gap = mark * 0.28f;
            float top = height * 0.94f - mark;
            paint.setColor(0xFF9A1C1C);
            if (code == 4) {
                float playWidth = mark * 0.86f;
                float iterateWidth = mark * 1.06f;
                float left = (width - playWidth - gap - iterateWidth) / 2;
                drawTriangle(canvas, left, top, playWidth, mark);
                paint.setColor(0xFF1B4E78);
                float iterateLeft = left + playWidth + gap;
                float half = iterateWidth * 0.42f;
                drawTriangle(canvas, iterateLeft, top, half, mark);
                drawTriangle(canvas, iterateLeft + iterateWidth - half, top, half, mark);
            } else {
                float left = (width - 2 * mark - gap) / 2;
                canvas.drawCircle(left + mark / 2, top + mark / 2, mark / 2, paint);
                paint.setColor(0xFF8C4C22);
                float stopLeft = left + mark + gap;
                canvas.drawRect(stopLeft, top, stopLeft + mark, top + mark, paint);
            }
        }

        private void drawTriangle(Canvas canvas, float left, float top, float width, float height) {
            triangle.rewind();
            triangle.moveTo(left, top);
            triangle.lineTo(left + width, top + height / 2);
            triangle.lineTo(left, top + height);
            triangle.close();
            canvas.drawPath(triangle, paint);
        }

        private void drawLegends(Canvas canvas, float w, float h) {
            String first = fLabel();
            String second = gLabel();
            float size = w * 0.22f;
            float centerY = h - w * 0.18f;
            if (second.isEmpty()) {
                text(canvas, first, w / 2, centerY, size, 0xFFD45346);
                return;
            }
            paint.setTextSize(size);
            float firstW = paint.measureText(first);
            float secondW = paint.measureText(second);
            float gap = w * (code >= 11 && code <= 13 ? 0.015f : 0.055f);
            float fit = Math.min(1, w * 0.88f / (firstW + secondW + gap));
            float left = (w - (firstW + secondW + gap) * fit) / 2;
            text(canvas, first, left + firstW * fit / 2, centerY, size * fit, 0xFFDD7E49);
            text(canvas, second, left + (firstW + gap + secondW / 2) * fit, centerY, size * fit, 0xFF56A8D6);
        }

        private void text(Canvas canvas, String text, float x, float y, float size, int color) {
            paint.setTextSize(size);
            paint.setColor(color);
            canvas.drawText(text, x, y - (paint.ascent() + paint.descent()) / 2, paint);
        }
    }
}
