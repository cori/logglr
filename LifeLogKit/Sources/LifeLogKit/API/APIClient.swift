import Foundation

/// HTTP client for the LifeLog API
/// Thread-safe actor that handles all API communication
public actor APIClient {

    // MARK: - Properties

    private let configuration: APIConfiguration
    private let session: URLSessionProtocol

    // MARK: - Initialization

    /// Create a new API client
    /// - Parameters:
    ///   - configuration: API configuration with URL and key
    ///   - session: URLSession (or mock for testing)
    public init(
        configuration: APIConfiguration,
        session: URLSessionProtocol = URLSession.shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    // MARK: - Public Methods

    /// Create one or more log entries
    /// - Parameter entries: Array of entries to create
    /// - Throws: LifeLogError if the operation fails
    public func createEntries(_ entries: [LogEntry]) async throws {
        guard !entries.isEmpty else {
            throw LifeLogError.invalidRequest(reason: "No entries provided")
        }

        let url = configuration.baseURL.appendingPathComponent("api/entries")
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONEncoder.iso8601.encode(entries)
        } catch {
            throw LifeLogError.encodingError(underlying: error)
        }

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LifeLogError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            try handleErrorResponse(statusCode: httpResponse.statusCode, data: data)
        }

        // Successfully created
    }

    /// Fetch entries with optional filters
    /// - Parameters:
    ///   - since: Return only entries after this date
    ///   - until: Return only entries before this date
    ///   - category: Filter by category
    ///   - source: Filter by source device
    ///   - limit: Maximum number of entries to return
    ///   - offset: Pagination offset
    /// - Returns: Array of log entries
    /// - Throws: LifeLogError if the operation fails
    public func fetchEntries(
        since: Date? = nil,
        until: Date? = nil,
        category: String? = nil,
        source: String? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [LogEntry] {
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent("api/entries"),
            resolvingAgainstBaseURL: false
        )!

        var queryItems: [URLQueryItem] = []

        if let since = since {
            queryItems.append(URLQueryItem(name: "since", value: since.iso8601String))
        }

        if let until = until {
            queryItems.append(URLQueryItem(name: "until", value: until.iso8601String))
        }

        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }

        if let source = source {
            queryItems.append(URLQueryItem(name: "source", value: source))
        }

        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        queryItems.append(URLQueryItem(name: "offset", value: String(offset)))

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw LifeLogError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LifeLogError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            try handleErrorResponse(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try JSONDecoder.iso8601.decode([LogEntry].self, from: data)
        } catch {
            throw LifeLogError.decodingError(underlying: error)
        }
    }

    /// Fetch a single entry by ID
    /// - Parameter id: The entry ID
    /// - Returns: The log entry
    /// - Throws: LifeLogError if the entry is not found or the operation fails
    public func fetchEntry(id: UUID) async throws -> LogEntry {
        let url = configuration.baseURL
            .appendingPathComponent("api/entries")
            .appendingPathComponent(id.uuidString)

        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LifeLogError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            try handleErrorResponse(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try JSONDecoder.iso8601.decode(LogEntry.self, from: data)
        } catch {
            throw LifeLogError.decodingError(underlying: error)
        }
    }

    // MARK: - Private Helpers

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw LifeLogError.networkUnavailable
            case .timedOut:
                throw LifeLogError.timeout
            default:
                throw LifeLogError.invalidResponse
            }
        }
    }

    private func handleErrorResponse(statusCode: Int, data: Data) throws -> Never {
        // Try to extract error message from response
        var errorMessage: String?

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["error"] as? String {
            errorMessage = message
        }

        switch statusCode {
        case 401:
            throw LifeLogError.unauthorized
        default:
            throw LifeLogError.serverError(statusCode: statusCode, message: errorMessage)
        }
    }
}
