import Foundation

/// Represents a geographic location with optional metadata
public struct Location: Codable, Equatable, Sendable {
    /// Latitude in degrees (-90 to 90)
    public let latitude: Double

    /// Longitude in degrees (-180 to 180)
    public let longitude: Double

    /// Horizontal accuracy in meters (nil if unknown)
    public var accuracy: Double?

    /// Altitude above sea level in meters (nil if unknown)
    public var altitude: Double?

    /// Human-readable place name (reverse geocoded or manually entered)
    public var placeName: String?

    public init(
        latitude: Double,
        longitude: Double,
        accuracy: Double? = nil,
        altitude: Double? = nil,
        placeName: String? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.altitude = altitude
        self.placeName = placeName
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case accuracy
        case altitude
        case placeName = "place_name"
    }
}
