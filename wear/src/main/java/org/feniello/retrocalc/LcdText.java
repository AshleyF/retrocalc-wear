package org.feniello.retrocalc;

/** Mantissa clipping shared with the Apple LCD renderer. */
final class LcdText {
    private LcdText() {}

    /** Drop a mantissa that does not fit, and the trailing zeros that cut leaves behind. */
    static String clipMantissa(String mantissa, int maxLength) {
        if (mantissa.length() <= maxLength) return mantissa;
        return stripTrailingFractionZeros(mantissa.substring(0, maxLength));
    }

    private static String stripTrailingFractionZeros(String mantissa) {
        int dot = mantissa.indexOf('.');
        if (dot < 0) return mantissa;
        int end = mantissa.length();
        while (end > dot + 1 && mantissa.charAt(end - 1) == '0') end--;
        if (end == dot + 1) return mantissa.substring(0, dot);
        return mantissa.substring(0, end);
    }
}
