import Foundation

/// Errors that can occur during LifeLog operations
public enum LifeLogError: LocalizedError, Equatable {

    // MARK: - Network Errors

    /// No internet connection available
    case networkUnavailable

    /// Invalid API URL
    case invalidURL

    /// Request timeout
    case timeout

    // MARK: - Authentication Errors

    /// API key is missing or invalid
    case unauthorized

    /// API key is not configured
    case apiKeyNotConfigured

    // MARK: - Server Errors

    /// Server returned an error response
    case serverError(statusCode: Int, message: String?)

    /// Server returned invalid data
    case invalidResponse

    /// Failed to decode server response
    case decodingError(underlying: Error)

    // MARK: - Client Errors

    /// Failed to encode request data
    case encodingError(underlying: Error)

    /// Invalid request data
    case invalidRequest(reason: String)

    // MARK: - Sync Errors

    /// Sync operation failed
    case syncFailed(underlying: Error)

    /// No entries to sync
    case noEntriesToSync

    // MARK: - Storage Errors

    /// Failed to save to local storage
    case storageFailed(underlying: Error)

    /// Failed to retrieve from local storage
    case retrievalFailed(underlying: Error)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection"
        case .invalidURL:
            return "Invalid API URL"
        case .timeout:
            return "Request timeout"
        case .unauthorized:
            return "Invalid API key"
        case .apiKeyNotConfigured:
            return "API key not configured"
        case .serverError(let statusCode, let message):
            if let message = message {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error (\(statusCode))"
        case .invalidResponse:
            return "Invalid server response"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .invalidRequest(let reason):
            return "Invalid request: \(reason)"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .noEntriesToSync:
            return "No entries to sync"
        case .storageFailed(let error):
            return "Storage failed: \(error.localizedDescription)"
        case .retrievalFailed(let error):
            return "Retrieval failed: \(error.localizedDescription)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .networkUnavailable:
            return "The device is not connected to the internet."
        case .unauthorized:
            return "The API key is invalid or has expired."
        case .apiKeyNotConfigured:
            return "No API key has been configured in settings."
        case .serverError(_, _):
            return "The server encountered an error processing the request."
        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .unauthorized, .apiKeyNotConfigured:
            return "Check your API key in settings."
        case .invalidURL:
            return "Check your API URL in settings."
        case .timeout:
            return "Try again later."
        case .serverError(_, _):
            return "Try again later or contact support if the problem persists."
        default:
            return "Try again or contact support if the problem persists."
        }
    }

    // MARK: - Equatable

    public static func == (lhs: LifeLogError, rhs: LifeLogError) -> Bool {
        switch (lhs, rhs) {
        case (.networkUnavailable, .networkUnavailable),
             (.invalidURL, .invalidURL),
             (.timeout, .timeout),
             (.unauthorized, .unauthorized),
             (.apiKeyNotConfigured, .apiKeyNotConfigured),
             (.invalidResponse, .invalidResponse),
             (.noEntriesToSync, .noEntriesToSync):
            return true
        case (.serverError(let lCode, let lMsg), .serverError(let rCode, let rMsg)):
            return lCode == rCode && lMsg == rMsg
        case (.invalidRequest(let lReason), .invalidRequest(let rReason)):
            return lReason == rReason
        // For errors with underlying errors, compare types only
        case (.decodingError, .decodingError),
             (.encodingError, .encodingError),
             (.syncFailed, .syncFailed),
             (.storageFailed, .storageFailed),
             (.retrievalFailed, .retrievalFailed):
            return true
        default:
            return false
        }
    }
}
