import SwiftUI
import SwiftData
import LifeLogKit

@main
struct LifeLogApp: App {

    // MARK: - Properties

    @StateObject private var appState = AppState.shared
    private let persistenceController = PersistenceController.shared

    // MARK: - App Lifecycle

    init() {
        // Configure background tasks on app launch
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.modelContext, persistenceController.mainContext)
                .environmentObject(appState)
                .task {
                    // Sync on app launch
                    await performInitialSync()
                }
        }
        .modelContainer(persistenceController.container)
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        // Background task registration will be implemented in SyncManager
        // For now, this is a placeholder
        print("📱 LifeLog app launching...")
    }

    // MARK: - Initial Sync

    private func performInitialSync() async {
        guard appState.isConfigured else {
            print("⚠️ App not configured, skipping initial sync")
            return
        }

        print("🔄 Performing initial sync...")

        // Check if we need to sync (last sync > 5 minutes ago)
        if let lastSync = appState.lastSyncDate,
           Date().timeIntervalSince(lastSync) < 300 {
            print("✅ Recent sync found, skipping")
            return
        }

        do {
            let syncManager = SyncManager(
                apiClient: appState.apiClient!,
                modelContainer: persistenceController.container
            )
            try await syncManager.syncUnsyncedEntries()
            appState.lastSyncDate = Date()
            print("✅ Initial sync completed")
        } catch {
            print("❌ Initial sync failed: \(error)")
        }
    }
}
