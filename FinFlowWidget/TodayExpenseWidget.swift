import AppIntents
import SwiftUI
import WidgetKit

nonisolated struct TodayEntry: TimelineEntry {
    let date: Date
    let total: Double
    let count: Int
}

nonisolated struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, total: 0, count: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = load()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> TodayEntry {
        let today = ExpenseSummary.today()
        return TodayEntry(date: .now, total: today.total, count: today.count)
    }
}

struct TodayExpenseWidget: Widget {
    static let kind = "in.akshaux.finflow.today"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TodayProvider()) { entry in
            Button(intent: LogExpenseIntent()) {
                TodayWidgetView(entry: entry)
            }
            .buttonStyle(.plain)
            .widgetURL(URL(string: "finflow://capture"))
        }
        .configurationDisplayName("FinFlow")
        .description("Today’s spending. Tap to open FinFlow already listening.")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        var list: [WidgetFamily] = [.systemSmall, .systemMedium]
        #if os(iOS)
        list.append(contentsOf: [.accessoryCircular, .accessoryRectangular, .accessoryInline])
        #endif
        return list
    }
}

private struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TodayEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Image(systemName: "mic.fill")
                    .font(.title3.weight(.semibold))
                    .widgetAccentable()
            case .accessoryInline:
                Text("\(ExpenseMoney.rupees(entry.total)) today")
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.caption2)
                    Text(ExpenseMoney.rupees(entry.total))
                        .font(.headline)
                    Text("Tap to speak")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .systemMedium:
                medium
            default:
                compact
            }
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    @ViewBuilder
    private var widgetBackground: some View {
        #if os(iOS)
        if family == .systemSmall || family == .systemMedium {
            richBackground
        } else {
            AccessoryWidgetBackground()
        }
        #else
        if family == .systemSmall || family == .systemMedium {
            richBackground
        } else {
            Color.clear
        }
        #endif
    }

    private var richBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.09, blue: 0.09),
                Color(red: 0.04, green: 0.04, blue: 0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var compact: some View {
        VStack(alignment: .leading, spacing: 8) {
            IslandFace(side: 36)
            Text("Today")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text(ExpenseMoney.rupees(entry.total))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(entry.count == 1 ? "1 expense" : "\(entry.count) expenses")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            IslandFace(side: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text("Today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Text(ExpenseMoney.rupees(entry.total))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(entry.count == 1 ? "Tap to speak another expense" : "Tap to speak · \(entry.count) saved today")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct IslandFace: View {
    var side: CGFloat

    var body: some View {
        ZStack {
            ribbon
                .rotationEffect(.degrees(-16))
                .offset(x: -side * 0.12, y: -side * 0.22)
            ribbon
                .rotationEffect(.degrees(14))
                .offset(x: side * 0.13, y: -side * 0.24)
            Circle()
                .fill(.white)
                .frame(width: side * 0.42, height: side * 0.42)
                .shadow(color: Color(red: 0.62, green: 0.45, blue: 1).opacity(0.9), radius: side * 0.08)
        }
        .frame(width: side, height: side)
    }

    private var ribbon: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.78, green: 0.62, blue: 1),
                        Color(red: 0.45, green: 0.18, blue: 0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: side * 0.22, height: side * 0.62)
    }
}
