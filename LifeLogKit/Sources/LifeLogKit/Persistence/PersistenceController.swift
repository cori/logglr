import Foundation
import SwiftData

/// Controller for managing SwiftData persistence
@MainActor
public final class PersistenceController {

    // MARK: - Singleton

    /// Shared instance for production use
    public static let shared = PersistenceController()

    // MARK: - Properties

    /// The SwiftData model container
    public let container: ModelContainer

    /// The main context (bound to main actor)
    public var mainContext: ModelContext {
        container.mainContext
    }

    // MARK: - Initialization

    /// Initialize with a custom configuration
    /// - Parameter inMemory: If true, uses in-memory storage (useful for testing)
    public init(inMemory: Bool = false) {
        do {
            let schema = Schema([
                LogEntryModel.self
            ])

            let configuration: ModelConfiguration
            if inMemory {
                configuration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
            } else {
                // Use App Group for sharing between app targets (iPhone, Watch, etc.)
                let appGroupID = DeviceInfo.appGroupID
                let groupURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: appGroupID
                )

                if let groupURL = groupURL {
                    // Store in shared app group
                    configuration = ModelConfiguration(
                        schema: schema,
                        url: groupURL.appendingPathComponent("LifeLog.sqlite")
                    )
                } else {
                    // Fallback to default location if app group isn't available
                    configuration = ModelConfiguration(schema: schema)
                }
            }

            container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    // MARK: - Preview Helper

    /// Create a preview instance with sample data
    /// Useful for SwiftUI previews
    public static func preview() -> PersistenceController {
        let controller = PersistenceController(inMemory: true)

        // Add sample data
        let context = controller.mainContext

        let sampleEntry1 = LogEntryModel(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-3600),
            recordedAt: Date().addingTimeInterval(-3600),
            source: "iphone",
            deviceId: "preview-device",
            category: "mood",
            synced: true,
            text: "Feeling great!",
            metricName: "mood",
            metricValue: 8.0,
            metricScaleMin: 1.0,
            metricScaleMax: 10.0,
            tags: ["happy", "productive"]
        )

        let sampleEntry2 = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "watch",
            deviceId: "preview-device",
            category: "mood",
            synced: false,
            text: nil,
            metricName: "mood",
            metricValue: 6.0,
            metricScaleMin: 1.0,
            metricScaleMax: 10.0,
            tags: ["quick-log"]
        )

        context.insert(sampleEntry1)
        context.insert(sampleEntry2)

        try? context.save()

        return controller
    }
}
