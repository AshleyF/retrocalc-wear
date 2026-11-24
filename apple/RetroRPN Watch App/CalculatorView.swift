import ObjectiveC
import RetroRPNEngine
import SwiftUI
import WatchKit

struct CalculatorView: View {
    @StateObject private var calc = RPNCalculator()
    @State private var restored = false
    @State private var crownValue = 0.0
    @State private var flashedCode: Int?
    @State private var flashToken = 0
    @State private var keyPressCount = 0
    @State private var showsPortrait = false
    @State private var showsSettings = false
    @State private var stackXOnTop = StackOrder.xOnTop
    @AppStorage("retrorpn.usesLed") private var usesLed = true
    @AppStorage("retrorpn.leftHanded") private var leftHanded = false
    @FocusState private var crownFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let layout = FaceLayout.measure(geo.size)
            ZStack {
                VStack(spacing: 0) {
                    Color.clear.frame(height: layout.topPad)
                    if calc.model.fullscreen {
                        fullscreenFace(width: layout.keypadSize.width, height: layout.stackHeight)
                            .frame(width: layout.keypadSize.width, height: layout.stackHeight)
                        Color.clear.frame(height: layout.bottomPad)
                    } else {
                        VStack(spacing: layout.gap) {
                            stackButton
                                .frame(width: layout.keypadSize.width, height: layout.displayHeight)
                            KeypadView(
                                flashedCode: flashedCode,
                                xOnTop: stackXOnTop,
                                leftHanded: leftHanded,
                                screenSize: geo.size,
                                onEnterDown: { keyPressCount &+= 1 }
                            ) { code in
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
        .coordinateSpace(name: "watchFace")
        // Draw to the screen edges. The safe area on a real watch is a small
        // rectangle, which is what left the face floating in the middle.
        .ignoresSafeArea()
        .background {
            (calc.model.fullscreen ? (usesLed ? Theme.led : Theme.lcd) : Theme.background)
                .ignoresSafeArea()
        }
        .scrollDisabled(true)
        .sensoryFeedback(.impact(weight: .heavy), trigger: keyPressCount)
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
        .onChange(of: calc.model.fullscreen) { _, isFull in
            if !isFull {
                showsPortrait = false
                showsSettings = false
            }
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
        LCDView(calc: calc, showsStack: calc.model.fullscreen, usesLed: usesLed)
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

    /// The expanded face gives the stack labels, display theme, and portrait their own controls.
    private func fullscreenFace(width: CGFloat, height: CGFloat) -> some View {
        let contentWidth = width - 4
        let creditHeight = max(34, height - 4 - LCDView.idealStackHeight(width: contentWidth))
        return Group {
            if showsSettings {
                settingsPage
            } else if showsPortrait {
                ImmediateButton(action: collapseAll) {
                    FacePortraitView(usesLed: usesLed)
                }
            } else {
                VStack(spacing: 0) {
                    LCDView(
                        calc: calc,
                        showsStack: true,
                        usesLed: usesLed,
                        showsCredit: false,
                        drawsChrome: false,
                        stackXOnTop: stackXOnTop,
                        onLabelTap: flipStack,
                        onDigitsTap: collapseStack
                    )
                    creditRow(width: contentWidth, height: creditHeight)
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    private func creditRow(width: CGFloat, height: CGFloat) -> some View {
        let textSize = max(7, width * 0.048)
        return HStack(spacing: 0) {
            ImmediateButton(action: { showsSettings = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.system(size: textSize * 1.8, weight: .semibold))
                    Text(LCDView.creditTitle)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                }
                .accessibilityLabel("Settings")
            }
            ImmediateButton(action: { showsPortrait = true }, expands: false) {
                Text("Ashley Feniello")
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.leading, 8)
                    .padding(.trailing, 4)
            }
        }
        .font(.system(size: textSize, weight: .medium))
        .foregroundStyle(usesLed ? Theme.ledCredit : Theme.credit)
        .shadow(color: usesLed ? Theme.ledCredit.opacity(0.48) : .clear, radius: 1.15)
        .padding(.leading, 6)
        .frame(height: height)
    }

    private var settingsPage: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Settings")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Done", action: collapseAll)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
            }
            setting("Display", value: usesLed ? "LED" : "LCD") { usesLed.toggle() }
            setting("Stack", value: stackXOnTop ? "Top down" : "Bottom up", action: flipStack)
            setting("Keypad", value: leftHanded ? "Left-handed" : "Right-handed") { leftHanded.toggle() }
        }
        .font(.system(.footnote, design: .monospaced).weight(.semibold))
        .foregroundStyle(usesLed ? Theme.ledCredit : Theme.credit)
        .shadow(color: usesLed ? Theme.ledCredit.opacity(0.48) : .clear, radius: 1.15)
        .buttonStyle(SettingsButtonStyle())
        .padding(8)
    }

    private func setting(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        Button {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction, action)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                Spacer(minLength: 2)
                Text(value)
                    .bold()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .padding(.horizontal, 6)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(usesLed ? Theme.ledCredit : Theme.credit.opacity(0.55))
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private func flipStack() {
        stackXOnTop.toggle()
        StackOrder.xOnTop = stackXOnTop
    }

    private func collapseStack() {
        calc.pressDisplay()
        commit()
    }

    private func collapseAll() {
        showsSettings = false
        showsPortrait = false
        if calc.model.fullscreen {
            calc.pressDisplay()
            commit()
        }
    }

    private func pressKey(_ code: Int) {
        calc.press(row: code / 5, column: code % 5)
        if code != 14 && code != RPNCalculator.exponentKey { keyPressCount &+= 1 }
        commit()
    }

    /// Crown-up increases the detent and redoes one keystroke per click.
    private func applyCrown(steps: Int) {
        guard steps != 0 else { return }
        var changed = false
        var replayed: Int?
        if steps > 0 {
            for _ in 0..<steps where calc.redo() {
                changed = true
                replayed = calc.replayedKey
            }
        } else {
            for _ in 0..<(-steps) where calc.undo() {
                changed = true
                replayed = calc.replayedKey
            }
        }
        if let replayed { pulse(replayed) }
        if changed { commit() }
    }

    /// Undo and redo have no finger on the key. Hold the same pressed look long
    /// enough to read in a recording, then let it up.
    private func pulse(_ code: Int) {
        flashToken += 1
        let token = flashToken
        flashedCode = code == RPNCalculator.exponentKey ? 14 : code
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if flashToken == token { flashedCode = nil }
        }
    }

    private func commit() {
        CalculatorStore.save(calc.model)
    }
}

/// Show the press immediately without watchOS's default button fade.
private struct SettingsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .transaction {
                $0.animation = nil
                $0.disablesAnimations = true
            }
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
        // Clear of the clock. Three more points is about half a millimeter.
        let topPad = max(22, size.height * 0.112) + 6
        // The full-screen face extends beyond the safe area on rounded displays.
        // Leave room for the bottom corner legends while keeping the LCD under the clock.
        let bottomPad = max(8, size.height * 0.036)
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
        let displayHeight = digitHeight + 10
        let keypadHeight = max(1, height - displayHeight - gap)
        return FaceLayout(
            topPad: topPad,
            bottomPad: bottomPad,
            gap: gap,
            displayHeight: displayHeight,
            stackHeight: height,
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
