import Foundation

// MARK: - LogEntry to LogEntryModel

extension LogEntry {

    /// Convert API model to persistence model
    /// - Parameter synced: Whether the entry has been synced to the server
    /// - Returns: SwiftData model ready for persistence
    public func toPersistenceModel(synced: Bool = false) -> LogEntryModel {
        LogEntryModel(
            id: id,
            timestamp: timestamp,
            recordedAt: recordedAt,
            source: source,
            deviceId: deviceId,
            category: category,
            synced: synced,
            text: data.text,
            metricName: data.metric?.name,
            metricValue: data.metric?.value,
            metricUnit: data.metric?.unit,
            metricScaleMin: data.metric?.scaleMin,
            metricScaleMax: data.metric?.scaleMax,
            locationLatitude: data.location?.latitude,
            locationLongitude: data.location?.longitude,
            locationAccuracy: data.location?.accuracy,
            locationAltitude: data.location?.altitude,
            locationPlaceName: data.location?.placeName,
            tags: data.tags
        )
    }
}

// MARK: - LogEntryModel to LogEntry

extension LogEntryModel {

    /// Convert persistence model to API model
    /// - Returns: Codable model ready for API transmission
    public func toAPIModel() -> LogEntry {
        LogEntry(
            id: id,
            timestamp: timestamp,
            recordedAt: recordedAt,
            source: source,
            deviceId: deviceId,
            category: category,
            data: data
        )
    }

    /// Update this model from an API model
    /// Useful for updating an existing persisted entry with fresh data from the API
    /// - Parameter entry: The API model with updated data
    public func update(from entry: LogEntry) {
        // Don't update id - it's the primary key
        timestamp = entry.timestamp
        recordedAt = entry.recordedAt
        source = entry.source
        deviceId = entry.deviceId
        category = entry.category

        // Update data fields
        text = entry.data.text
        metricName = entry.data.metric?.name
        metricValue = entry.data.metric?.value
        metricUnit = entry.data.metric?.unit
        metricScaleMin = entry.data.metric?.scaleMin
        metricScaleMax = entry.data.metric?.scaleMax
        locationLatitude = entry.data.location?.latitude
        locationLongitude = entry.data.location?.longitude
        locationAccuracy = entry.data.location?.accuracy
        locationAltitude = entry.data.location?.altitude
        locationPlaceName = entry.data.location?.placeName
        tags = entry.data.tags
    }
}

// MARK: - Convenience Initializers

extension LogEntryModel {

    /// Create a persistence model from an API model
    /// - Parameters:
    ///   - entry: The API model
    ///   - synced: Whether the entry has been synced
    /// - Returns: SwiftData model ready for persistence
    public convenience init(from entry: LogEntry, synced: Bool = false) {
        self.init(
            id: entry.id,
            timestamp: entry.timestamp,
            recordedAt: entry.recordedAt,
            source: entry.source,
            deviceId: entry.deviceId,
            category: entry.category,
            synced: synced,
            text: entry.data.text,
            metricName: entry.data.metric?.name,
            metricValue: entry.data.metric?.value,
            metricUnit: entry.data.metric?.unit,
            metricScaleMin: entry.data.metric?.scaleMin,
            metricScaleMax: entry.data.metric?.scaleMax,
            locationLatitude: entry.data.location?.latitude,
            locationLongitude: entry.data.location?.longitude,
            locationAccuracy: entry.data.location?.accuracy,
            locationAltitude: entry.data.location?.altitude,
            locationPlaceName: entry.data.location?.placeName,
            tags: entry.data.tags
        )
    }

    /// Create a persistence model with LogData
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - timestamp: When the event occurred
    ///   - recordedAt: When the entry was created
    ///   - source: Source device
    ///   - deviceId: Device identifier
    ///   - category: Optional category
    ///   - data: The log data
    ///   - synced: Whether synced to server
    public convenience init(
        id: UUID,
        timestamp: Date,
        recordedAt: Date,
        source: String,
        deviceId: String,
        category: String?,
        data: LogData,
        synced: Bool = false
    ) {
        self.init(
            id: id,
            timestamp: timestamp,
            recordedAt: recordedAt,
            source: source,
            deviceId: deviceId,
            category: category,
            synced: synced,
            text: data.text,
            metricName: data.metric?.name,
            metricValue: data.metric?.value,
            metricUnit: data.metric?.unit,
            metricScaleMin: data.metric?.scaleMin,
            metricScaleMax: data.metric?.scaleMax,
            locationLatitude: data.location?.latitude,
            locationLongitude: data.location?.longitude,
            locationAccuracy: data.location?.accuracy,
            locationAltitude: data.location?.altitude,
            locationPlaceName: data.location?.placeName,
            tags: data.tags
        )
    }
}
