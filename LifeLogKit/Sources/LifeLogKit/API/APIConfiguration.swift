import Foundation

/// Configuration for the LifeLog API client
public struct APIConfiguration: Equatable, Sendable {

    /// The base URL of the API (e.g., "https://username-lifelog.web.val.run")
    public let baseURL: URL

    /// The API key for authentication
    public let apiKey: String

    /// Request timeout in seconds (default: 30)
    public var timeout: TimeInterval

    /// Create a new API configuration
    /// - Parameters:
    ///   - baseURL: The base URL of the API
    ///   - apiKey: The API key for authentication
    ///   - timeout: Request timeout in seconds (default: 30)
    public init(baseURL: URL, apiKey: String, timeout: TimeInterval = 30) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.timeout = timeout
    }

    /// Create a new API configuration from a URL string
    /// - Parameters:
    ///   - baseURLString: The base URL as a string
    ///   - apiKey: The API key for authentication
    ///   - timeout: Request timeout in seconds (default: 30)
    /// - Throws: LifeLogError.invalidURL if the URL string is invalid
    public init(baseURLString: String, apiKey: String, timeout: TimeInterval = 30) throws {
        guard let url = URL(string: baseURLString) else {
            throw LifeLogError.invalidURL
        }
        self.init(baseURL: url, apiKey: apiKey, timeout: timeout)
    }
}
