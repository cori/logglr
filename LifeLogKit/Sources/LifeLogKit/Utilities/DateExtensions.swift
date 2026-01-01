import Foundation

// MARK: - Date Extensions

extension Date {

    /// Converts the date to an ISO 8601 string (e.g., "2024-01-01T12:30:45Z")
    public var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }

    /// Creates a date from an ISO 8601 string
    /// - Parameter string: ISO 8601 formatted string (e.g., "2024-01-01T12:30:45Z")
    /// - Returns: Date if parsing succeeds, nil otherwise
    public static func fromISO8601(_ string: String) -> Date? {
        // Try standard ISO8601 formatter first
        if let date = ISO8601DateFormatter().date(from: string) {
            return date
        }

        // Try with fractional seconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}

// MARK: - JSONEncoder Extension

extension JSONEncoder {

    /// A JSONEncoder configured to use ISO 8601 date encoding
    public static var iso8601: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

// MARK: - JSONDecoder Extension

extension JSONDecoder {

    /// A JSONDecoder configured to use ISO 8601 date decoding
    public static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
