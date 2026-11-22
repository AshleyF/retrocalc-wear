package org.feniello.retrocalc;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/** The stack, modes, and programs, kept the way the Apple app keeps them. */
final class StateStore {
    private static final String PREFS = "retrorpn";
    private static final String KEY = "state";
    private static final String STACK_X_ON_TOP = "stackXOnTop";

    private StateStore() {}

    static void save(Context context, Calculator.Snapshot snap) {
        try {
            JSONObject json = new JSONObject();
            putDouble(json, "x", snap.x);
            putDouble(json, "y", snap.y);
            putDouble(json, "z", snap.z);
            putDouble(json, "t", snap.t);
            putDouble(json, "stored", snap.stored);
            json.put("display", snap.display);
            json.put("editing", snap.editing);
            json.put("fMode", snap.fMode);
            json.put("gMode", snap.gMode);
            json.put("recMode", snap.recMode);
            json.put("fullscreen", snap.fullscreen);
            json.put("progNum", snap.progNum);
            JSONArray programs = new JSONArray();
            for (java.util.List<Integer> program : snap.programs) {
                JSONArray keys = new JSONArray();
                for (Integer key : program) keys.put(key);
                programs.put(keys);
            }
            json.put("programs", programs);
            JSONArray values = new JSONArray();
            for (double value : snap.values) values.put(doubleText(value));
            json.put("values", values);
            json.put("letterStore", snap.letterStore);
            json.put("letterRecall", snap.letterRecall);
            prefs(context).edit().putString(KEY, json.toString()).apply();
        } catch (JSONException ignored) {
        }
    }

    static Calculator.Snapshot load(Context context) {
        String raw = prefs(context).getString(KEY, null);
        if (raw == null) return null;
        try {
            JSONObject json = new JSONObject(raw);
            Calculator.Snapshot snap = new Calculator.Snapshot();
            snap.x = getDouble(json, "x");
            snap.y = getDouble(json, "y");
            snap.z = getDouble(json, "z");
            snap.t = getDouble(json, "t");
            snap.stored = getDouble(json, "stored");
            snap.display = json.optString("display", "0");
            snap.editing = json.optBoolean("editing", true);
            snap.fMode = json.optBoolean("fMode");
            snap.gMode = json.optBoolean("gMode");
            snap.recMode = json.optBoolean("recMode");
            snap.fullscreen = json.optBoolean("fullscreen");
            snap.progNum = json.optInt("progNum");
            snap.programs = new java.util.ArrayList<>();
            JSONArray programs = json.optJSONArray("programs");
            for (int i = 0; i < 4; i++) {
                java.util.List<Integer> keys = new java.util.ArrayList<>();
                if (programs != null && i < programs.length()) {
                    JSONArray stored = programs.optJSONArray(i);
                    if (stored != null) {
                        for (int k = 0; k < stored.length(); k++) keys.add(stored.getInt(k));
                    }
                }
                snap.programs.add(keys);
            }
            snap.values = new double[4];
            JSONArray values = json.optJSONArray("values");
            if (values != null) {
                for (int i = 0; i < 4 && i < values.length(); i++) snap.values[i] = readDouble(values.get(i));
            }
            snap.letterStore = json.optBoolean("letterStore");
            snap.letterRecall = json.optBoolean("letterRecall");
            return snap;
        } catch (JSONException ignored) {
            return null;
        }
    }

    /** False draws the manual's stack, with X at the bottom. True puts X on top. */
    static boolean stackXOnTop(Context context) {
        return prefs(context).getBoolean(STACK_X_ON_TOP, false);
    }

    static void setStackXOnTop(Context context, boolean xOnTop) {
        prefs(context).edit().putBoolean(STACK_X_ON_TOP, xOnTop).apply();
    }

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private static void putDouble(JSONObject json, String key, double value) throws JSONException {
        json.put(key, doubleText(value));
    }

    private static Object doubleText(double value) {
        if (Double.isNaN(value)) return "nan";
        if (value == Double.POSITIVE_INFINITY) return "inf";
        if (value == Double.NEGATIVE_INFINITY) return "-inf";
        return value;
    }

    private static double getDouble(JSONObject json, String key) throws JSONException {
        return readDouble(json.get(key));
    }

    private static double readDouble(Object value) {
        if ("nan".equals(value)) return Double.NaN;
        if ("inf".equals(value)) return Double.POSITIVE_INFINITY;
        if ("-inf".equals(value)) return Double.NEGATIVE_INFINITY;
        return ((Number) value).doubleValue();
    }
}
