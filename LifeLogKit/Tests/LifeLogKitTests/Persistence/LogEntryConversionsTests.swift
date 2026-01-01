import XCTest
@testable import LifeLogKit

final class LogEntryConversionsTests: XCTestCase {

    // MARK: - LogEntry to LogEntryModel

    func testAPIToPersistenceConversion() {
        let apiEntry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "iphone",
            deviceId: "test-device",
            category: "mood",
            data: LogData(
                text: "Feeling good",
                metric: Metric(name: "mood", value: 8.0, scaleMin: 1.0, scaleMax: 10.0),
                location: Location(latitude: 37.7749, longitude: -122.4194, placeName: "SF"),
                tags: ["happy", "productive"]
            )
        )

        let persistenceModel = apiEntry.toPersistenceModel(synced: false)

        XCTAssertEqual(persistenceModel.id, apiEntry.id)
        XCTAssertEqual(persistenceModel.timestamp, apiEntry.timestamp)
        XCTAssertEqual(persistenceModel.source, apiEntry.source)
        XCTAssertEqual(persistenceModel.deviceId, apiEntry.deviceId)
        XCTAssertEqual(persistenceModel.category, apiEntry.category)
        XCTAssertFalse(persistenceModel.synced)
        XCTAssertEqual(persistenceModel.text, "Feeling good")
        XCTAssertEqual(persistenceModel.metricName, "mood")
        XCTAssertEqual(persistenceModel.metricValue, 8.0)
        XCTAssertEqual(persistenceModel.locationLatitude, 37.7749)
        XCTAssertEqual(persistenceModel.tags, ["happy", "productive"])
    }

    func testAPIToPersistenceWithMinimalData() {
        let apiEntry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "watch",
            deviceId: "watch-1",
            category: nil,
            data: LogData()
        )

        let persistenceModel = apiEntry.toPersistenceModel()

        XCTAssertEqual(persistenceModel.id, apiEntry.id)
        XCTAssertNil(persistenceModel.category)
        XCTAssertNil(persistenceModel.text)
        XCTAssertNil(persistenceModel.metricName)
        XCTAssertNil(persistenceModel.locationLatitude)
        XCTAssertNil(persistenceModel.tags)
    }

    func testAPIToPersistenceMarksAsSynced() {
        let apiEntry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "iphone",
            deviceId: "test",
            data: LogData()
        )

        let syncedModel = apiEntry.toPersistenceModel(synced: true)
        let unsyncedModel = apiEntry.toPersistenceModel(synced: false)

        XCTAssertTrue(syncedModel.synced)
        XCTAssertFalse(unsyncedModel.synced)
    }

    // MARK: - LogEntryModel to LogEntry

    func testPersistenceToAPIConversion() {
        let persistenceModel = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "iphone",
            deviceId: "test-device",
            category: "mood",
            synced: true,
            text: "Test entry",
            metricName: "mood",
            metricValue: 7.5,
            metricUnit: "scale",
            metricScaleMin: 1.0,
            metricScaleMax: 10.0,
            locationLatitude: 37.7749,
            locationLongitude: -122.4194,
            locationAccuracy: 10.0,
            locationPlaceName: "San Francisco",
            tags: ["test", "conversion"]
        )

        let apiEntry = persistenceModel.toAPIModel()

        XCTAssertEqual(apiEntry.id, persistenceModel.id)
        XCTAssertEqual(apiEntry.timestamp, persistenceModel.timestamp)
        XCTAssertEqual(apiEntry.source, persistenceModel.source)
        XCTAssertEqual(apiEntry.deviceId, persistenceModel.deviceId)
        XCTAssertEqual(apiEntry.category, persistenceModel.category)
        XCTAssertEqual(apiEntry.data.text, "Test entry")
        XCTAssertEqual(apiEntry.data.metric?.name, "mood")
        XCTAssertEqual(apiEntry.data.metric?.value, 7.5)
        XCTAssertEqual(apiEntry.data.location?.latitude, 37.7749)
        XCTAssertEqual(apiEntry.data.tags, ["test", "conversion"])
    }

    func testPersistenceToAPIWithMinimalData() {
        let persistenceModel = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "watch",
            deviceId: "watch-1",
            synced: false
        )

        let apiEntry = persistenceModel.toAPIModel()

        XCTAssertNil(apiEntry.category)
        XCTAssertNil(apiEntry.data.text)
        XCTAssertNil(apiEntry.data.metric)
        XCTAssertNil(apiEntry.data.location)
        XCTAssertNil(apiEntry.data.tags)
    }

    // MARK: - Round-trip Tests

    func testRoundTripConversion() {
        let original = LogEntry(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1704067200),
            recordedAt: Date(timeIntervalSince1970: 1704067205),
            source: "iphone",
            deviceId: "test-device",
            category: "mood",
            data: LogData(
                text: "Round trip test",
                metric: Metric(name: "energy", value: 6.5, unit: "scale", scaleMin: 1.0, scaleMax: 10.0),
                location: Location(latitude: 40.7128, longitude: -74.0060, accuracy: 5.0, placeName: "NYC"),
                tags: ["test", "round-trip", "conversion"]
            )
        )

        // API -> Persistence -> API
        let persistenceModel = original.toPersistenceModel(synced: true)
        let roundTripped = persistenceModel.toAPIModel()

        XCTAssertEqual(roundTripped.id, original.id)
        XCTAssertEqual(roundTripped.timestamp.timeIntervalSince1970, original.timestamp.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(roundTripped.recordedAt.timeIntervalSince1970, original.recordedAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(roundTripped.source, original.source)
        XCTAssertEqual(roundTripped.deviceId, original.deviceId)
        XCTAssertEqual(roundTripped.category, original.category)
        XCTAssertEqual(roundTripped.data.text, original.data.text)
        XCTAssertEqual(roundTripped.data.metric?.name, original.data.metric?.name)
        XCTAssertEqual(roundTripped.data.metric?.value, original.data.metric?.value)
        XCTAssertEqual(roundTripped.data.location?.latitude, original.data.location?.latitude)
        XCTAssertEqual(roundTripped.data.tags, original.data.tags)
    }

    // MARK: - Update Tests

    func testUpdatePersistenceModelFromAPI() {
        let persistenceModel = LogEntryModel(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1000),
            recordedAt: Date(timeIntervalSince1970: 1000),
            source: "old-source",
            deviceId: "old-device",
            category: "old-category",
            synced: true,
            text: "Old text"
        )

        let updatedAPI = LogEntry(
            id: persistenceModel.id,  // Same ID
            timestamp: Date(timeIntervalSince1970: 2000),
            recordedAt: Date(timeIntervalSince1970: 2000),
            source: "new-source",
            deviceId: "new-device",
            category: "new-category",
            data: LogData(
                text: "New text",
                metric: Metric(name: "mood", value: 9.0)
            )
        )

        persistenceModel.update(from: updatedAPI)

        // ID should remain the same
        XCTAssertEqual(persistenceModel.id, updatedAPI.id)

        // Other fields should be updated
        XCTAssertEqual(persistenceModel.timestamp.timeIntervalSince1970, 2000)
        XCTAssertEqual(persistenceModel.source, "new-source")
        XCTAssertEqual(persistenceModel.deviceId, "new-device")
        XCTAssertEqual(persistenceModel.category, "new-category")
        XCTAssertEqual(persistenceModel.text, "New text")
        XCTAssertEqual(persistenceModel.metricName, "mood")
        XCTAssertEqual(persistenceModel.metricValue, 9.0)

        // Synced flag should NOT be updated (it's a local-only field)
        XCTAssertTrue(persistenceModel.synced)
    }

    // MARK: - Convenience Initializer Tests

    func testConvenienceInitFromAPIEntry() {
        let apiEntry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "iphone",
            deviceId: "test",
            category: "mood",
            data: LogData(
                text: "Test",
                metric: Metric(name: "mood", value: 7.0)
            )
        )

        let model = LogEntryModel(from: apiEntry, synced: true)

        XCTAssertEqual(model.id, apiEntry.id)
        XCTAssertEqual(model.text, "Test")
        XCTAssertTrue(model.synced)
    }

    func testConvenienceInitWithLogData() {
        let id = UUID()
        let timestamp = Date()
        let data = LogData(
            text: "Test data",
            metric: Metric(name: "focus", value: 8.0),
            tags: ["work"]
        )

        let model = LogEntryModel(
            id: id,
            timestamp: timestamp,
            recordedAt: timestamp,
            source: "mac",
            deviceId: "mac-1",
            category: "work",
            data: data,
            synced: false
        )

        XCTAssertEqual(model.id, id)
        XCTAssertEqual(model.text, "Test data")
        XCTAssertEqual(model.metricName, "focus")
        XCTAssertEqual(model.metricValue, 8.0)
        XCTAssertEqual(model.tags, ["work"])
        XCTAssertFalse(model.synced)
    }

    // MARK: - Edge Cases

    func testEmptyTagsConversion() {
        let apiEntry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test",
            data: LogData(tags: [])
        )

        let model = apiEntry.toPersistenceModel()

        // Empty array should result in empty string
        XCTAssertEqual(model.tagsString, "")
        // But tags property should return empty array, not nil
        XCTAssertNotNil(model.tags)
        XCTAssertEqual(model.tags?.count, 0)
    }

    func testMetricWithOnlyRequiredFields() {
        let apiEntry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test",
            data: LogData(
                metric: Metric(name: "test", value: 5.0)
            )
        )

        let model = apiEntry.toPersistenceModel()
        let roundTripped = model.toAPIModel()

        XCTAssertEqual(roundTripped.data.metric?.name, "test")
        XCTAssertEqual(roundTripped.data.metric?.value, 5.0)
        XCTAssertNil(roundTripped.data.metric?.unit)
        XCTAssertNil(roundTripped.data.metric?.scaleMin)
        XCTAssertNil(roundTripped.data.metric?.scaleMax)
    }

    func testLocationWithOnlyCoordinates() {
        let apiEntry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test",
            data: LogData(
                location: Location(latitude: 0.0, longitude: 0.0)
            )
        )

        let model = apiEntry.toPersistenceModel()
        let roundTripped = model.toAPIModel()

        XCTAssertEqual(roundTripped.data.location?.latitude, 0.0)
        XCTAssertEqual(roundTripped.data.location?.longitude, 0.0)
        XCTAssertNil(roundTripped.data.location?.accuracy)
        XCTAssertNil(roundTripped.data.location?.altitude)
        XCTAssertNil(roundTripped.data.location?.placeName)
    }
}
