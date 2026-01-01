import XCTest
@testable import LifeLogKit

final class LogDataTests: XCTestCase {

    // MARK: - Encoding Tests

    func testLogDataWithAllFieldsEncodesToJSON() throws {
        let location = Location(
            latitude: 37.7749,
            longitude: -122.4194,
            placeName: "San Francisco"
        )

        let metric = Metric(
            name: "mood",
            value: 8.0,
            scaleMin: 1.0,
            scaleMax: 10.0
        )

        let logData = LogData(
            text: "Feeling great today!",
            metric: metric,
            location: location,
            tags: ["happy", "productive"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(logData)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"text\":\"Feeling great today!\""))
        XCTAssertTrue(json.contains("\"mood\""))
        XCTAssertTrue(json.contains("\"latitude\":37.7749"))
        XCTAssertTrue(json.contains("\"tags\":["))
        XCTAssertTrue(json.contains("\"happy\""))
    }

    func testLogDataWithOnlyTextEncodesToJSON() throws {
        let logData = LogData(
            text: "Quick note",
            metric: nil,
            location: nil,
            tags: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(logData)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"text\":\"Quick note\""))
        XCTAssertFalse(json.contains("\"metric\""))
        XCTAssertFalse(json.contains("\"location\""))
        XCTAssertFalse(json.contains("\"tags\""))
    }

    func testLogDataWithOnlyMetricEncodesToJSON() throws {
        let metric = Metric(name: "energy", value: 7.0)
        let logData = LogData(
            text: nil,
            metric: metric,
            location: nil,
            tags: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(logData)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"metric\""))
        XCTAssertTrue(json.contains("\"energy\""))
        XCTAssertFalse(json.contains("\"text\""))
    }

    func testLogDataEmptyEncodesToJSON() throws {
        let logData = LogData(
            text: nil,
            metric: nil,
            location: nil,
            tags: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(logData)
        let json = String(data: data, encoding: .utf8)!

        // Should be an empty object or minimal JSON
        XCTAssertTrue(json.count < 10) // Just {}
    }

    // MARK: - Decoding Tests

    func testLogDataDecodesFromCompleteJSON() throws {
        let json = """
        {
            "text": "Test entry",
            "metric": {
                "name": "focus",
                "value": 6.5
            },
            "location": {
                "latitude": 40.7128,
                "longitude": -74.0060
            },
            "tags": ["work", "focused"]
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let logData = try decoder.decode(LogData.self, from: data)

        XCTAssertEqual(logData.text, "Test entry")
        XCTAssertEqual(logData.metric?.name, "focus")
        XCTAssertEqual(logData.metric?.value, 6.5)
        XCTAssertEqual(logData.location?.latitude, 40.7128)
        XCTAssertEqual(logData.tags, ["work", "focused"])
    }

    func testLogDataDecodesFromMinimalJSON() throws {
        let json = "{}"

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let logData = try decoder.decode(LogData.self, from: data)

        XCTAssertNil(logData.text)
        XCTAssertNil(logData.metric)
        XCTAssertNil(logData.location)
        XCTAssertNil(logData.tags)
    }

    func testLogDataDecodesPartialJSON() throws {
        let json = """
        {
            "text": "Just a note",
            "tags": ["note"]
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let logData = try decoder.decode(LogData.self, from: data)

        XCTAssertEqual(logData.text, "Just a note")
        XCTAssertNil(logData.metric)
        XCTAssertNil(logData.location)
        XCTAssertEqual(logData.tags, ["note"])
    }

    // MARK: - Round-trip Tests

    func testLogDataRoundTrip() throws {
        let original = LogData(
            text: "Test text",
            metric: Metric(name: "mood", value: 5.0),
            location: Location(latitude: 0, longitude: 0),
            tags: ["test", "round-trip"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LogData.self, from: data)

        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.metric?.name, original.metric?.name)
        XCTAssertEqual(decoded.location?.latitude, original.location?.latitude)
        XCTAssertEqual(decoded.tags, original.tags)
    }

    // MARK: - Convenience Tests

    func testLogDataCanBeModified() {
        var logData = LogData(text: "Initial", metric: nil, location: nil, tags: nil)

        logData.text = "Modified"
        logData.metric = Metric(name: "test", value: 1.0)
        logData.tags = ["new-tag"]

        XCTAssertEqual(logData.text, "Modified")
        XCTAssertNotNil(logData.metric)
        XCTAssertEqual(logData.tags, ["new-tag"])
    }

    func testLogDataWithEmptyArrays() throws {
        let logData = LogData(
            text: nil,
            metric: nil,
            location: nil,
            tags: []
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(logData)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LogData.self, from: data)

        XCTAssertEqual(decoded.tags, [])
    }
}
