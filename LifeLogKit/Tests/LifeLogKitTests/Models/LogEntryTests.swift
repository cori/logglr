import XCTest
@testable import LifeLogKit

final class LogEntryTests: XCTestCase {

    // MARK: - Encoding Tests

    func testLogEntryEncodesToJSON() throws {
        let entry = LogEntry(
            id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
            timestamp: Date(timeIntervalSince1970: 1704067200), // 2024-01-01 00:00:00 UTC
            recordedAt: Date(timeIntervalSince1970: 1704067200),
            source: "iphone",
            deviceId: "test-device-123",
            category: "mood",
            data: LogData(
                text: "Feeling good",
                metric: Metric(name: "mood", value: 8.0, scaleMin: 1.0, scaleMax: 10.0)
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(entry)
        let json = String(data: data, encoding: .utf8)!

        print("Encoded JSON: \(json)")

        XCTAssertTrue(json.contains("\"id\":\"123e4567-e89b-12d3-a456-426614174000\""))
        XCTAssertTrue(json.contains("\"source\":\"iphone\""))
        XCTAssertTrue(json.contains("\"category\":\"mood\""))
        XCTAssertTrue(json.contains("\"device_id\":\"test-device-123\""))
    }

    func testLogEntryWithoutCategoryEncodesToJSON() throws {
        let entry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "watch",
            deviceId: "watch-1",
            category: nil,
            data: LogData(text: "Quick note")
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"source\":\"watch\""))
        XCTAssertFalse(json.contains("\"category\""))
    }

    // MARK: - Decoding Tests

    func testLogEntryDecodesFromJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "timestamp": "2024-01-15T10:30:00Z",
            "recorded_at": "2024-01-15T10:30:05Z",
            "source": "iphone",
            "device_id": "iphone-abc123",
            "category": "note",
            "data": {
                "text": "Test note",
                "tags": ["test"]
            }
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = json.data(using: .utf8)!
        let entry = try decoder.decode(LogEntry.self, from: data)

        XCTAssertEqual(entry.id.uuidString.lowercased(), "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(entry.source, "iphone")
        XCTAssertEqual(entry.deviceId, "iphone-abc123")
        XCTAssertEqual(entry.category, "note")
        XCTAssertEqual(entry.data.text, "Test note")
        XCTAssertEqual(entry.data.tags, ["test"])
    }

    func testLogEntryDecodesMinimalJSON() throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "timestamp": "2024-01-01T00:00:00Z",
            "recorded_at": "2024-01-01T00:00:00Z",
            "source": "test",
            "device_id": "test-1",
            "data": {}
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = json.data(using: .utf8)!
        let entry = try decoder.decode(LogEntry.self, from: data)

        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.source, "test")
        XCTAssertNil(entry.category)
        XCTAssertNil(entry.data.text)
    }

    // MARK: - Round-trip Tests

    func testLogEntryRoundTrip() throws {
        let original = LogEntry(
            id: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!,
            timestamp: Date(timeIntervalSince1970: 1704067200),
            recordedAt: Date(timeIntervalSince1970: 1704067205),
            source: "iphone",
            deviceId: "device-123",
            category: "mood",
            data: LogData(
                text: "Round trip test",
                metric: Metric(name: "mood", value: 7.5, scaleMin: 1.0, scaleMax: 10.0),
                location: Location(latitude: 37.7749, longitude: -122.4194),
                tags: ["test", "round-trip"]
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encodedData = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LogEntry.self, from: encodedData)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970, original.timestamp.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(decoded.source, original.source)
        XCTAssertEqual(decoded.deviceId, original.deviceId)
        XCTAssertEqual(decoded.category, original.category)
        XCTAssertEqual(decoded.data.text, original.data.text)
        XCTAssertEqual(decoded.data.metric?.value, original.data.metric?.value)
        XCTAssertEqual(decoded.data.location?.latitude, original.data.location?.latitude)
        XCTAssertEqual(decoded.data.tags, original.data.tags)
    }

    // MARK: - CodingKeys Tests

    func testLogEntryUsesSnakeCaseForJSON() throws {
        let entry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-1",
            category: nil,
            data: LogData()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        let json = String(data: data, encoding: .utf8)!

        // Verify snake_case in JSON
        XCTAssertTrue(json.contains("recorded_at"))
        XCTAssertTrue(json.contains("device_id"))

        // Verify camelCase is NOT in JSON
        XCTAssertFalse(json.contains("recordedAt"))
        XCTAssertFalse(json.contains("deviceId"))
    }

    // MARK: - Validation Tests

    func testLogEntryRequiredFieldsArePresentAfterDecoding() throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "timestamp": "2024-01-01T00:00:00Z",
            "recorded_at": "2024-01-01T00:00:00Z",
            "source": "test",
            "device_id": "test-1",
            "data": {}
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = json.data(using: .utf8)!
        let entry = try decoder.decode(LogEntry.self, from: data)

        // Verify all required fields are present
        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(entry.timestamp)
        XCTAssertNotNil(entry.recordedAt)
        XCTAssertNotNil(entry.source)
        XCTAssertNotNil(entry.deviceId)
        XCTAssertNotNil(entry.data)
    }

    func testLogEntryHandlesDifferentTimestamps() throws {
        let now = Date()
        let fiveSecondsLater = Date(timeInterval: 5, since: now)

        let entry = LogEntry(
            id: UUID(),
            timestamp: now,
            recordedAt: fiveSecondsLater,
            source: "test",
            deviceId: "test-1",
            category: nil,
            data: LogData()
        )

        XCTAssertNotEqual(entry.timestamp, entry.recordedAt)
        XCTAssertTrue(entry.recordedAt > entry.timestamp)
    }

    // MARK: - Source Device Tests

    func testLogEntrySupportsVariousSources() {
        let sources = ["watch", "iphone", "ipad", "mac", "drafts", "shortcut", "api"]

        for source in sources {
            let entry = LogEntry(
                id: UUID(),
                timestamp: Date(),
                recordedAt: Date(),
                source: source,
                deviceId: "test",
                category: nil,
                data: LogData()
            )

            XCTAssertEqual(entry.source, source)
        }
    }

    // MARK: - Category Tests

    func testLogEntrySupportsVariousCategories() {
        let categories = ["mood", "work", "location", "health", "note"]

        for category in categories {
            let entry = LogEntry(
                id: UUID(),
                timestamp: Date(),
                recordedAt: Date(),
                source: "test",
                deviceId: "test",
                category: category,
                data: LogData()
            )

            XCTAssertEqual(entry.category, category)
        }
    }
}
