import SwiftUI
import LifeLogKit

struct EntryRow: View {

    let entry: LogEntryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: time and category
            HStack {
                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let category = entry.category {
                    Text(category.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(categoryColor(category).opacity(0.2))
                        .foregroundStyle(categoryColor(category))
                        .clipShape(Capsule())
                }

                Spacer()

                if !entry.synced {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                sourceIcon
            }

            // Main content
            if let metric = entry.metric {
                metricView(metric)
            }

            if let text = entry.text, !text.isEmpty {
                Text(text)
                    .font(.body)
                    .lineLimit(3)
            }

            // Location
            if let location = entry.location {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)

                    if let placeName = location.placeName {
                        Text(placeName)
                            .font(.caption)
                    } else {
                        Text("\(location.latitude, specifier: "%.4f"), \(location.longitude, specifier: "%.4f")")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }

            // Tags
            if let tags = entry.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.gray.opacity(0.1))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Subviews

    private var sourceIcon: some View {
        Group {
            switch entry.source {
            case "watch":
                Image(systemName: "applewatch")
            case "iphone":
                Image(systemName: "iphone")
            case "ipad":
                Image(systemName: "ipad")
            case "mac":
                Image(systemName: "macbook")
            default:
                Image(systemName: "app")
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }

    private func metricView(_ metric: Metric) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.name.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(String(format: "%.1f", metric.value))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(metricColor(metric))
            }

            if let min = metric.scaleMin, let max = metric.scaleMax {
                Spacer()

                // Visual scale indicator
                let percentage = (metric.value - min) / (max - min)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(min))-\(Int(max))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.gray.opacity(0.2))

                            RoundedRectangle(cornerRadius: 2)
                                .fill(metricColor(metric))
                                .frame(width: geometry.size.width * percentage)
                        }
                    }
                    .frame(width: 60, height: 4)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "mood": return .blue
        case "work": return .purple
        case "health": return .red
        case "note": return .green
        case "location": return .orange
        default: return .gray
        }
    }

    private func metricColor(_ metric: Metric) -> Color {
        guard let min = metric.scaleMin, let max = metric.scaleMax else {
            return .blue
        }

        let percentage = (metric.value - min) / (max - min)

        if percentage < 0.33 {
            return .red
        } else if percentage < 0.66 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Previews

#Preview("Mood Entry") {
    let entry = LogEntryModel(
        id: UUID(),
        timestamp: Date(),
        recordedAt: Date(),
        source: "iphone",
        deviceId: "preview",
        category: "mood",
        synced: true,
        text: "Feeling pretty good today!",
        metricName: "mood",
        metricValue: 8.0,
        metricScaleMin: 1.0,
        metricScaleMax: 10.0,
        tags: ["happy", "productive"]
    )

    return List {
        EntryRow(entry: entry)
    }
}

#Preview("Simple Note") {
    let entry = LogEntryModel(
        id: UUID(),
        timestamp: Date(),
        recordedAt: Date(),
        source: "watch",
        deviceId: "preview",
        category: "note",
        synced: false,
        text: "Quick note from my watch"
    )

    return List {
        EntryRow(entry: entry)
    }
}

#Preview("Location Entry") {
    let entry = LogEntryModel(
        id: UUID(),
        timestamp: Date(),
        recordedAt: Date(),
        source: "iphone",
        deviceId: "preview",
        category: "location",
        synced: true,
        locationLatitude: 37.7749,
        locationLongitude: -122.4194,
        locationPlaceName: "San Francisco, CA"
    )

    return List {
        EntryRow(entry: entry)
    }
}
