import Foundation

/// A log entry representing a timestamped event, mood, note, or metric
/// This is the primary API transfer object for communicating with the backend
public struct LogEntry: Codable, Equatable, Identifiable, Sendable {
    /// Unique identifier for the entry
    public let id: UUID

    /// When the logged event occurred
    public let timestamp: Date

    /// When the entry was recorded/created (may differ from timestamp for retroactive logging)
    public let recordedAt: Date

    /// Source device or application (e.g., "watch", "iphone", "drafts")
    public let source: String

    /// Unique identifier for the device
    public let deviceId: String

    /// Optional category for filtering (e.g., "mood", "work", "note")
    public var category: String?

    /// The entry data payload
    public var data: LogData

    public init(
        id: UUID,
        timestamp: Date,
        recordedAt: Date,
        source: String,
        deviceId: String,
        category: String? = nil,
        data: LogData
    ) {
        self.id = id
        self.timestamp = timestamp
        self.recordedAt = recordedAt
        self.source = source
        self.deviceId = deviceId
        self.category = category
        self.data = data
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case recordedAt = "recorded_at"
        case source
        case deviceId = "device_id"
        case category
        case data
    }
}
