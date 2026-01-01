import XCTest
@testable import LifeLogKit

final class MetricTests: XCTestCase {

    // MARK: - Encoding Tests

    func testMetricEncodesToJSON() throws {
        let metric = Metric(
            name: "mood",
            value: 8.0,
            unit: nil,
            scaleMin: 1.0,
            scaleMax: 10.0
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(metric)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"name\":\"mood\""))
        XCTAssertTrue(json.contains("\"value\":8"))
        XCTAssertTrue(json.contains("\"scale_min\":1"))
        XCTAssertTrue(json.contains("\"scale_max\":10"))
    }

    func testMetricWithUnitEncodesToJSON() throws {
        let metric = Metric(
            name: "temperature",
            value: 98.6,
            unit: "°F",
            scaleMin: nil,
            scaleMax: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metric)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"name\":\"temperature\""))
        XCTAssertTrue(json.contains("\"value\":98.6"))
        XCTAssertTrue(json.contains("\"unit\":\"°F\""))
    }

    func testMetricMinimalEncodesToJSON() throws {
        let metric = Metric(
            name: "focus",
            value: 5.0,
            unit: nil,
            scaleMin: nil,
            scaleMax: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metric)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"name\":\"focus\""))
        XCTAssertTrue(json.contains("\"value\":5"))
        // Should not contain optional fields
        XCTAssertFalse(json.contains("\"unit\""))
        XCTAssertFalse(json.contains("\"scale_min\""))
        XCTAssertFalse(json.contains("\"scale_max\""))
    }

    // MARK: - Decoding Tests

    func testMetricDecodesFromJSON() throws {
        let json = """
        {
            "name": "mood",
            "value": 7.5,
            "scale_min": 1,
            "scale_max": 10
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let metric = try decoder.decode(Metric.self, from: data)

        XCTAssertEqual(metric.name, "mood")
        XCTAssertEqual(metric.value, 7.5)
        XCTAssertNil(metric.unit)
        XCTAssertEqual(metric.scaleMin, 1.0)
        XCTAssertEqual(metric.scaleMax, 10.0)
    }

    func testMetricDecodesMinimalJSON() throws {
        let json = """
        {
            "name": "pain",
            "value": 3
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let metric = try decoder.decode(Metric.self, from: data)

        XCTAssertEqual(metric.name, "pain")
        XCTAssertEqual(metric.value, 3.0)
        XCTAssertNil(metric.unit)
        XCTAssertNil(metric.scaleMin)
        XCTAssertNil(metric.scaleMax)
    }

    // MARK: - Round-trip Tests

    func testMetricRoundTrip() throws {
        let original = Metric(
            name: "energy",
            value: 6.0,
            unit: "scale",
            scaleMin: 1.0,
            scaleMax: 10.0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Metric.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.value, original.value)
        XCTAssertEqual(decoded.unit, original.unit)
        XCTAssertEqual(decoded.scaleMin, original.scaleMin)
        XCTAssertEqual(decoded.scaleMax, original.scaleMax)
    }

    // MARK: - CodingKeys Tests

    func testMetricUsesCamelCaseForSwift() throws {
        let metric = Metric(
            name: "test",
            value: 1.0,
            unit: nil,
            scaleMin: 1.0,
            scaleMax: 10.0
        )

        // Verify Swift properties use camelCase
        XCTAssertNotNil(metric.scaleMin)
        XCTAssertNotNil(metric.scaleMax)
    }

    func testMetricUsesSnakeCaseForJSON() throws {
        let metric = Metric(
            name: "test",
            value: 1.0,
            unit: nil,
            scaleMin: 1.0,
            scaleMax: 10.0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metric)
        let json = String(data: data, encoding: .utf8)!

        // Verify JSON uses snake_case
        XCTAssertTrue(json.contains("scale_min"))
        XCTAssertTrue(json.contains("scale_max"))
        XCTAssertFalse(json.contains("scaleMin"))
        XCTAssertFalse(json.contains("scaleMax"))
    }
}
