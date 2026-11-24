import SwiftUI
import WidgetKit

@main
struct RetroRPNComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RetroRPNLauncher", provider: LauncherTimeline()) { _ in
            LauncherView()
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("RetroRPN")
        .description("Open the RetroRPN calculator.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

private struct LauncherTimeline: TimelineProvider {
    struct Entry: TimelineEntry {
        let date: Date
    }

    func placeholder(in context: Context) -> Entry { Entry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [placeholder(in: context)], policy: .never))
    }
}

private struct LauncherView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("RetroRPN", systemImage: "calculator")
        case .accessoryRectangular:
            HStack {
                CalculatorMark().frame(width: 34, height: 34)
                    .accessibilityHidden(true)
                Text("RetroRPN").font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            CalculatorMark()
                .padding(4)
                .accessibilityLabel("RetroRPN calculator")
        }
    }
}

private struct CalculatorMark: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let fullColor = renderingMode == .fullColor
        Canvas { context, size in
            let unit = min(size.width, size.height) / 32
            let origin = CGPoint(x: (size.width - 32 * unit) / 2, y: (size.height - 32 * unit) / 2)
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
                CGRect(x: origin.x + x * unit, y: origin.y + y * unit, width: w * unit, height: h * unit)
            }

            let casePath = Path(roundedRect: rect(4, 1.5, 24, 29), cornerRadius: 4 * unit)
            let caseStyle: GraphicsContext.Shading = fullColor ? .color(Color(white: 0.76)) : .foreground
            context.stroke(casePath, with: caseStyle, lineWidth: 1.6 * unit)
            var display = context
            display.opacity = fullColor ? 1 : 0.22
            let displayRect = rect(7, 5, 18, 8)
            let displayStyle: GraphicsContext.Shading = fullColor
                ? .color(Color(red: 48 / 255, green: 16 / 255, blue: 19 / 255)) : .foreground
            display.fill(Path(roundedRect: displayRect, cornerRadius: unit), with: displayStyle)

            let readout = Text("RPN")
                .font(.system(size: 6.5 * unit, weight: .bold))
                .foregroundColor(fullColor ? Color(red: 1, green: 82 / 255, blue: 72 / 255) : nil)
            context.draw(readout, at: CGPoint(x: displayRect.midX, y: displayRect.midY))
            for row in 0..<3 {
                for column in 0..<3 {
                    let key = rect(8 + CGFloat(column) * 6, 15 + CGFloat(row) * 4.6, 4, 2.8)
                    let color: Color = column == 2 && row == 0 ? .orange
                        : column == 2 && row == 1 ? .blue : Color(white: 0.86)
                    let keyStyle: GraphicsContext.Shading = fullColor ? .color(color) : .foreground
                    context.fill(Path(roundedRect: key, cornerRadius: 0.7 * unit), with: keyStyle)
                }
            }
        }
    }
}
