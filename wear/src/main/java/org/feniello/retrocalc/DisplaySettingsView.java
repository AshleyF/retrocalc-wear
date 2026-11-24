package org.feniello.retrocalc;

import android.content.Context;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.LayerDrawable;
import android.util.TypedValue;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.TextView;

/** Settings drawn inside the same plate as the expanded stack. */
final class DisplaySettingsView extends LinearLayout {
    private final TextView title;
    private final TextView done;
    private final Setting display;
    private final Setting stack;
    private final Setting keypad;

    DisplaySettingsView(Context context, Runnable close, Runnable changeDisplay,
                        Runnable changeStack, Runnable changeKeypad) {
        super(context);
        setOrientation(VERTICAL);
        setClickable(true);
        setPadding(13, 12, 13, 12);
        setBackground(new GradientDrawable());

        LinearLayout heading = new LinearLayout(context);
        heading.setGravity(Gravity.CENTER_VERTICAL);
        title = text("Settings", 16, Typeface.BOLD);
        title.setAccessibilityHeading(true);
        done = text("Done", 12, Typeface.BOLD);
        done.setGravity(Gravity.CENTER);
        done.setPadding(8, 0, 8, 0);
        done.setOnClickListener(view -> close.run());
        heading.addView(title, new LayoutParams(0, LayoutParams.MATCH_PARENT, 1));
        heading.addView(done, new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.MATCH_PARENT));
        addView(heading, new LayoutParams(LayoutParams.MATCH_PARENT, 0, 1));

        display = new Setting("Display", changeDisplay);
        stack = new Setting("Stack", changeStack);
        keypad = new Setting("Keypad", changeKeypad);
    }

    void update(boolean led, boolean xOnTop, boolean leftHanded) {
        int foreground = led ? CalculatorFace.LED_TEXT : CalculatorFace.LCD_TEXT;
        GradientDrawable plate = (GradientDrawable) getBackground();
        plate.setColor(led ? CalculatorFace.LED : CalculatorFace.LCD);
        plate.setCornerRadius(8);
        styleText(title, foreground);
        styleText(done, foreground);
        done.setBackground(outline(foreground));
        display.update(led ? "LED" : "LCD", foreground);
        stack.update(xOnTop ? "Top down" : "Bottom up", foreground);
        keypad.update(leftHanded ? "Left-handed" : "Right-handed", foreground);
    }

    static void styleText(TextView view, int color) {
        view.setTextColor(color);
        if (color == CalculatorFace.LED_TEXT) view.setShadowLayer(1.8f, 0, 0, 0x7AFF5248);
        else view.setShadowLayer(0, 0, 0, 0);
    }

    private Drawable outline(int color) {
        GradientDrawable shape = new GradientDrawable();
        shape.setCornerRadius(4);
        shape.setStroke(1, color);
        if (color != CalculatorFace.LED_TEXT) return shape;

        GradientDrawable halo = new GradientDrawable();
        halo.setCornerRadius(5);
        halo.setStroke(3, 0x39FF5248);
        LayerDrawable layered = new LayerDrawable(new Drawable[] {halo, shape});
        layered.setLayerInset(1, 1, 1, 1, 1);
        return layered;
    }

    private TextView text(String value, float size, int weight) {
        TextView text = new TextView(getContext());
        text.setText(value);
        text.setTextSize(TypedValue.COMPLEX_UNIT_PX, size);
        text.setTypeface(Typeface.create("monospace", weight));
        text.setGravity(Gravity.CENTER_VERTICAL);
        text.setIncludeFontPadding(false);
        text.setSingleLine();
        return text;
    }

    private final class Setting {
        private final LinearLayout row;
        private final TextView label;
        private final TextView value;

        Setting(String name, Runnable action) {
            row = new LinearLayout(getContext());
            row.setGravity(Gravity.CENTER_VERTICAL);
            row.setPadding(8, 0, 8, 0);
            row.setOnClickListener(view -> action.run());
            label = text(name, 12, Typeface.NORMAL);
            value = text("", 12, Typeface.BOLD);
            row.addView(label, new LayoutParams(0, LayoutParams.MATCH_PARENT, 1));
            row.addView(value, new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.MATCH_PARENT));
            LayoutParams layout = new LayoutParams(LayoutParams.MATCH_PARENT, 0, 1);
            layout.topMargin = 8;
            addView(row, layout);
        }

        void update(String description, int color) {
            styleText(label, color);
            styleText(value, color);
            value.setText(description);
            row.setContentDescription(label.getText() + ", " + description);
            row.setBackground(outline(color));
        }
    }
}
