import SwiftUI
import SwiftData
import LifeLogKit

@main
struct LifeLogWatchApp: App {

    // MARK: - Properties

    private let persistenceController = PersistenceController.shared
    @StateObject private var connectivity = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.modelContext, persistenceController.mainContext)
                .environmentObject(connectivity)
        }
        .modelContainer(persistenceController.container)
    }
}
