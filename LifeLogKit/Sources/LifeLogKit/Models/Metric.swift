import Foundation

/// Represents a numeric measurement with optional scale information
public struct Metric: Codable, Equatable, Sendable {
    /// The name of the metric (e.g., "mood", "energy", "focus", "pain")
    public let name: String

    /// The numeric value of the measurement
    public let value: Double

    /// Optional unit label (e.g., "°F", "bpm", "scale")
    public var unit: String?

    /// Optional minimum value of the scale (e.g., 1 for a 1-10 scale)
    public var scaleMin: Double?

    /// Optional maximum value of the scale (e.g., 10 for a 1-10 scale)
    public var scaleMax: Double?

    public init(
        name: String,
        value: Double,
        unit: String? = nil,
        scaleMin: Double? = nil,
        scaleMax: Double? = nil
    ) {
        self.name = name
        self.value = value
        self.unit = unit
        self.scaleMin = scaleMin
        self.scaleMax = scaleMax
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case name
        case value
        case unit
        case scaleMin = "scale_min"
        case scaleMax = "scale_max"
    }
}
