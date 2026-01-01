import Foundation
import SwiftData

/// Manages synchronization between local SwiftData storage and the remote API
@MainActor
public final class SyncManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isSyncing = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var lastError: LifeLogError?

    // MARK: - Private Properties

    private let apiClient: APIClient
    private let modelContainer: ModelContainer

    // MARK: - Initialization

    public init(apiClient: APIClient, modelContainer: ModelContainer) {
        self.apiClient = apiClient
        self.modelContainer = modelContainer
    }

    // MARK: - Public Methods

    /// Sync all unsynced entries to the API
    /// - Throws: LifeLogError if sync fails
    public func syncUnsyncedEntries() async throws {
        guard !isSyncing else {
            print("⚠️ Sync already in progress")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let context = modelContainer.mainContext

        // Fetch unsynced entries
        let descriptor = FetchDescriptor<LogEntryModel>(
            predicate: #Predicate { !$0.synced },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        do {
            let unsyncedEntries = try context.fetch(descriptor)

            guard !unsyncedEntries.isEmpty else {
                print("✅ No entries to sync")
                lastSyncDate = Date()
                return
            }

            print("🔄 Syncing \(unsyncedEntries.count) entries...")

            // Convert to API models
            let apiEntries = unsyncedEntries.map { $0.toAPIModel() }

            // Send to API (in batches if needed)
            let batchSize = 50
            var syncedCount = 0

            for batch in apiEntries.chunked(into: batchSize) {
                do {
                    try await apiClient.createEntries(batch)

                    // Mark as synced
                    let batchIDs = Set(batch.map(\.id))
                    for entry in unsyncedEntries where batchIDs.contains(entry.id) {
                        entry.synced = true
                        syncedCount += 1
                    }
                } catch {
                    print("❌ Failed to sync batch: \(error)")
                    // Continue with next batch
                    throw LifeLogError.syncFailed(underlying: error)
                }
            }

            // Save updated sync status
            try context.save()

            lastSyncDate = Date()
            lastError = nil

            print("✅ Successfully synced \(syncedCount) entries")
        } catch {
            print("❌ Sync failed: \(error)")
            lastError = error as? LifeLogError ?? .syncFailed(underlying: error)
            throw lastError!
        }
    }

    /// Fetch entries from API and save to local storage
    /// - Parameters:
    ///   - since: Only fetch entries after this date
    ///   - category: Only fetch entries of this category
    /// - Returns: Number of new entries fetched
    /// - Throws: LifeLogError if fetch fails
    @discardableResult
    public func fetchEntriesFromAPI(
        since: Date? = nil,
        category: String? = nil
    ) async throws -> Int {
        guard !isSyncing else {
            print("⚠️ Sync already in progress")
            return 0
        }

        isSyncing = true
        defer { isSyncing = false }

        let context = modelContainer.mainContext

        do {
            // Fetch from API
            let apiEntries = try await apiClient.fetchEntries(
                since: since,
                category: category
            )

            guard !apiEntries.isEmpty else {
                print("✅ No new entries from API")
                return 0
            }

            print("📥 Fetched \(apiEntries.count) entries from API")

            // Get existing IDs to avoid duplicates
            let existingIDs = try fetchExistingIDs(context: context)

            var newCount = 0

            for apiEntry in apiEntries {
                if existingIDs.contains(apiEntry.id) {
                    // Update existing entry
                    if let existing = try fetchEntry(id: apiEntry.id, context: context) {
                        existing.update(from: apiEntry)
                    }
                } else {
                    // Create new entry (mark as synced since it came from API)
                    let newEntry = LogEntryModel(from: apiEntry, synced: true)
                    context.insert(newEntry)
                    newCount += 1
                }
            }

            try context.save()

            lastSyncDate = Date()
            lastError = nil

            print("✅ Added \(newCount) new entries, updated \(apiEntries.count - newCount)")

            return newCount
        } catch {
            print("❌ Fetch failed: \(error)")
            lastError = error as? LifeLogError ?? .syncFailed(underlying: error)
            throw lastError!
        }
    }

    /// Perform a full two-way sync
    /// - Uploads unsynced local entries
    /// - Downloads new entries from API
    /// - Returns: (uploaded: Int, downloaded: Int)
    public func performFullSync() async throws -> (uploaded: Int, downloaded: Int) {
        print("🔄 Starting full sync...")

        // Upload unsynced entries first
        let uploadedCount = try await uploadUnsyncedCount()

        // Download new entries
        let lastSync = lastSyncDate ?? Date.distantPast
        let downloadedCount = try await fetchEntriesFromAPI(since: lastSync)

        print("✅ Full sync complete: ↑\(uploadedCount) ↓\(downloadedCount)")

        return (uploadedCount, downloadedCount)
    }

    // MARK: - Private Helpers

    private func uploadUnsyncedCount() async throws -> Int {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<LogEntryModel>(
            predicate: #Predicate { !$0.synced }
        )
        let count = try context.fetchCount(descriptor)

        try await syncUnsyncedEntries()

        return count
    }

    private func fetchExistingIDs(context: ModelContext) throws -> Set<UUID> {
        let descriptor = FetchDescriptor<LogEntryModel>()
        let entries = try context.fetch(descriptor)
        return Set(entries.map(\.id))
    }

    private func fetchEntry(id: UUID, context: ModelContext) throws -> LogEntryModel? {
        let descriptor = FetchDescriptor<LogEntryModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
}

// MARK: - Array Extension for Batching

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
