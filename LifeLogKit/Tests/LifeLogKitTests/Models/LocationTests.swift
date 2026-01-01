import XCTest
@testable import LifeLogKit

final class LocationTests: XCTestCase {

    // MARK: - Encoding Tests

    func testLocationEncodesToJSON() throws {
        let location = Location(
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 10.0,
            altitude: 15.0,
            placeName: "San Francisco, CA"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(location)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"latitude\":37.7749"))
        XCTAssertTrue(json.contains("\"longitude\":-122.4194"))
        XCTAssertTrue(json.contains("\"accuracy\":10"))
        XCTAssertTrue(json.contains("\"altitude\":15"))
        XCTAssertTrue(json.contains("\"place_name\":\"San Francisco, CA\""))
    }

    func testLocationMinimalEncodesToJSON() throws {
        let location = Location(
            latitude: 40.7128,
            longitude: -74.0060,
            accuracy: nil,
            altitude: nil,
            placeName: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(location)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"latitude\":40.7128"))
        XCTAssertTrue(json.contains("\"longitude\":-74.006"))
        XCTAssertFalse(json.contains("\"accuracy\""))
        XCTAssertFalse(json.contains("\"altitude\""))
        XCTAssertFalse(json.contains("\"place_name\""))
    }

    // MARK: - Decoding Tests

    func testLocationDecodesFromJSON() throws {
        let json = """
        {
            "latitude": 51.5074,
            "longitude": -0.1278,
            "accuracy": 5.5,
            "altitude": 11.0,
            "place_name": "London, UK"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let location = try decoder.decode(Location.self, from: data)

        XCTAssertEqual(location.latitude, 51.5074)
        XCTAssertEqual(location.longitude, -0.1278)
        XCTAssertEqual(location.accuracy, 5.5)
        XCTAssertEqual(location.altitude, 11.0)
        XCTAssertEqual(location.placeName, "London, UK")
    }

    func testLocationDecodesMinimalJSON() throws {
        let json = """
        {
            "latitude": 35.6762,
            "longitude": 139.6503
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let location = try decoder.decode(Location.self, from: data)

        XCTAssertEqual(location.latitude, 35.6762)
        XCTAssertEqual(location.longitude, 139.6503)
        XCTAssertNil(location.accuracy)
        XCTAssertNil(location.altitude)
        XCTAssertNil(location.placeName)
    }

    // MARK: - Round-trip Tests

    func testLocationRoundTrip() throws {
        let original = Location(
            latitude: 48.8566,
            longitude: 2.3522,
            accuracy: 8.5,
            altitude: 35.0,
            placeName: "Paris, France"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Location.self, from: data)

        XCTAssertEqual(decoded.latitude, original.latitude)
        XCTAssertEqual(decoded.longitude, original.longitude)
        XCTAssertEqual(decoded.accuracy, original.accuracy)
        XCTAssertEqual(decoded.altitude, original.altitude)
        XCTAssertEqual(decoded.placeName, original.placeName)
    }

    // MARK: - CodingKeys Tests

    func testLocationUsesSnakeCaseForPlaceName() throws {
        let location = Location(
            latitude: 0,
            longitude: 0,
            accuracy: nil,
            altitude: nil,
            placeName: "Test Place"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(location)
        let json = String(data: data, encoding: .utf8)!

        // Verify JSON uses snake_case for place_name
        XCTAssertTrue(json.contains("place_name"))
        XCTAssertFalse(json.contains("placeName"))
    }

    // MARK: - Validation Tests

    func testLocationHandlesExtremeCoordinates() throws {
        let location = Location(
            latitude: -90.0,  // South Pole
            longitude: 180.0, // Date line
            accuracy: nil,
            altitude: nil,
            placeName: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(location)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Location.self, from: data)

        XCTAssertEqual(decoded.latitude, -90.0)
        XCTAssertEqual(decoded.longitude, 180.0)
    }
}
