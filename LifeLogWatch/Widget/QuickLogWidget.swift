import SwiftUI
import WidgetKit
import LifeLogKit

// MARK: - Widget

struct QuickLogWidget: Widget {
    let kind: String = "QuickLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickLogProvider()) { entry in
            QuickLogWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Log")
        .description("Tap to quickly log your mood")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

// MARK: - Timeline Entry

struct QuickLogEntry: TimelineEntry {
    let date: Date
}

// MARK: - Provider

struct QuickLogProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickLogEntry {
        QuickLogEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickLogEntry) -> Void) {
        completion(QuickLogEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLogEntry>) -> Void) {
        let entry = QuickLogEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Widget View

struct QuickLogWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: QuickLogEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryInline:
            inlineView
        case .accessoryRectangular:
            rectangularView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .widgetAccentable()

                Text("Log")
                    .font(.caption2)
                    .widgetAccentable()
            }
        }
    }

    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus.circle.fill")
            Text("Quick Log")
        }
    }

    private var rectangularView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)

                    Text("Quick Log")
                        .font(.headline)
                }

                Text("Tap to log your mood")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    QuickLogWidget()
} timeline: {
    QuickLogEntry(date: .now)
}

#Preview(as: .accessoryRectangular) {
    QuickLogWidget()
} timeline: {
    QuickLogEntry(date: .now)
}

#Preview(as: .accessoryInline) {
    QuickLogWidget()
} timeline: {
    QuickLogEntry(date: .now)
}
