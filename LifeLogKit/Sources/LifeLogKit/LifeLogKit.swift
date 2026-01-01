/// LifeLogKit
///
/// A Swift package for personal life logging across Apple platforms.
/// Provides models, API client, and sync capabilities for the LifeLog app.
///
/// Core models:
/// - `LogEntry`: Main API transfer object
/// - `LogData`: Entry data payload
/// - `Metric`: Numeric measurements
/// - `Location`: Geographic data
///
/// Usage:
/// ```swift
/// import LifeLogKit
///
/// let entry = LogEntry(
///     id: UUID(),
///     timestamp: Date(),
///     recordedAt: Date(),
///     source: "iphone",
///     deviceId: DeviceInfo.identifier,
///     category: "mood",
///     data: LogData(
///         metric: Metric(name: "mood", value: 8.0, scaleMin: 1.0, scaleMax: 10.0)
///     )
/// )
/// ```

import Foundation

// Re-export all public types for convenience
@_exported import struct Foundation.UUID
@_exported import struct Foundation.Date
