package org.feniello.retrocalc;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.view.View;
import android.util.Base64;

/** The same face picture the Apple stack shows when the name is tapped. */
final class FacePortrait extends View {
    private static final int SIDE = 80;
    private static final int COLUMNS = 100;
    private static final int[] LCD_COLORS = {
        0xFF60695B, 0xFF4A5045, 0xFF282828, CalculatorFace.LCD_TEXT, CalculatorFace.LCD
    };
    private static final int[] LED_COLORS = {
        0xFF391417, 0xFFDC514A, 0xFF702326, CalculatorFace.LED_TEXT, CalculatorFace.LED
    };

    // '#' is bubble ink, '+' is lettering, and '.' leaves the portrait visible.
    private static final String[] SPEECH = {
        "...........#########################...",
        ".........#############################.",
        "........###############################",
        "........###+##+###############+######+#",
        "........###+##+###############+######+#",
        "........###+##+##++##+###+##+++#+##+#+#",
        "......#####++++#+##+#+#+#+#+##+#+##+#+#",
        "....#######+##+#+##+#+#+#+#+##+#+##+#+#",
        "###########+##+#+##+#+#+#+#+##+##+++###",
        "...########+##+##++###+#+###+++####+#+#",
        "......##########################+++####",
        "........###############################",
        "........###############################",
        ".........#############################.",
        "...........#########################..."
    };

    private final Paint paint = new Paint();
    private boolean usesLed;

    FacePortrait(Context context) {
        super(context);
    }

    void setUsesLed(boolean enabled) {
        if (usesLed == enabled) return;
        usesLed = enabled;
        invalidate();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        int pitch = Math.max(1, (int) Math.min(getWidth() * 0.96f / COLUMNS, (float) getHeight() / SIDE));
        int side = Math.max(1, pitch - 1);
        int left = (getWidth() - COLUMNS * pitch) / 2;
        int top = (getHeight() - SIDE * pitch) / 2;
        int[] colors = usesLed ? LED_COLORS : LCD_COLORS;
        for (int row = 0; row < SIDE; row++) {
            int y = top + row * pitch;
            for (int column = 0; column < COLUMNS; column++) {
                int x = left + column * pitch;
                paint.setColor(colors[CELLS[row * COLUMNS + column]]);
                canvas.drawRect(x, y, x + side, y + side, paint);
            }
        }
    }

    private static byte[] decodeCells() {
        byte[] data = Base64.decode(PACKED, Base64.DEFAULT);
        byte[] cells = new byte[SIDE * COLUMNS];
        int limit = Math.min(SIDE * SIDE, data.length * 4);
        for (int index = 0; index < limit; index++) {
            int shift = (3 - (index % 4)) * 2;
            int level = (data[index / 4] >> shift) & 3;
            cells[index / SIDE * COLUMNS + index % SIDE] = (byte) Math.min(level, 2);
        }
        for (int row = 0; row < SPEECH.length; row++) {
            String line = SPEECH[row];
            for (int column = 0; column < line.length(); column++) {
                char pixel = line.charAt(column);
                int index = (row + 46) * COLUMNS + column + 57;
                if (pixel == '#') cells[index] = 3;
                if (pixel == '+') cells[index] = 4;
            }
        }
        return cells;
    }

    private static final String PACKED = "AAAAAAAAAAAAKAAqAAAAAAAAAAAAAAAAAAAAAAKqqqqgAAAAAAAAAAAAAAAAAAAAKqqqqqgAAAAAAAAAAAAAAAAAAAKqqqqqqgAAAAAAAAAAAAAAAAAAqqqqqqqqgAAAAAAAAAAAAAAAACqqqqqqqqogAAAAAAAAAAAAAAACqqqqqqqqqqgAAAAAAAAAAAAAAAqqqqqqqqqqqgAAAAAAAAAAAAAACqqqqqqqqqqqgAAAAAAAAAAAAAAqqqqqqqqqqqqgAAAAAAAAAAAAACqqqqqqqqqqqqgAAAAAAAAAAAAAqqqqqqlZqqqqqgAAAAAAAAAAAACqqqqqVVVaqqqqAAAAAAAAAAAAAKqqqpVVVVVqqqqgAAAAAAAAAAACqqqpVVVVVVaqqqAAAAAAAAAAAAqqqpVVVVVVVWqqqAAAAAAAAAAAKqqqVVVVVVVVWqqqAAAAAAAAAAAqqqpVVVVVVVVWqqgAAAAAAAAAACqqqlVVVVVVVVaqqgAAAAAAAAAAqqqpVVVVVVVVVaqqAAAAAAAAAACqqqVVVVVVVVVVqqoAAAAAAAAAAKqqpVVVVVVVVVVqqgAAAAAAAAAAqqqVVVVVVVVVVWqqAAAAAAAAAACqqpVVVVVVVVVVaqgAAAAAAAAAAKqqpVVVVVVVVVVaqAAAAAAAAAAAKqqlVVVVVVVVVVqoAAAAAAAAAAAqqqVVVVVVVVVVWqAAAAAAAAAAACqqqVVVVVVVVVVaqAAAAAAAAAAACqqlVVVVVVVVVVqoAAAAAAAAAAAKqqlVValVVVVVWqAAAAAAAAAAAAqqqlVqqVVWqVVaoAAAAAAAAAAAKqqWWqqpVVaqqVqgAAAAAAAAAAAKqqmqqqlVVqqqWqAAAAAAAAAAAAqqlqpVWpVaWpqaoAAAAAAAAAAACqqaqlZWlWlZVqqgAAAAAAAAAAAKqlaqqqWlWqqmlqAAAAAAAAAAAAqqVqqqaaVaqqqWoAAAAAAAAAAACqpVqmlVpVVaWlaAAAAAAAAAAAAKqlVqqVWVVWpqVoAAAAAAAAAAACqqVWVVVVVVVVVWgAAAAAAAAAAAKqqVWVVVVVVVVVaAAAAAAAAAAAAqqpVVVVVVVVVVVoAAAAAAAAAAACqqlVVVVVVVVVVWgAAAAAAAAAAACqqVVVVWVVVVVVYAAAAAAAAAAAAKqpVVVVlVVZVVVgAAAAAAAAAAAAmqpVVVWWlVZVVWAAAAAAAAAAAACaqlVVVZqlplVVYAAAAAAAAAAAAAqqVVVVqqqllVVgAAAAAAAAAAAAJqpVVVWqqqVVVWAAAAAAAAAAAAAKqpVVVqqqqWVVYAAAAAAAAAAAAAKqqVVaqqqqmVVgAAAAAAAAAAAAAqqlVmqqVaqpVaAAAAAAAAAAAAACqqlWqqlWqqpWoAAAAAAAAAAAAACqqVaqqqlaqlaAAAAAAAAAAAAAAqqpVqqlVVWpVoAAAAAAAAAAAAAAqqlWqpVVVWVagAAAAAAAAAAAAACqqVWqqqqpVVoAAAAAAAAAAAAAAKqqlVaqqqlZWgAAAAAAAAAAAAAAKqqVWaqWqZlqAAAAAAAAAAAAAAAKqqaZWZWWVqgAAAAAAAAAAAAAACqqqqpqpVqqqAAAAAAAAAAAAACqqqqqqqmqqqqgAAAAAAAAAAAAAKqqqqqqqqqmqoAAAAAAAAAAAAAAKqqqqqqqqmaqgAAAAAAAAAAAAAAKqqqqqqqqqqoAAAAAAAAAAAAAAAKqqqqqqqqqqAAAAAAAAAAAAAAAAKqqqqqqqqqgAAAAAAAAAAAAAAAAKqqqqqqqqqAAAAAAAAAAAAAAAAAKqqqqqqqqoAAAAAAAAAAAAAAAAAKqqqqqqqqAAAAAAAAAAAAAAAAAAKqqqqqqqoAAAAAAAAAAAAAAAAAAKqqqqqqqgAAAAAAAAAAAAAAAAAAKqqqqqZoAAAAAAAAAAAAAAAAAAAKqqqqlZgAAAAAAAAAAAAAAAAAAAKqqqqmaAAAAAAAAAAAAAAAAAAAAKqVqqagAAAAAAAAAAAAAAAAAAAAKlVWqpYAAAAAAAAAAAAAAAAAAAAJVVWVmgAAAAAAAAAAAAAAAAAAAAJVVVVWAAAAAAAAAAAAAAAAAAAAAKVVVVYAAAAAAAAAA==";
    private static final byte[] CELLS = decodeCells();
}
