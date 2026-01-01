import SwiftUI
import SwiftData
import LifeLogKit

struct TimelineView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    @Query(sort: \LogEntryModel.timestamp, order: .reverse)
    private var entries: [LogEntryModel]

    @State private var selectedCategory: String?
    @State private var showingNewEntry = false
    @State private var isRefreshing = false

    var filteredEntries: [LogEntryModel] {
        guard let category = selectedCategory else { return entries }
        return entries.filter { $0.category == category }
    }

    var groupedEntries: [(Date, [LogEntryModel])] {
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            Calendar.current.startOfDay(for: entry.timestamp)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var categories: [String] {
        Set(entries.compactMap(\.category)).sorted()
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Button {
                            selectedCategory = nil
                        } label: {
                            Label("All", systemImage: selectedCategory == nil ? "checkmark" : "")
                        }

                        if !categories.isEmpty {
                            Divider()

                            ForEach(categories, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    Label(
                                        category.capitalized,
                                        systemImage: selectedCategory == category ? "checkmark" : ""
                                    )
                                }
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                NewEntryView()
            }
            .refreshable {
                await performSync()
            }
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Entries Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap the + button to create your first entry")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingNewEntry = true
            } label: {
                Text("Create Entry")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top)
        }
        .padding()
    }

    private var entryList: some View {
        List {
            if let selectedCategory = selectedCategory {
                Section {
                    HStack {
                        Text("Filtered by: \(selectedCategory.capitalized)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Clear") {
                            self.selectedCategory = nil
                        }
                        .font(.caption)
                    }
                }
            }

            ForEach(groupedEntries, id: \.0) { day, dayEntries in
                Section {
                    ForEach(dayEntries) { entry in
                        EntryRow(entry: entry)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteEntry(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text(day, style: .date)
                        .font(.headline)
                }
            }

            if !entries.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("\(entries.count) total entries")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let lastSync = appState.lastSyncDate {
                                Text("Last sync: \(lastSync, style: .relative)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func deleteEntry(_ entry: LogEntryModel) {
        withAnimation {
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    private func performSync() async {
        guard appState.isConfigured, let apiClient = appState.apiClient else {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let syncManager = SyncManager(
                apiClient: apiClient,
                modelContainer: PersistenceController.shared.container
            )
            try await syncManager.syncUnsyncedEntries()
            appState.updateLastSyncDate()
        } catch {
            print("❌ Sync failed: \(error)")
        }
    }
}

// MARK: - Previews

#Preview("With Entries") {
    TimelineView()
        .environment(\.modelContext, PersistenceController.preview().mainContext)
        .environmentObject(AppState.shared)
}

#Preview("Empty") {
    TimelineView()
        .environment(\.modelContext, PersistenceController(inMemory: true).mainContext)
        .environmentObject(AppState.shared)
}
