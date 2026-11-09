import ObjectiveC
import RetroRPNEngine
import SwiftUI
import WatchKit

struct CalculatorView: View {
    @StateObject private var calc = RPNCalculator()
    @State private var restored = false
    @State private var crownValue = 0.0
    @FocusState private var crownFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let layout = FaceLayout.measure(geo.size)
            ZStack {
                VStack(spacing: 0) {
                    Color.clear.frame(height: layout.topPad)
                    if calc.model.fullscreen {
                        stackButton
                            .frame(width: layout.keypadSize.width, height: layout.stackHeight)
                        Color.clear.frame(height: layout.topPad)
                    } else {
                        VStack(spacing: layout.gap) {
                            stackButton
                                .frame(width: layout.keypadSize.width, height: layout.displayHeight)
                            KeypadView { code in
                                pressKey(code)
                            }
                            .frame(width: layout.keypadSize.width, height: layout.keypadSize.height)
                        }
                        Color.clear.frame(height: layout.bottomPad)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        // Draw to the screen edges. The safe area on a real watch is a small
        // rectangle, which is what left the face floating in the middle.
        .ignoresSafeArea()
        .background(Theme.background)
        .scrollDisabled(true)
        // The crown turns this view. One detent is one keystroke. Up redoes.
        // Low sensitivity is the coarsest step the system offers, and the
        // click is played on that same step, so the tick and the undo stay together.
        .focusable()
        .focused($crownFocused)
        .focusEffectDisabled()
        .digitalCrownRotation(
            $crownValue,
            from: -100_000,
            through: 100_000,
            by: 1,
            sensitivity: .low,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { previous, current in
            let steps = Int(current.rounded()) - Int(previous.rounded())
            guard steps != 0, abs(steps) < 8 else { return }
            applyCrown(steps: steps)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { crownFocused = true }
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            WatchInput.releaseDelays()
            if !crownFocused { crownFocused = true }
        }
        .onAppear {
            crownFocused = true
            WatchInput.releaseDelays()
            guard !restored else { return }
            restored = true
            if let saved = CalculatorStore.load() {
                calc.restore(saved)
            }
        }
    }

    private var lcd: some View {
        LCDView(calc: calc, showsStack: calc.model.fullscreen)
    }

    /// Same immediate press as the keys, framed to the display only.
    private var stackButton: some View {
        ImmediateButton {
            calc.pressDisplay()
            commit()
        } label: {
            lcd
        }
    }

    private func pressKey(_ code: Int) {
        calc.press(row: code / 5, column: code % 5)
        WKInterfaceDevice.current().play(.click)
        commit()
    }

    /// Crown-up increases the detent and redoes one keystroke per click.
    private func applyCrown(steps: Int) {
        guard steps != 0 else { return }
        var changed = false
        if steps > 0 {
            for _ in 0..<steps where calc.redo() { changed = true }
        } else {
            for _ in 0..<(-steps) where calc.undo() { changed = true }
        }
        if changed { commit() }
    }

    private func commit() {
        CalculatorStore.save(calc.model)
    }
}

/// Keys fill the face. The LCD is only as tall as the digits, and starts just under the clock.
private struct FaceLayout {
    var topPad: CGFloat
    var bottomPad: CGFloat
    var gap: CGFloat
    var displayHeight: CGFloat
    var stackHeight: CGFloat
    var keypadSize: CGSize

    static func measure(_ size: CGSize) -> FaceLayout {
        // A hair under the clock. The previous pad let the LCD touch the time.
        let topPad = max(22, size.height * 0.112) + 3
        // Leave a sliver under the keys so they still look raised off the bezel.
        let bottomPad = max(3, size.height * 0.012)
        let side = max(4, size.width * 0.018)
        let width = max(1, size.width - side * 2)
        let height = max(1, size.height - topPad - bottomPad)
        // Close to the keys, with a visible gap so the LCD is not sitting on them.
        let gap = max(1.5, width * 0.008) + 1
        let keyWidth = (width - gap * 4) / 5
        let keypadWidth = keyWidth * 5 + gap * 4
        // Same chrome as LCDView: horizontal padding, the annunciator, and the gap beside it.
        let cellWidth = max(1, (keypadWidth - 6 - 13 - 6) / 7)
        let digitHeight = cellWidth * (53.0 / 43.0)
        let displayHeight = digitHeight + 8
        let keypadHeight = max(1, height - displayHeight - gap)
        return FaceLayout(
            topPad: topPad,
            bottomPad: bottomPad,
            gap: gap,
            displayHeight: displayHeight,
            stackHeight: max(1, size.height - topPad * 2),
            keypadSize: CGSize(width: keypadWidth, height: keypadHeight)
        )
    }
}

/// The window's flick gesture holds every touch for about a third of a second
/// while it decides the touch is not a scroll. There is no scroll view on this
/// screen, so that wait is the whole delay.
private enum WatchInput {
    static func releaseDelays() {
        guard let appType = NSClassFromString("UIApplication") as? NSObject.Type,
              let app = appType.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue() as? NSObject else {
            return
        }
        var windows: [NSObject] = []
        if let window = object(app, "keyWindow") { windows.append(window) }
        if let list = object(app, "windows") as? NSArray {
            windows.append(contentsOf: list.compactMap { $0 as? NSObject })
        }
        for window in windows { walk(window) }
    }

    private static func walk(_ view: NSObject) {
        if let scroll = NSClassFromString("UIScrollView"), view.isKind(of: scroll) {
            // The crown is this scroll view's pan. Leave the pan enabled.
            setFalse(view, "delaysContentTouches")
            setFalse(view, "canCancelContentTouches")
        }
        if let gestures = object(view, "gestureRecognizers") as? NSArray {
            for case let gesture as NSObject in gestures {
                setFalse(gesture, "delaysTouchesBegan")
                setFalse(gesture, "delaysTouchesEnded")
                let name = NSStringFromClass(type(of: gesture)).lowercased()
                if name.contains("crown") || name.contains("pan") || name.contains("scroll") { continue }
                if name.contains("flick") || name.contains("longpress") {
                    setFalse(gesture, "enabled")
                }
            }
        }
        if let subs = object(view, "subviews") as? NSArray {
            for case let sub as NSObject in subs { walk(sub) }
        }
    }

    private static func object(_ object: NSObject, _ key: String) -> NSObject? {
        let sel = NSSelectorFromString(key)
        guard object.responds(to: sel) else { return nil }
        return object.perform(sel)?.takeUnretainedValue() as? NSObject
    }

    private static func setFalse(_ object: NSObject, _ key: String) {
        let setter = "set" + key.prefix(1).uppercased() + key.dropFirst() + ":"
        guard object.responds(to: NSSelectorFromString(setter)) else { return }
        object.setValue(false, forKey: key)
    }
}
