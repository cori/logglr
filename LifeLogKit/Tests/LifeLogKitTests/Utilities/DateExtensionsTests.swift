import XCTest
@testable import LifeLogKit

final class DateExtensionsTests: XCTestCase {

    // MARK: - ISO8601 String Tests

    func testDateToISO8601String() {
        let date = Date(timeIntervalSince1970: 1704067200) // 2024-01-01 00:00:00 UTC
        let isoString = date.iso8601String

        XCTAssertEqual(isoString, "2024-01-01T00:00:00Z")
    }

    func testDateFromISO8601String() throws {
        let isoString = "2024-01-01T12:30:45Z"
        let date = try XCTUnwrap(Date.fromISO8601(isoString))

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date)

        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 30)
        XCTAssertEqual(components.second, 45)
    }

    func testDateRoundTripThroughISO8601() throws {
        let original = Date(timeIntervalSince1970: 1704153645) // 2024-01-02 00:00:45 UTC

        let isoString = original.iso8601String
        let decoded = try XCTUnwrap(Date.fromISO8601(isoString))

        // Allow 1 second tolerance for rounding
        XCTAssertEqual(decoded.timeIntervalSince1970, original.timeIntervalSince1970, accuracy: 1.0)
    }

    func testInvalidISO8601StringReturnsNil() {
        let invalidStrings = [
            "not a date",
            "2024-13-01",  // Invalid month
            "2024-01-32",  // Invalid day
            "",
            "2024-01-01",  // Missing time
        ]

        for invalidString in invalidStrings {
            XCTAssertNil(Date.fromISO8601(invalidString), "Should return nil for invalid string: \(invalidString)")
        }
    }

    func testDateFromISO8601WithMilliseconds() throws {
        let isoString = "2024-01-01T12:30:45.123Z"
        let date = try XCTUnwrap(Date.fromISO8601(isoString))

        // Should parse successfully even with milliseconds
        XCTAssertNotNil(date)
    }

    func testDateFromISO8601WithTimeZone() throws {
        // ISO8601 with offset
        let isoString = "2024-01-01T12:30:45+00:00"
        let date = try XCTUnwrap(Date.fromISO8601(isoString))

        XCTAssertNotNil(date)
    }

    // MARK: - JSON Encoder/Decoder Tests

    func testJSONEncoderISO8601Extension() throws {
        struct TestStruct: Codable {
            let date: Date
        }

        let testDate = Date(timeIntervalSince1970: 1704067200)
        let testStruct = TestStruct(date: testDate)

        let encoder = JSONEncoder.iso8601
        let data = try encoder.encode(testStruct)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("2024-01-01T00:00:00Z"))
    }

    func testJSONDecoderISO8601Extension() throws {
        struct TestStruct: Codable {
            let date: Date
        }

        let json = """
        {
            "date": "2024-01-01T12:30:45Z"
        }
        """

        let decoder = JSONDecoder.iso8601
        let data = json.data(using: .utf8)!
        let testStruct = try decoder.decode(TestStruct.self, from: data)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: testStruct.date)

        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 30)
        XCTAssertEqual(components.second, 45)
    }

    func testEncoderDecoderRoundTrip() throws {
        struct TestStruct: Codable, Equatable {
            let date: Date
            let name: String
        }

        let original = TestStruct(
            date: Date(timeIntervalSince1970: 1704153645),
            name: "test"
        )

        let encoder = JSONEncoder.iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder.iso8601
        let decoded = try decoder.decode(TestStruct.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.date.timeIntervalSince1970, original.date.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - Performance Tests

    func testISO8601StringPerformance() {
        let date = Date()

        measure {
            for _ in 0..<1000 {
                _ = date.iso8601String
            }
        }
    }

    func testISO8601ParsingPerformance() {
        let isoString = "2024-01-01T12:30:45Z"

        measure {
            for _ in 0..<1000 {
                _ = Date.fromISO8601(isoString)
            }
        }
    }
}
