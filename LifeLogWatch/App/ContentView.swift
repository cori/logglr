import SwiftUI
import SwiftData
import LifeLogKit

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    @Query(sort: \LogEntryModel.timestamp, order: .reverse, limit: 5)
    private var recentEntries: [LogEntryModel]

    var body: some View {
        NavigationStack {
            List {
                // Quick log button
                NavigationLink {
                    QuickLogView()
                } label: {
                    Label("Quick Log", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }

                // Recent entries
                if !recentEntries.isEmpty {
                    Section("Recent") {
                        ForEach(recentEntries.prefix(5)) { entry in
                            WatchEntryRow(entry: entry)
                        }
                    }
                }

                // Sync status
                Section {
                    HStack {
                        Image(systemName: connectivity.isReachable ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                            .foregroundStyle(connectivity.isReachable ? .green : .secondary)

                        Text(connectivity.isReachable ? "Connected" : "iPhone Not Reachable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let unsyncedCount = unsyncedCount, unsyncedCount > 0 {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle")
                                .foregroundStyle(.orange)

                            Text("\(unsyncedCount) pending")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("LifeLog")
        }
    }

    private var unsyncedCount: Int? {
        let descriptor = FetchDescriptor<LogEntryModel>(
            predicate: #Predicate { !$0.synced }
        )
        return try? modelContext.fetchCount(descriptor)
    }
}

// MARK: - Watch Entry Row

struct WatchEntryRow: View {

    let entry: LogEntryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let category = entry.category {
                    Text(category.capitalized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let metric = entry.metric {
                HStack {
                    Text(metric.name.capitalized)
                        .font(.caption)

                    Spacer()

                    Text(String(format: "%.0f", metric.value))
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
            }

            if let text = entry.text {
                Text(text)
                    .font(.caption2)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    ContentView()
        .environment(\.modelContext, PersistenceController.preview().mainContext)
        .environmentObject(WatchConnectivityManager.shared)
}
