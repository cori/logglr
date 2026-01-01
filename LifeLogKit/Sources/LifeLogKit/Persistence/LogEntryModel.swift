import Foundation
import SwiftData

/// SwiftData persistence model for log entries
/// This is the mutable, reference-type version used for local storage
@Model
public final class LogEntryModel {

    // MARK: - Properties

    /// Unique identifier (matches LogEntry.id)
    @Attribute(.unique) public var id: UUID

    /// When the logged event occurred
    public var timestamp: Date

    /// When the entry was recorded/created
    public var recordedAt: Date

    /// Source device or application
    public var source: String

    /// Device identifier
    public var deviceId: String

    /// Optional category
    public var category: String?

    /// Whether this entry has been synced to the server
    public var synced: Bool

    // MARK: - Data Payload (stored as separate properties for SwiftData compatibility)

    /// Freeform text content
    public var text: String?

    /// Metric name (e.g., "mood", "energy")
    public var metricName: String?

    /// Metric value
    public var metricValue: Double?

    /// Metric unit
    public var metricUnit: String?

    /// Metric scale minimum
    public var metricScaleMin: Double?

    /// Metric scale maximum
    public var metricScaleMax: Double?

    /// Location latitude
    public var locationLatitude: Double?

    /// Location longitude
    public var locationLongitude: Double?

    /// Location accuracy
    public var locationAccuracy: Double?

    /// Location altitude
    public var locationAltitude: Double?

    /// Location place name
    public var locationPlaceName: String?

    /// Tags (stored as comma-separated string)
    public var tagsString: String?

    // MARK: - Initialization

    public init(
        id: UUID,
        timestamp: Date,
        recordedAt: Date,
        source: String,
        deviceId: String,
        category: String? = nil,
        synced: Bool = false,
        text: String? = nil,
        metricName: String? = nil,
        metricValue: Double? = nil,
        metricUnit: String? = nil,
        metricScaleMin: Double? = nil,
        metricScaleMax: Double? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        locationAccuracy: Double? = nil,
        locationAltitude: Double? = nil,
        locationPlaceName: String? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.recordedAt = recordedAt
        self.source = source
        self.deviceId = deviceId
        self.category = category
        self.synced = synced
        self.text = text
        self.metricName = metricName
        self.metricValue = metricValue
        self.metricUnit = metricUnit
        self.metricScaleMin = metricScaleMin
        self.metricScaleMax = metricScaleMax
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.locationAccuracy = locationAccuracy
        self.locationAltitude = locationAltitude
        self.locationPlaceName = locationPlaceName
        self.tagsString = tags?.joined(separator: ",")
    }

    // MARK: - Convenience Properties

    /// Get tags as an array
    public var tags: [String]? {
        get {
            guard let tagsString = tagsString, !tagsString.isEmpty else {
                return nil
            }
            return tagsString.split(separator: ",").map(String.init)
        }
        set {
            tagsString = newValue?.joined(separator: ",")
        }
    }

    /// Get metric as Metric struct (if metric data exists)
    public var metric: Metric? {
        guard let name = metricName, let value = metricValue else {
            return nil
        }
        return Metric(
            name: name,
            value: value,
            unit: metricUnit,
            scaleMin: metricScaleMin,
            scaleMax: metricScaleMax
        )
    }

    /// Get location as Location struct (if location data exists)
    public var location: Location? {
        guard let latitude = locationLatitude,
              let longitude = locationLongitude else {
            return nil
        }
        return Location(
            latitude: latitude,
            longitude: longitude,
            accuracy: locationAccuracy,
            altitude: locationAltitude,
            placeName: locationPlaceName
        )
    }

    /// Get data as LogData struct
    public var data: LogData {
        LogData(
            text: text,
            metric: metric,
            location: location,
            tags: tags
        )
    }
}
