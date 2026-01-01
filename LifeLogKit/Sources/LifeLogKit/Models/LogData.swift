import Foundation

/// The data payload for a log entry
/// Contains optional fields for different types of log entries (notes, metrics, location, etc.)
public struct LogData: Codable, Equatable, Sendable {
    /// Optional freeform text content
    public var text: String?

    /// Optional numeric metric (e.g., mood rating, pain level)
    public var metric: Metric?

    /// Optional geographic location
    public var location: Location?

    /// Optional tags for categorization and filtering
    public var tags: [String]?

    public init(
        text: String? = nil,
        metric: Metric? = nil,
        location: Location? = nil,
        tags: [String]? = nil
    ) {
        self.text = text
        self.metric = metric
        self.location = location
        self.tags = tags
    }
}
