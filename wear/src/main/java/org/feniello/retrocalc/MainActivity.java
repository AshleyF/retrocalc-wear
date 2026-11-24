package org.feniello.retrocalc;

import android.app.Activity;
import android.os.Bundle;
import android.widget.ImageView;
import android.view.View;
import android.view.MotionEvent;
import android.os.Vibrator;
import android.os.VibrationEffect;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.util.Locale;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.RelativeLayout;
import android.view.Gravity;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.Drawable;
import android.util.TypedValue;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.InputDevice;
import java.util.HashMap;
import java.util.Map;

public class MainActivity extends Activity {

    private Vibrator mVibrator;
    private ImageView imageBackground;

    private final Calculator calc = new Calculator();
    private ImageView[][] lcdDigits = new ImageView[7][5];
    private ImageView[][] lcdDots = new ImageView[7][5];
    private ImageView lcdRec;
    private ImageView lcdF;
    private ImageView lcdG;
    private ImageView lcdEdit;
    private boolean isRound = false;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private FacePortrait portraitView;
    private Rect labelBounds;
    /** False draws the manual's stack, with X at the bottom. True puts X on top. */
    private boolean stackXOnTop;
    private boolean usesLed;
    private boolean leftHanded;
    private boolean showsSettings;
    private CalculatorFace calculatorFace;

    /** Skip the drawable reload when the cell is already showing it. Reloading the face on every key made the emulator's software renderer stall long enough to trip "isn't responding". */
    private void show(ImageView view, int res) {
        if (usesLed) res = LedDisplay.drawable(res);
        Object shown = view.getTag();
        if (shown instanceof Integer && (Integer) shown == res) return;
        view.setTag(res);
        view.setImageResource(res);
    }

    private void renderDigit(char c, ImageView iv) {
        switch (c)
        {
            case '-':
                show(iv, R.drawable.display_neg);
                break;
            case '0':
                show(iv, R.drawable.display0);
                break;
            case '1':
                show(iv, R.drawable.display1);
                break;
            case '2':
                show(iv, R.drawable.display2);
                break;
            case '3':
                show(iv, R.drawable.display3);
                break;
            case '4':
                show(iv, R.drawable.display4);
                break;
            case '5':
                show(iv, R.drawable.display5);
                break;
            case '6':
                show(iv, R.drawable.display6);
                break;
            case '7':
                show(iv, R.drawable.display7);
                break;
            case '8':
                show(iv, R.drawable.display8);
                break;
            case '9':
                show(iv, R.drawable.display9);
                break;
        }
    }

    private void renderValue(double dv, String v, int reg) {
        // reset dots
        int d = 6;
        for (int i = 0; i < 7; i++) {
            show(lcdDots[i][reg], R.drawable.dot_none);
        }

        if (v.equals("Infinity")) {
            show(lcdDigits[0][reg], R.drawable.display_none);
            show(lcdDigits[1][reg], R.drawable.display_none);
            show(lcdDigits[2][reg], R.drawable.display1);
            show(lcdDigits[3][reg], R.drawable.display_n);
            show(lcdDigits[4][reg], R.drawable.display_f);
            show(lcdDigits[5][reg], R.drawable.display_i);
            show(lcdDigits[6][reg], R.drawable.display_n);
            return;
        }

        if (v.equals("-Infinity")) {
            show(lcdDigits[0][reg], R.drawable.display_none);
            show(lcdDigits[1][reg], R.drawable.display_neg);
            show(lcdDigits[2][reg], R.drawable.display1);
            show(lcdDigits[3][reg], R.drawable.display_n);
            show(lcdDigits[4][reg], R.drawable.display_f);
            show(lcdDigits[5][reg], R.drawable.display_i);
            show(lcdDigits[6][reg], R.drawable.display_n);
            return;
        }

        if (v.equals("NaN")) {
            show(lcdDigits[0][reg], R.drawable.display_none);
            show(lcdDigits[1][reg], R.drawable.display_none);
            show(lcdDigits[2][reg], R.drawable.display_e);
            show(lcdDigits[3][reg], R.drawable.display_r);
            show(lcdDigits[4][reg], R.drawable.display_r);
            show(lcdDigits[5][reg], R.drawable.display_o);
            show(lcdDigits[6][reg], R.drawable.display_r);
            return;
        }

        String[] parts = v.split("E");
        int explen = 0;
        if (parts.length > 1) {
            explen = parts[1].length();
            if (parts[1].charAt(0) != '-') explen++;
            d -= explen;
        } else {
            if (dv > 9999999 || dv < -999999 || (dv > 0 && dv < 0.000001) || (dv < 0 && dv > -0.00001)) {
                DecimalFormat formatter = new DecimalFormat("0.0####E0", DecimalFormatSymbols.getInstance(Locale.US));
                v = formatter.format(dv);
                parts = v.split("E");
                explen = 0;
                explen = parts[1].length();
                if (parts[1].charAt(0) != '-') explen++;
                d -= explen;
            }
        }
        v = parts[0];
        int maxlen = (v.contains(".") ? 8 : 7) - explen;
        if (v.length() > maxlen) {
            v = LcdText.clipMantissa(v, maxlen);
        }
        for (int i = v.length() - 1; i >= 0; i--) {
            char c = v.charAt(i);
            if (c == '.') {
                show(lcdDots[d][reg], R.drawable.dot);
            } else {
                renderDigit(c, lcdDigits[d][reg]);
                d--;
            }
        }

        // reset remaining leading digits
        while (d >= 0) {
            show(lcdDigits[d][reg], R.drawable.display_none);
            d--;
        }
        if (parts.length > 1) { // scientific notation
            String e = parts[1];
            d = 6;
            boolean neg = false;
            for (int i = e.length() - 1; i >= 0; i--) {
                char c = e.charAt(i);
                if (c == '-') neg = true;
                renderDigit(c, lcdDigits[d][reg]);
                d--;
            }
            if (!neg) show(lcdDigits[d][reg], R.drawable.display_none);
        }
    }

    private void render() {
        if (calc.isFullscreen()) {
            showStack();
        } else {
            hideStack();
            for (int j = 1; j < 4; j++) {
                for (int i = 0; i < 7; i++) {
                    lcdDigits[i][j].setVisibility(View.INVISIBLE);
                    lcdDots[i][j].setVisibility(View.INVISIBLE);
                }
            }
        }
        show(lcdRec, calc.isRecMode() ? R.drawable.sym_rec : R.drawable.sym_rec_none);
        show(lcdF, calc.isFMode() ? R.drawable.sym_f : R.drawable.sym_f_none);
        show(lcdG, calc.isGMode() ? R.drawable.sym_g : R.drawable.sym_g_none);
        show(lcdEdit, calc.isEditing() ? R.drawable.sym_editing : R.drawable.sym_editing_none);
        renderValue(calc.getX(), calc.getDisplay(), 0);
        applyFaceScale();
        calculatorFace.update(calc.isFullscreen(), usesLed, stackXOnTop, leftHanded);
    }

    @Override
    protected void onPause() {
        StateStore.save(this, calc.exportState());
        super.onPause();
    }

    private void keypress(int row, int column, boolean update) {
        if (update && row >= 0) vibrate();
        calc.press(row, column);
    }

    private void vibrate() {
        if (mVibrator == null)
            mVibrator = (Vibrator) getSystemService(Vibrator.class);
        if (mVibrator != null) {
            mVibrator.vibrate(VibrationEffect.createOneShot(15, VibrationEffect.DEFAULT_AMPLITUDE));
        }
    }


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        isRound = getResources().getConfiguration().isScreenRound();
        stackXOnTop = StateStore.stackXOnTop(this);
        usesLed = StateStore.usesLed(this);
        leftHanded = StateStore.leftHanded(this);
        calc.setRoundFace(isRound);
        calc.restoreState(StateStore.load(this));
        calc.setScheduler(new Calculator.Scheduler() {
            @Override
            public void schedule(Runnable work) {
                handler.postDelayed(work, 1);
            }
        });
        calc.setListener(new Calculator.Listener() {
            @Override
            public void onChanged() {
                if (calculatorFace != null) render();
                StateStore.save(MainActivity.this, calc.exportState());
            }
        });
        final FrameLayout container = (FrameLayout) findViewById(R.id.container);
        final View face = getLayoutInflater().inflate(
                isRound ? R.layout.round_activity_main : R.layout.rect_activity_main,
                container, false);
        container.addView(face, new FrameLayout.LayoutParams(320, 320, Gravity.CENTER));
        container.setClipChildren(false);
        // This emulator has no GLES 3.1, so the system falls back to a software
        // GL driver that stalls for seconds while drawing the scaled keypad.
        // Rasterize the 320-pixel face on the CPU and composite one bitmap.
        if (isEmulator()) face.setLayerType(View.LAYER_TYPE_SOFTWARE, null);
        container.addOnLayoutChangeListener((v, left, top, right, bottom,
                                              oldLeft, oldTop, oldRight, oldBottom) -> {
            if (right - left == oldRight - oldLeft && bottom - top == oldBottom - oldTop) return;
            fitFace(face, right - left, bottom - top);
        });
        container.post(() -> fitFace(face, container.getWidth(), container.getHeight()));

        final MainActivity that = this;
        mVibrator = (Vibrator) getSystemService(Vibrator.class);
        that.imageBackground = (ImageView)findViewById(R.id.imageBackground);
                that.lcdDigits[0][0] = (ImageView)findViewById(R.id.imageDigit0x);
                that.lcdDigits[1][0] = (ImageView)findViewById(R.id.imageDigit1x);
                that.lcdDigits[2][0] = (ImageView)findViewById(R.id.imageDigit2x);
                that.lcdDigits[3][0] = (ImageView)findViewById(R.id.imageDigit3x);
                that.lcdDigits[4][0] = (ImageView)findViewById(R.id.imageDigit4x);
                that.lcdDigits[5][0] = (ImageView)findViewById(R.id.imageDigit5x);
                that.lcdDigits[6][0] = (ImageView)findViewById(R.id.imageDigit6x);
                that.lcdDots[0][0] = (ImageView)findViewById(R.id.imageDot0x);
                that.lcdDots[1][0] = (ImageView)findViewById(R.id.imageDot1x);
                that.lcdDots[2][0] = (ImageView)findViewById(R.id.imageDot2x);
                that.lcdDots[3][0] = (ImageView)findViewById(R.id.imageDot3x);
                that.lcdDots[5][0] = (ImageView)findViewById(R.id.imageDot5x);
                that.lcdDots[4][0] = (ImageView)findViewById(R.id.imageDot4x);
                that.lcdDots[6][0] = (ImageView)findViewById(R.id.imageDot6x);
                that.lcdDigits[0][1] = (ImageView)findViewById(R.id.imageDigit0y);
                that.lcdDigits[1][1] = (ImageView)findViewById(R.id.imageDigit1y);
                that.lcdDigits[2][1] = (ImageView)findViewById(R.id.imageDigit2y);
                that.lcdDigits[3][1] = (ImageView)findViewById(R.id.imageDigit3y);
                that.lcdDigits[4][1] = (ImageView)findViewById(R.id.imageDigit4y);
                that.lcdDigits[5][1] = (ImageView)findViewById(R.id.imageDigit5y);
                that.lcdDigits[6][1] = (ImageView)findViewById(R.id.imageDigit6y);
                that.lcdDots[0][1] = (ImageView)findViewById(R.id.imageDot0y);
                that.lcdDots[1][1] = (ImageView)findViewById(R.id.imageDot1y);
                that.lcdDots[2][1] = (ImageView)findViewById(R.id.imageDot2y);
                that.lcdDots[3][1] = (ImageView)findViewById(R.id.imageDot3y);
                that.lcdDots[5][1] = (ImageView)findViewById(R.id.imageDot5y);
                that.lcdDots[4][1] = (ImageView)findViewById(R.id.imageDot4y);
                that.lcdDots[6][1] = (ImageView)findViewById(R.id.imageDot6y);
                that.lcdDigits[0][2] = (ImageView)findViewById(R.id.imageDigit0z);
                that.lcdDigits[1][2] = (ImageView)findViewById(R.id.imageDigit1z);
                that.lcdDigits[2][2] = (ImageView)findViewById(R.id.imageDigit2z);
                that.lcdDigits[3][2] = (ImageView)findViewById(R.id.imageDigit3z);
                that.lcdDigits[4][2] = (ImageView)findViewById(R.id.imageDigit4z);
                that.lcdDigits[5][2] = (ImageView)findViewById(R.id.imageDigit5z);
                that.lcdDigits[6][2] = (ImageView)findViewById(R.id.imageDigit6z);
                that.lcdDots[0][2] = (ImageView)findViewById(R.id.imageDot0z);
                that.lcdDots[1][2] = (ImageView)findViewById(R.id.imageDot1z);
                that.lcdDots[2][2] = (ImageView)findViewById(R.id.imageDot2z);
                that.lcdDots[3][2] = (ImageView)findViewById(R.id.imageDot3z);
                that.lcdDots[5][2] = (ImageView)findViewById(R.id.imageDot5z);
                that.lcdDots[4][2] = (ImageView)findViewById(R.id.imageDot4z);
                that.lcdDots[6][2] = (ImageView)findViewById(R.id.imageDot6z);
                that.lcdDigits[0][3] = (ImageView)findViewById(R.id.imageDigit0t);
                that.lcdDigits[1][3] = (ImageView)findViewById(R.id.imageDigit1t);
                that.lcdDigits[2][3] = (ImageView)findViewById(R.id.imageDigit2t);
                that.lcdDigits[3][3] = (ImageView)findViewById(R.id.imageDigit3t);
                that.lcdDigits[4][3] = (ImageView)findViewById(R.id.imageDigit4t);
                that.lcdDigits[5][3] = (ImageView)findViewById(R.id.imageDigit5t);
                that.lcdDigits[6][3] = (ImageView)findViewById(R.id.imageDigit6t);
                that.lcdDots[0][3] = (ImageView)findViewById(R.id.imageDot0t);
                that.lcdDots[1][3] = (ImageView)findViewById(R.id.imageDot1t);
                that.lcdDots[2][3] = (ImageView)findViewById(R.id.imageDot2t);
                that.lcdDots[3][3] = (ImageView)findViewById(R.id.imageDot3t);
                that.lcdDots[5][3] = (ImageView)findViewById(R.id.imageDot5t);
                that.lcdDots[4][3] = (ImageView)findViewById(R.id.imageDot4t);
                that.lcdDots[6][3] = (ImageView)findViewById(R.id.imageDot6t);
                that.lcdRec = (ImageView)findViewById(R.id.imageSymRec);
                that.lcdF = (ImageView)findViewById(R.id.imageSymF);
                that.lcdG = (ImageView)findViewById(R.id.imageSymG);
                that.lcdEdit = (ImageView)findViewById(R.id.imageSymEdit);
                that.imageBackground.setOnTouchListener(new ImageView.OnTouchListener() {
                    @Override
                    public boolean onTouch(View view, MotionEvent event) {
                        int action = event.getAction();
                        if (action == MotionEvent.ACTION_DOWN) {
                            // The open stack is not a keypad. Closing it is a display
                            // tap, including while a macro is running, so the tap does
                            // not land on a key and stop the macro.
                            if (showsSettings) return true;
                            if (calc.isFullscreen()) {
                                if (portraitView != null && portraitView.getVisibility() == View.VISIBLE) {
                                    hidePortrait();
                                    keypress(-1, 0, true);
                                } else if (labelBounds != null
                                        && labelBounds.contains((int) event.getX(), (int) event.getY())) {
                                    flipStack();
                                } else {
                                    keypress(-1, 0, true);
                                }
                                return true;
                            }
                            if (calculatorFace.isDisplay(event.getY())) keypress(-1, 0, true);
                        }
                        return true;
                    }
                });
        calculatorFace = new CalculatorFace((RelativeLayout) face, isRound,
                code -> keypress(code / 5, code % 5,
                        code != 14 && code != 19 && code != Calculator.EXPONENT_KEY), this::vibrate);
        imageBackground.setBackground(calculatorFace);
        render();
    }

    @Override
    public boolean onGenericMotionEvent(MotionEvent event) {
        // A phone emulator turns trackpad and mouse-wheel movement into scroll
        // events. Those are not the crown; treating them as undo redrew the
        // keypad on every nudge.
        boolean rotary = (event.getSource() & InputDevice.SOURCE_ROTARY_ENCODER)
                == InputDevice.SOURCE_ROTARY_ENCODER;
        if (rotary && event.getAction() == MotionEvent.ACTION_SCROLL) {
            // Crown up redoes one keystroke, matching the watch. A positive
            // rotary scroll is that upward turn.
            float scroll = event.getAxisValue(MotionEvent.AXIS_SCROLL);
            boolean changed = scroll > 0 ? calc.redo() : scroll < 0 && calc.undo();
            Integer key = calc.getReplayedKey();
            if (changed && key != null && key >= 0) calculatorFace.flash(key);
            return true;
        }
        return super.onGenericMotionEvent(event);
    }

    private View face;
    private int faceWidth;
    private int faceHeight;

    private void fitFace(View face, int width, int height) {
        this.face = face;
        faceWidth = width;
        faceHeight = height;
        applyFaceScale();
    }

    private void applyFaceScale() {
        if (face == null || faceWidth <= 0 || faceHeight <= 0) return;
        float scale = Math.min(faceWidth, faceHeight) / 320f;
        if (Math.abs(face.getScaleX() - scale) < 0.01f && Math.abs(face.getScaleY() - scale) < 0.01f) return;
        face.setPivotX(160f);
        face.setPivotY(160f);
        face.setScaleX(scale);
        face.setScaleY(scale);
    }

    private static final int FACE_PX = 320;
    private static final String[] STACK_LABELS = {"x", "y", "z", "t", "ST"};
    private View stackPanel;
    private DisplaySettingsView settings;
    private final TextView[] stackLabels = new TextView[5];
    private TextView creditTitle;
    private Drawable creditGear;
    private Drawable creditLedGear;
    private TextView creditAuthor;
    private final Map<View, RelativeLayout.LayoutParams> collapsedLayout = new HashMap<>();

    /** Five labeled rows, the same stack the Apple face shows. The round plate stays inside the circle. */
    private void showStack() {
        RelativeLayout parent = (RelativeLayout) imageBackground.getParent();
        ensureRoundStack(parent);
        rememberCollapsed();
        int textColor = usesLed ? CalculatorFace.LED_TEXT : CalculatorFace.LCD_TEXT;
        ((GradientDrawable) stackPanel.getBackground()).setColor(usesLed ? CalculatorFace.LED : CalculatorFace.LCD);
        stackPanel.setVisibility(View.VISIBLE);
        for (TextView label : stackLabels) label.setVisibility(View.VISIBLE);
        creditTitle.setVisibility(View.VISIBLE);
        creditAuthor.setVisibility(View.VISIBLE);

        int side;
        int origin;
        if (isRound) {
            side = Math.round(FACE_PX / (float) Math.sqrt(2.0)) - 8;
            origin = (FACE_PX - side) / 2;
        } else {
            side = FACE_PX - 8;
            origin = 4;
        }
        RelativeLayout.LayoutParams panelLp = new RelativeLayout.LayoutParams(side, side);
        panelLp.leftMargin = origin;
        panelLp.topMargin = origin;
        stackPanel.setLayoutParams(panelLp);

        float inner = side - 8f;
        float creditH = Math.max(23f, side * 0.09f);
        float labelW = Math.min(28f, Math.max(18f, inner * 0.11f));
        float annW = 12f;
        float cellW = Math.max(1f, (inner - annW - 8f - labelW) / 7f);
        float rowArea = side - 8f - creditH;
        float cellH = Math.min(cellW * (53f / 43f), Math.max(1f, (rowArea - 8f) / 5f));
        float rowGap = 1f;
        float blockH = 5f * cellH + 4f * rowGap;
        float rowTop = origin + 4f + (rowArea - blockH) / 2f;
        float labelLeft = origin + 4f;
        float digitLeft = labelLeft + labelW + 2f;
        float labelSize = Math.min(13f, Math.max(8f, labelW * 0.46f));

        for (int register = 0; register < 5; register++) {
            int row = stackXOnTop ? register : 4 - register;
            float top = rowTop + row * (cellH + rowGap);
            TextView label = stackLabels[register];
            label.setText(STACK_LABELS[register]);
            DisplaySettingsView.styleText(label, textColor);
            label.setTextSize(TypedValue.COMPLEX_UNIT_PX, labelSize);
            place(label, labelLeft, top, labelW, cellH);
            for (int i = 0; i < 7; i++) {
                float cellX = digitLeft + i * cellW;
                float glyphW = cellW * 35f / 43f;
                lcdDigits[i][register].setVisibility(View.VISIBLE);
                lcdDigits[i][register].setScaleType(ImageView.ScaleType.FIT_XY);
                place(lcdDigits[i][register], cellX, top, glyphW, cellH);
                float dotW = cellW * 10f / 43f;
                float dotH = cellH * 8f / 53f;
                float dotCx = cellX + cellW * 36f / 43f;
                float dotCy = top + cellH * 49f / 53f;
                lcdDots[i][register].setVisibility(View.VISIBLE);
                lcdDots[i][register].setScaleType(ImageView.ScaleType.FIT_XY);
                place(lcdDots[i][register], dotCx - dotW / 2f, dotCy - dotH / 2f, dotW, dotH);
            }
        }
        labelBounds = new Rect(
                Math.round(origin),
                Math.round(rowTop),
                Math.round(digitLeft),
                Math.round(rowTop + blockH));
        int xRow = stackXOnTop ? 0 : 4;
        float xTop = rowTop + xRow * (cellH + rowGap);
        float annLeft = digitLeft + 7f * cellW + 2f;
        float annH = cellH / 4f;
        place(lcdRec, annLeft, xTop, annW, annH);
        place(lcdF, annLeft, xTop + annH, annW, annH);
        place(lcdG, annLeft, xTop + annH * 2f, annW, annH);
        place(lcdEdit, annLeft, xTop + annH * 3f, annW, annH);

        float creditTop = origin + side - creditH;
        // Both strings have to fit the plate. A larger size clips "RetroRPN" and the name.
        float creditSize = Math.max(6.5f, inner * 0.042f);
        DisplaySettingsView.styleText(creditTitle, textColor);
        DisplaySettingsView.styleText(creditAuthor, textColor);
        creditTitle.setTextSize(TypedValue.COMPLEX_UNIT_PX, creditSize);
        creditAuthor.setTextSize(TypedValue.COMPLEX_UNIT_PX, creditSize);
        int gearSize = Math.round(Math.min(creditH - 5f, creditSize * 1.65f));
        Drawable gear = usesLed ? creditLedGear : creditGear;
        if (creditTitle.getCompoundDrawables()[0] != gear || gear.getBounds().width() != gearSize) {
            gear.setBounds(0, 0, gearSize, gearSize);
            creditTitle.setCompoundDrawables(gear, null, null, null);
            creditTitle.setCompoundDrawablePadding(Math.round(creditSize * 0.45f));
        }
        place(creditTitle, origin + 6f, creditTop, inner * 0.46f, creditH - 2f);
        int authorLeft = Math.round(origin + 6f + inner * 0.46f);
        int authorTop = Math.round(creditTop);
        int authorWidth = Math.round(inner * 0.52f);
        int authorHeight = Math.round(creditH - 2f);
        place(creditAuthor, authorLeft, authorTop, authorWidth, authorHeight);

        if (showsSettings) {
            place(settings, origin, origin, side, side);
            settings.update(usesLed, stackXOnTop, leftHanded);
            settings.setVisibility(View.VISIBLE);
        } else {
            settings.setVisibility(View.GONE);
        }

        renderValue(calc.getY(), Calculator.format(calc.getY()), 1);
        renderValue(calc.getZ(), Calculator.format(calc.getZ()), 2);
        renderValue(calc.getT(), Calculator.format(calc.getT()), 3);
        renderValue(calc.getStored(), Calculator.format(calc.getStored()), 4);
    }

    private void hideStack() {
        hidePortrait();
        showsSettings = false;
        if (stackPanel == null) return;
        stackPanel.setVisibility(View.GONE);
        settings.setVisibility(View.GONE);
        for (TextView label : stackLabels) {
            if (label != null) label.setVisibility(View.GONE);
        }
        if (creditTitle != null) creditTitle.setVisibility(View.GONE);
        if (creditAuthor != null) creditAuthor.setVisibility(View.GONE);
        for (int register = 0; register < 4; register++) {
            for (int i = 0; i < 7; i++) {
                lcdDigits[i][register].setScaleType(ImageView.ScaleType.FIT_CENTER);
                lcdDots[i][register].setScaleType(ImageView.ScaleType.FIT_CENTER);
            }
        }
        for (int i = 0; i < 7; i++) {
            if (lcdDigits[i][4] != null) lcdDigits[i][4].setVisibility(View.GONE);
            if (lcdDots[i][4] != null) lcdDots[i][4].setVisibility(View.GONE);
        }
        for (Map.Entry<View, RelativeLayout.LayoutParams> entry : collapsedLayout.entrySet()) {
            entry.getKey().setLayoutParams(new RelativeLayout.LayoutParams(entry.getValue()));
        }
    }

    private void rememberCollapsed() {
        if (!collapsedLayout.isEmpty()) return;
        for (int register = 0; register < 4; register++) {
            for (int i = 0; i < 7; i++) {
                keepLayout(lcdDigits[i][register]);
                keepLayout(lcdDots[i][register]);
            }
        }
        keepLayout(lcdRec);
        keepLayout(lcdF);
        keepLayout(lcdG);
        keepLayout(lcdEdit);
    }

    private void keepLayout(View view) {
        RelativeLayout.LayoutParams lp = (RelativeLayout.LayoutParams) view.getLayoutParams();
        collapsedLayout.put(view, new RelativeLayout.LayoutParams(lp));
    }

    private void place(View view, float left, float top, float width, float height) {
        RelativeLayout.LayoutParams lp = new RelativeLayout.LayoutParams(
                Math.max(1, Math.round(width)), Math.max(1, Math.round(height)));
        lp.leftMargin = Math.round(left);
        lp.topMargin = Math.round(top);
        view.setLayoutParams(lp);
    }

    private void ensureRoundStack(RelativeLayout parent) {
        if (stackPanel != null) return;
        GradientDrawable plate = new GradientDrawable();
        plate.setCornerRadius(8f);
        stackPanel = new View(this);
        stackPanel.setBackground(plate);
        stackPanel.setVisibility(View.GONE);
        parent.addView(stackPanel, 1);

        for (int i = 0; i < 7; i++) {
            ImageView digit = new ImageView(this);
            digit.setScaleType(ImageView.ScaleType.FIT_XY);
            digit.setVisibility(View.GONE);
            parent.addView(digit);
            lcdDigits[i][4] = digit;
            ImageView dot = new ImageView(this);
            dot.setScaleType(ImageView.ScaleType.FIT_XY);
            dot.setVisibility(View.GONE);
            parent.addView(dot);
            lcdDots[i][4] = dot;
        }
        for (int register = 0; register < 5; register++) {
            TextView label = new TextView(this);
            label.setText(STACK_LABELS[register]);
            label.setTextColor(CalculatorFace.LCD_TEXT);
            label.setTypeface(Typeface.create("sans-serif-medium", Typeface.BOLD));
            label.setGravity(Gravity.RIGHT | Gravity.CENTER_VERTICAL);
            label.setIncludeFontPadding(false);
            label.setVisibility(View.GONE);
            parent.addView(label);
            stackLabels[register] = label;
        }
        String version = "1.6";
        try {
            String name = getPackageManager().getPackageInfo(getPackageName(), 0).versionName;
            if (name != null) version = name;
        } catch (Exception ignored) {
        }
        creditTitle = creditText("RetroRPN " + version, Gravity.LEFT | Gravity.CENTER_VERTICAL);
        creditTitle.setPadding(3, 0, 0, 0);
        creditGear = getDrawable(R.drawable.settings_gear).mutate();
        creditLedGear = getDrawable(R.drawable.led_settings_gear).mutate();
        creditAuthor = creditText("Ashley Feniello", Gravity.RIGHT | Gravity.CENTER_VERTICAL);
        creditAuthor.setPadding(0, 0, 3, 0);
        creditAuthor.setOnClickListener(view -> showPortrait());
        creditTitle.setContentDescription("Settings");
        creditTitle.setOnClickListener(view -> {
            showsSettings = true;
            render();
        });
        parent.addView(creditTitle);
        parent.addView(creditAuthor);

        portraitView = new FacePortrait(this);
        portraitView.setContentDescription("Portrait saying Howdy! Close the display");
        portraitView.setOnClickListener(view -> keypress(-1, 0, true));
        portraitView.setVisibility(View.GONE);
        parent.addView(portraitView);

        settings = new DisplaySettingsView(this, this::closeSettings, () -> {
            usesLed = !usesLed;
            StateStore.setUsesLed(this, usesLed);
            render();
        }, this::flipStack, () -> {
            leftHanded = !leftHanded;
            StateStore.setLeftHanded(this, leftHanded);
            render();
        });
        settings.setVisibility(View.GONE);
        parent.addView(settings);
    }

    private void flipStack() {
        stackXOnTop = !stackXOnTop;
        StateStore.setStackXOnTop(this, stackXOnTop);
        render();
    }

    private void closeSettings() {
        showsSettings = false;
        render();
    }

    @Override
    public void onBackPressed() {
        if (showsSettings) closeSettings();
        else super.onBackPressed();
    }

    private void showPortrait() {
        if (portraitView == null || stackPanel == null) return;
        portraitView.setUsesLed(usesLed);
        RelativeLayout.LayoutParams panel = (RelativeLayout.LayoutParams) stackPanel.getLayoutParams();
        RelativeLayout.LayoutParams lp = new RelativeLayout.LayoutParams(panel.width, panel.height);
        lp.leftMargin = panel.leftMargin;
        lp.topMargin = panel.topMargin;
        portraitView.setLayoutParams(lp);
        portraitView.setVisibility(View.VISIBLE);
        portraitView.bringToFront();
    }

    private void hidePortrait() {
        if (portraitView != null) portraitView.setVisibility(View.GONE);
    }

    private TextView creditText(String text, int gravity) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextColor(0xFF282828);
        view.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        view.setGravity(gravity);
        view.setIncludeFontPadding(false);
        view.setMaxLines(1);
        view.setVisibility(View.GONE);
        return view;
    }

    private static boolean isEmulator() {
        String fingerprint = Build.FINGERPRINT;
        String hardware = Build.HARDWARE;
        String product = Build.PRODUCT;
        return fingerprint.startsWith("generic")
                || fingerprint.contains("emulator")
                || fingerprint.contains("sdk_gphone")
                || hardware.contains("ranchu")
                || hardware.contains("goldfish")
                || product.contains("sdk");
    }
}