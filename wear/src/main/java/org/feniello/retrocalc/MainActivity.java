package org.feniello.retrocalc;

import android.app.Activity;
import android.os.Bundle;
import android.support.wearable.view.WatchViewStub;
import android.widget.TextView;
import android.widget.ImageView;
import android.view.View;
import android.view.MotionEvent;
import android.os.Vibrator;
import android.content.Context;
import java.util.Vector;
import java.util.Enumeration;
import java.text.DecimalFormat;
import android.view.WindowInsets;

public class MainActivity extends Activity {

    private Vibrator mVibrator;
    private ImageView imageBackground;

    private double x = 0;
    private double y = 0;
    private double z = 0;
    private double t = 0;
    private String display = "0";
    private boolean editing = true;
    private boolean recMode = false;
    private boolean fMode = false;
    private boolean gMode = false;
    private boolean fullscreen = false;
    private ImageView[][] lcdDigits = new ImageView[7][4];
    private ImageView[][] lcdDots = new ImageView[7][4];
    private ImageView lcdRec;
    private ImageView lcdF;
    private ImageView lcdG;
    private ImageView lcdEdit;
    private double stored = 0;
    private Vector[] prog = { new Vector(), new Vector(), new Vector(), new Vector() };
    private int progNum = 0;
    private boolean isRound = false;

    private void startRecording(int n) {
        recMode = true;
        progNum = n;
        prog[n].clear();
    }

    private void recordKey(int c, int r) {
        int k = c + r * 5;
        prog[progNum].add(k);
    }

    private void stopRecording() {
        prog[progNum].removeElementAt(prog[progNum].size() - 1); // rec or g
        prog[progNum].removeElementAt(prog[progNum].size() - 1); // g or f
        recMode = false;
    }

    private void playRecording(int p) {
        Enumeration e = prog[p].elements();
        while(e.hasMoreElements()) {
            int k = (int)e.nextElement();
            int c = k % 5;
            int r = k / 5;
            keypress(r, c, false);
        }
    }

    private void renderDigit(char c, ImageView iv) {
        switch (c)
        {
            case '-':
                iv.setImageResource(R.drawable.display_neg);
                break;
            case '0':
                iv.setImageResource(R.drawable.display0);
                break;
            case '1':
                iv.setImageResource(R.drawable.display1);
                break;
            case '2':
                iv.setImageResource(R.drawable.display2);
                break;
            case '3':
                iv.setImageResource(R.drawable.display3);
                break;
            case '4':
                iv.setImageResource(R.drawable.display4);
                break;
            case '5':
                iv.setImageResource(R.drawable.display5);
                break;
            case '6':
                iv.setImageResource(R.drawable.display6);
                break;
            case '7':
                iv.setImageResource(R.drawable.display7);
                break;
            case '8':
                iv.setImageResource(R.drawable.display8);
                break;
            case '9':
                iv.setImageResource(R.drawable.display9);
                break;
        }
    }

    private void renderValue(double dv, String v, int reg) {
        // reset dots
        int d = 6;
        for (int i = 0; i < 7; i++) {
            lcdDots[i][reg].setImageResource(R.drawable.dot_none);
        }

        if (v.equals("Infinity")) {
            lcdDigits[0][reg].setImageResource(R.drawable.display_none);
            lcdDigits[1][reg].setImageResource(R.drawable.display_none);
            lcdDigits[2][reg].setImageResource(R.drawable.display1);
            lcdDigits[3][reg].setImageResource(R.drawable.display_n);
            lcdDigits[4][reg].setImageResource(R.drawable.display_f);
            lcdDigits[5][reg].setImageResource(R.drawable.display_i);
            lcdDigits[6][reg].setImageResource(R.drawable.display_n);
            return;
        }

        if (v.equals("-Infinity")) {
            lcdDigits[0][reg].setImageResource(R.drawable.display_none);
            lcdDigits[1][reg].setImageResource(R.drawable.display_neg);
            lcdDigits[2][reg].setImageResource(R.drawable.display1);
            lcdDigits[3][reg].setImageResource(R.drawable.display_n);
            lcdDigits[4][reg].setImageResource(R.drawable.display_f);
            lcdDigits[5][reg].setImageResource(R.drawable.display_i);
            lcdDigits[6][reg].setImageResource(R.drawable.display_n);
            return;
        }

        if (v.equals("NaN")) {
            lcdDigits[0][reg].setImageResource(R.drawable.display_none);
            lcdDigits[1][reg].setImageResource(R.drawable.display_none);
            lcdDigits[2][reg].setImageResource(R.drawable.display_e);
            lcdDigits[3][reg].setImageResource(R.drawable.display_r);
            lcdDigits[4][reg].setImageResource(R.drawable.display_r);
            lcdDigits[5][reg].setImageResource(R.drawable.display_o);
            lcdDigits[6][reg].setImageResource(R.drawable.display_r);
            if (reg == 0) x = 0; // reset value
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
                DecimalFormat formatter = new DecimalFormat("0.0####E0");
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
            v = v.substring(0, maxlen);
        }
        for (int i = v.length() - 1; i >= 0; i--) {
            char c = v.charAt(i);
            if (c == '.') {
                lcdDots[d][reg].setImageResource(R.drawable.dot);
            } else {
                renderDigit(c, lcdDigits[d][reg]);
                d--;
            }
        }

        // reset remaining leading digits
        while (d >= 0) {
            lcdDigits[d][reg].setImageResource(R.drawable.display_none);
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
            if (!neg) lcdDigits[d][reg].setImageResource(R.drawable.display_none);
        }
    }

    private void render() {
        if (fullscreen) {
            imageBackground.setImageResource(R.drawable.calc_screen);
            for (int j = 1; j < 4; j++) {
                for (int i = 0; i < 7; i++) {
                    lcdDigits[i][j].setVisibility(View.VISIBLE);
                    lcdDots[i][j].setVisibility(View.VISIBLE);
                }
            }
            renderValue(y, displayValue(y), 1);
            renderValue(z, displayValue(z), 2);
            renderValue(t, displayValue(t), 3);
        } else {
            if (isRound)
                imageBackground.setImageResource(R.drawable.calc_round);
            else
                imageBackground.setImageResource(R.drawable.calc);
            for (int j = 1; j < 4; j++) {
                for (int i = 0; i < 7; i++) {
                    lcdDigits[i][j].setVisibility(View.INVISIBLE);
                    lcdDots[i][j].setVisibility(View.INVISIBLE);
                }
            }
        }
        lcdRec.setImageResource(recMode ? R.drawable.sym_rec : R.drawable.sym_rec_none);
        lcdF.setImageResource(fMode ? R.drawable.sym_f : R.drawable.sym_f_none);
        lcdG.setImageResource(gMode ? R.drawable.sym_g : R.drawable.sym_g_none);
        lcdEdit.setImageResource(editing ? R.drawable.sym_editing : R.drawable.sym_editing_none);
        updateVal();
        renderValue(x, display, 0);
    }

    private void error() {

    }

    private void overflow() {

    }

    private int displayLength() {
        int len = display.length();
        if (display.contains(".")) len--;
        return len;
    }

    private String displayValue(double v) {
        if (v == (long)v) {
            return String.format("%d", (long)v);
        } else {
            String d = String.format("%s", v);
            if (d == "Infinity") return "9.999E99";
            else if (d == "-Infinity") return "9999E-99";
            return d;
        }
    }

    private void updateDisplay() {
        display = displayValue(x);
    }

    private void updateVal() {
        x = Double.parseDouble(display);
    }

    private void digit(char d) {
        // TODO: handle displayable range
        if (!editing) {
            push();
            display = "";
            editing = true;
        }
        if (display.compareTo("0") == 0) display = "";
        if (display.compareTo("-0") == 0) display = "-";
        if (displayLength() < 7) {
            display += d;
            updateVal();
        }
        else error();
    }

    private void decimalPoint() {
        if (!editing) {
            push();
            x = 0;
            updateDisplay();
            editing = true;
        }
        if (display.contains("."))
            error();
        else {
            display += '.';
            updateVal();
        }
    }

    private void changeSign() {
        if (display.charAt(0) == '-') {
            display = display.substring(1);
            updateVal();
        } else {
            display = '-' + display;
            updateVal();
        }
    }

    private void del() {
        if (!display.equals("0") && !display.equals("-0")) {
            int len = display.length();
            if (len > 1) {
                display = display.substring(0, len - 1);
            }
            else {
                display = "0";
            }
            updateVal();
        }
    }

    private void push() {
        t = z;
        z = y;
        y = x;
    }

    private void pop() {
        x = y;
        y = z;
        z = t;
    }

    private void unOp(double v) {
        x = v;
        editing = false;
        updateDisplay();
    }

    private void binOp(double v) {
        pop();
        unOp(v);
    }

    private void constant(double v) {
        push();
        x = v;
        editing = false;
        updateDisplay();
    }

    private void vibrate() {
        if (mVibrator == null)
            mVibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
        if (mVibrator != null) mVibrator.vibrate(15);
    }

    private void keypress(int row, int column, boolean update) {
        if (recMode) recordKey(column, row);
        if (fullscreen || row < 0) {
            fullscreen = !fullscreen;
        } else {
            if (update) vibrate();
            if (fMode) {
                fMode = false;
                switch (column + row * 5) {
                    case 0: // play a or 1/x
                        if (isRound) {
                            unOp(1.0 / x);
                        } else {
                            if (!recMode || progNum != 0)
                                playRecording(0);
                        }
                        break;
                    case 1: // play b
                        if (!recMode || progNum != 1)
                            playRecording(1);
                        break;
                    case 2: // play c
                        if (!recMode || progNum != 2)
                            playRecording(2);
                        break;
                    case 3: // play d
                        if (!recMode || progNum != 3)
                            playRecording(3);
                        break;
                    case 4: // f
                        fMode = false;
                        break;
                    case 5: // y^x
                        binOp(Math.pow(y, x));
                        break;
                    case 6: // e^x
                        unOp(Math.pow(Math.E, x));
                        break;
                    case 7: // 10^x
                        unOp(Math.pow(10.0, x));
                        break;
                    case 8: // 1/x or a
                        if (isRound) {
                            if (!recMode || progNum != 0)
                                playRecording(0);
                        } else {
                            unOp(1.0 / x);
                        }
                        break;
                    case 9: // g
                        if (recMode) {
                            stopRecording();
                        } else {
                            gMode = true;
                        }
                        break;
                    case 10: // ran
                        constant(Math.random());
                        break;
                    case 11: // sin
                        unOp(Math.sin(x));
                        break;
                    case 12: // cos
                        unOp(Math.cos(x));
                        break;
                    case 13: // tan
                        unOp(Math.tan(x));
                        break;
                    case 14: // CLx
                    case 19: // CLx
                        x = 0;
                        updateDisplay();
                        editing = false;
                        break;
                    case 15: // STO
                        stored = x;
                        break;
                    case 16: // e
                        constant(Math.E);
                        break;
                    case 17: // x<->y
                        double temp = x;
                        x = y;
                        y = temp;
                        updateDisplay();
                        editing = false;
                        break;
                    case 18: // R down
                        temp = t;
                        t = z;
                        z = y;
                        y = x;
                        x = temp;
                        updateDisplay();
                        editing = false;
                        break;
                }
            }
            else if (gMode) {
                gMode = false;
                switch (column + row * 5) {
                    case 0: // rec a or int
                        if (isRound) {
                            unOp((double)((int)x));
                        } else {
                            if (recMode) stopRecording();
                            else startRecording(0);
                        }
                        break;
                    case 1: // rec b
                        if (recMode) stopRecording();
                        else startRecording(1);
                        break;
                    case 2: // rec c
                        if (recMode) stopRecording();
                        else startRecording(2);
                        break;
                    case 3: // rec d
                        if (recMode) stopRecording();
                        else startRecording(3);
                        break;
                    case 4: // f
                        fMode = true;
                        break;
                    case 5: // x root y
                        binOp(Math.pow(y, 1.0 / x));
                        break;
                    case 6: // ln
                        unOp(Math.log(x));
                        break;
                    case 7: // log
                        unOp(Math.log10(x));
                        break;
                    case 8: // int or rec a
                        if (isRound) {
                            if (recMode) stopRecording();
                            else startRecording(0);
                        } else {
                            unOp((double)((int)x));
                        }
                        break;
                    case 9: // g
                        gMode = false;
                        break;
                    case 10: // abs
                        unOp(Math.abs(x));
                        break;
                    case 11: // sin-1
                        unOp(Math.asin(x));
                        break;
                    case 12: // cos-1
                        unOp(Math.acos(x));
                        break;
                    case 13: // tan-1
                        unOp(Math.atan(x));
                        break;
                    case 14: // del
                    case 19: // del
                        del();
                        break;
                    case 15: // RCL
                        constant(stored);
                        break;
                    case 16: // pi
                        constant(Math.PI);
                        break;
                    case 17: // over
                        constant(y);
                        break;
                    case 18: // R up
                        double temp = x;
                        x = y;
                        y = z;
                        z = t;
                        t = temp;
                        updateDisplay();
                        editing = false;
                        break;
                }
            }
            else {
                switch (column + row * 5) {
                    case 0: // divide
                        binOp(y / x);
                        break;
                    case 1: // 7
                        digit('7');
                        break;
                    case 2: // 8
                        digit('8');
                        break;
                    case 3: // 9
                        digit('9');
                        break;
                    case 4: // f
                        fMode = true;
                        break;
                    case 5: // multiply
                        binOp(y * x);
                        break;
                    case 6: // 4
                        digit('4');
                        break;
                    case 7: // 5
                        digit('5');
                        break;
                    case 8: // 6
                        digit('6');
                        break;
                    case 9: // g
                        gMode = true;
                        break;
                    case 10: // subtract
                        binOp(y - x);
                        break;
                    case 11: // 1
                        digit('1');
                        break;
                    case 12: // 2
                        digit('2');
                        break;
                    case 13: // 3
                        digit('3');
                        break;
                    case 14: // ENTER
                    case 19: // ENTER
                        if (!editing) push();
                        editing = false;
                        break;
                    case 15: // add
                        binOp(y + x);
                        break;
                    case 16: // 0
                        digit('0');
                        break;
                    case 17: // .
                        decimalPoint();
                        break;
                    case 18: // +/-
                        changeSign();
                        break;
                }
            }
        }

        if (update) render();
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        final WatchViewStub stub = (WatchViewStub)findViewById(R.id.watch_view_stub);

        final MainActivity that = this;

        stub.setOnLayoutInflatedListener(new WatchViewStub.OnLayoutInflatedListener() {
            @Override
            public void onLayoutInflated(WatchViewStub stub) {
                mVibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
                if (findViewById(R.id.LinearLayout) == null)
                    that.isRound = true;
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
                            int x = (int)event.getX();
                            int y = (int)event.getY();
                            int r = 0;
                            int c = 0;
                            if (isRound) {
                                if (y < 54) {
                                    r = 0;
                                    if (x > 109 && x < 209) {
                                        c = (x - 109) / 51;
                                    }
                                } else if (y < 103) {
                                    r = 1;
                                    if (x > 33 && x < 285) {
                                        c = (x - 33) / 51;
                                    }
                                } else if (y < 168) {
                                    // screen - TODO on round
                                } else if (y < 216) {
                                    r = 2;
                                    if (x > 8 && x < 312) {
                                        c = (x - 8) / 51;
                                    }
                                } else if (y < 265) {
                                    r = 3;
                                    if (x > 33 && x < 289) {
                                        c = (x - 33) / 51;
                                    }
                                } else {
                                    r = 4;
                                    if (x > 116 && x < 283) {
                                        c = 0;
                                    }
                                }
                                switch (c + r * 6) {
                                    case 0: // f
                                        r = 0;
                                        c = 4;
                                        break;
                                    case 1: // g
                                        r = 1;
                                        c = 4;
                                        break;
                                    case 2: // NONE
                                        break;
                                    case 3: // NONE
                                        break;
                                    case 4: // NONE
                                        break;
                                    case 5: // NONE
                                        break;
                                    case 6: // +/-
                                        r = 3;
                                        c = 3;
                                        break;
                                    case 7: // div
                                        r = 0;
                                        c = 0;
                                        break;
                                    case 8: // mul
                                        r = 1;
                                        c = 0;
                                        break;
                                    case 9: // sub
                                        r = 2;
                                        c = 0;
                                        break;
                                    case 10: // add
                                        r = 3;
                                        c = 0;
                                        break;
                                    case 11: // NONE
                                        break;
                                    case 12: // 4
                                        r = 1;
                                        c = 1;
                                        break;
                                    case 13: // 5
                                        r = 1;
                                        c = 2;
                                        break;
                                    case 14: // 6
                                        r = 1;
                                        c = 3;
                                        break;
                                    case 15: // 7
                                        r = 0;
                                        c = 1;
                                        break;
                                    case 16: // 8
                                        r = 0;
                                        c = 2;
                                        break;
                                    case 17: // 9
                                        r = 0;
                                        c = 3;
                                        break;
                                    case 18: // .
                                        r = 3;
                                        c = 2;
                                        break;
                                    case 19: // 0
                                        r = 3;
                                        c = 1;
                                        break;
                                    case 20: // 1
                                        r = 2;
                                        c = 1;
                                        break;
                                    case 21: // 2
                                        r = 2;
                                        c = 2;
                                        break;
                                    case 22: // 3
                                        r = 2;
                                        c = 3;
                                        break;
                                    case 23: // NONE
                                        break;
                                    case 24: // ENTER
                                        r = 2;
                                        c = 4;
                                        break;
                                    case 25: // NONE
                                        break;
                                    case 26: // NONE
                                        break;
                                    case 27: // NONE
                                        break;
                                    case 28: // NONE
                                        break;
                                    case 29: // NONE
                                        break;
                                }
                            } else {
                                c = x / 64;
                                r = (y - 4) / 64 - 1;
                                //mTextView1 = (TextView) stub.findViewById(R.id.textView1);
                                //if (mTextView1 != null) mTextView1.setText("Yo " + x + " (" + c + "), " + y + "(" + r + ")");
                            }
                            keypress(r, c, true);
                        }
                        return true;
                    }
                });
            }
        });

        //stub.setOnApplyWindowInsetsListener(new View.OnApplyWindowInsetsListener() {
        //	@Override
        //	public WindowInsets onApplyWindowInsets(View v, WindowInsets insets) {
        //        if(insets.isRound()) {
        //            //that.isRound = true;
        //        }

                /*
				//setContentView(R.layout.rect_activity_main); // TODO: generic
		*/
        //		return null;
        //	}
        //});
    }
}