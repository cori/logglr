import XCTest
import SwiftData
@testable import LifeLogKit

@MainActor
final class LogEntryModelTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory container for testing
        let schema = Schema([LogEntryModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        try await super.tearDown()
    }

    // MARK: - Basic Persistence Tests

    func testCreateAndSaveEntry() throws {
        let entry = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            category: "mood",
            synced: false,
            text: "Test entry",
            metricName: "mood",
            metricValue: 8.0
        )

        context.insert(entry)
        try context.save()

        // Verify it was saved
        let descriptor = FetchDescriptor<LogEntryModel>()
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.text, "Test entry")
    }

    func testFetchEntryById() throws {
        let id = UUID()
        let entry = LogEntryModel(
            id: id,
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            synced: false
        )

        context.insert(entry)
        try context.save()

        // Fetch by ID
        let descriptor = FetchDescriptor<LogEntryModel>(
            predicate: #Predicate { $0.id == id }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, id)
    }

    func testUniqueIDConstraint() throws {
        let id = UUID()

        let entry1 = LogEntryModel(
            id: id,
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            synced: false
        )

        let entry2 = LogEntryModel(
            id: id,  // Same ID
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            synced: false
        )

        context.insert(entry1)
        context.insert(entry2)

        // Save should handle duplicate IDs (SwiftData will keep the last one)
        try context.save()

        let descriptor = FetchDescriptor<LogEntryModel>(
            predicate: #Predicate { $0.id == id }
        )
        let results = try context.fetch(descriptor)

        // Should only have one entry with this ID
        XCTAssertEqual(results.count, 1)
    }

    func testDeleteEntry() throws {
        let entry = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            synced: false
        )

        context.insert(entry)
        try context.save()

        // Delete
        context.delete(entry)
        try context.save()

        // Verify it's gone
        let descriptor = FetchDescriptor<LogEntryModel>()
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Synced Flag Tests

    func testFetchUnsyncedEntries() throws {
        let synced = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            synced: true
        )

        let unsynced = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            synced: false
        )

        context.insert(synced)
        context.insert(unsynced)
        try context.save()

        // Fetch only unsynced
        let descriptor = FetchDescriptor<LogEntryModel>(
            predicate: #Predicate { !$0.synced }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
        XCTAssertFalse(results.first!.synced)
    }

    func testMarkAsSynced() throws {
        let entry = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            synced: false
        )

        context.insert(entry)
        try context.save()

        // Mark as synced
        entry.synced = true
        try context.save()

        // Verify
        let descriptor = FetchDescriptor<LogEntryModel>(
            predicate: #Predicate { $0.synced }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Data Field Tests

    func testMetricProperties() throws {
        let entry = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            synced: false,
            metricName: "mood",
            metricValue: 7.5,
            metricUnit: "scale",
            metricScaleMin: 1.0,
            metricScaleMax: 10.0
        )

        context.insert(entry)
        try context.save()

        // Test convenience property
        let metric = entry.metric
        XCTAssertNotNil(metric)
        XCTAssertEqual(metric?.name, "mood")
        XCTAssertEqual(metric?.value, 7.5)
        XCTAssertEqual(metric?.unit, "scale")
        XCTAssertEqual(metric?.scaleMin, 1.0)
        XCTAssertEqual(metric?.scaleMax, 10.0)
    }

    func testLocationProperties() throws {
        let entry = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            synced: false,
            locationLatitude: 37.7749,
            locationLongitude: -122.4194,
            locationAccuracy: 10.0,
            locationPlaceName: "San Francisco"
        )

        context.insert(entry)
        try context.save()

        // Test convenience property
        let location = entry.location
        XCTAssertNotNil(location)
        XCTAssertEqual(location?.latitude, 37.7749)
        XCTAssertEqual(location?.longitude, -122.4194)
        XCTAssertEqual(location?.accuracy, 10.0)
        XCTAssertEqual(location?.placeName, "San Francisco")
    }

    func testTagsConversion() throws {
        let entry = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            synced: false,
            tags: ["tag1", "tag2", "tag3"]
        )

        context.insert(entry)
        try context.save()

        // Verify tags are stored as comma-separated string
        XCTAssertEqual(entry.tagsString, "tag1,tag2,tag3")

        // Verify tags convenience property
        XCTAssertEqual(entry.tags, ["tag1", "tag2", "tag3"])
    }

    func testDataProperty() throws {
        let entry = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            synced: false,
            text: "Test text",
            metricName: "mood",
            metricValue: 8.0,
            locationLatitude: 37.7749,
            locationLongitude: -122.4194,
            tags: ["test"]
        )

        context.insert(entry)
        try context.save()

        // Test data convenience property
        let data = entry.data
        XCTAssertEqual(data.text, "Test text")
        XCTAssertNotNil(data.metric)
        XCTAssertNotNil(data.location)
        XCTAssertEqual(data.tags, ["test"])
    }

    // MARK: - Sorting and Filtering Tests

    func testFetchSortedByTimestamp() throws {
        let now = Date()

        let entry1 = LogEntryModel(
            id: UUID(),
            timestamp: now.addingTimeInterval(-3600),
            recordedAt: now,
            source: "test",
            deviceId: "test-1",
            synced: false
        )

        let entry2 = LogEntryModel(
            id: UUID(),
            timestamp: now,
            recordedAt: now,
            source: "test",
            deviceId: "test-1",
            synced: false
        )

        context.insert(entry1)
        context.insert(entry2)
        try context.save()

        // Fetch sorted descending
        let descriptor = FetchDescriptor<LogEntryModel>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0].timestamp > results[1].timestamp)
    }

    func testFetchByCategory() throws {
        let mood = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            category: "mood",
            synced: false
        )

        let work = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            category: "work",
            synced: false
        )

        context.insert(mood)
        context.insert(work)
        try context.save()

        // Fetch only mood entries
        let descriptor = FetchDescriptor<LogEntryModel>(
            predicate: #Predicate { $0.category == "mood" }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.category, "mood")
    }

    func testFetchBySource() throws {
        let iPhone = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "iphone",
            deviceId: "test-1",
            synced: false
        )

        let watch = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "watch",
            deviceId: "test-1",
            synced: false
        )

        context.insert(iPhone)
        context.insert(watch)
        try context.save()

        // Fetch only watch entries
        let descriptor = FetchDescriptor<LogEntryModel>(
            predicate: #Predicate { $0.source == "watch" }
        )
        let results = try context.fetch(descriptor)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.source, "watch")
    }
}
