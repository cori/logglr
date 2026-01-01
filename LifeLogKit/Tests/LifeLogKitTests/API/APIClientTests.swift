import XCTest
@testable import LifeLogKit

final class APIClientTests: XCTestCase {

    var mockSession: MockURLSession!
    var config: APIConfiguration!
    var client: APIClient!

    override func setUp() async throws {
        try await super.setUp()
        mockSession = MockURLSession()
        config = try APIConfiguration(
            baseURLString: "https://test.val.run",
            apiKey: "test-api-key"
        )
        client = APIClient(configuration: config, session: mockSession)
    }

    // MARK: - Create Entries Tests

    func testCreateSingleEntry() async throws {
        let entry = createTestEntry()

        // Mock successful response
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = """
        {"created": 1}
        """.data(using: .utf8)

        try await client.createEntries([entry])

        // Verify request was made
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertTrue(mockSession.lastRequest?.url?.absoluteString.contains("/api/entries") ?? false)
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-api-key")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testCreateBatchEntries() async throws {
        let entries = [createTestEntry(), createTestEntry(), createTestEntry()]

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = """
        {"created": 3}
        """.data(using: .utf8)

        try await client.createEntries(entries)

        // Verify batch was sent
        let requestBody = try XCTUnwrap(mockSession.lastRequest?.httpBody)
        let decoded = try JSONDecoder.iso8601.decode([LogEntry].self, from: requestBody)
        XCTAssertEqual(decoded.count, 3)
    }

    func testCreateEntriesWithUnauthorized() async throws {
        let entry = createTestEntry()

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = """
        {"error": "Unauthorized"}
        """.data(using: .utf8)

        do {
            try await client.createEntries([entry])
            XCTFail("Should have thrown unauthorized error")
        } catch LifeLogError.unauthorized {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testCreateEntriesWithServerError() async throws {
        let entry = createTestEntry()

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = """
        {"error": "Internal server error"}
        """.data(using: .utf8)

        do {
            try await client.createEntries([entry])
            XCTFail("Should have thrown server error")
        } catch LifeLogError.serverError(let code, _) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Fetch Entries Tests

    func testFetchEntries() async throws {
        let testEntries = [createTestEntry(), createTestEntry()]
        let jsonData = try JSONEncoder.iso8601.encode(testEntries)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = jsonData

        let entries = try await client.fetchEntries()

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "GET")
    }

    func testFetchEntriesWithSinceFilter() async throws {
        let since = Date(timeIntervalSince1970: 1704067200)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = "[]".data(using: .utf8)

        _ = try await client.fetchEntries(since: since)

        let url = try XCTUnwrap(mockSession.lastRequest?.url)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let sinceParam = components?.queryItems?.first { $0.name == "since" }

        XCTAssertNotNil(sinceParam)
        XCTAssertTrue(sinceParam?.value?.contains("2024-01-01") ?? false)
    }

    func testFetchEntriesWithCategoryFilter() async throws {
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = "[]".data(using: .utf8)

        _ = try await client.fetchEntries(category: "mood")

        let url = try XCTUnwrap(mockSession.lastRequest?.url)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let categoryParam = components?.queryItems?.first { $0.name == "category" }

        XCTAssertEqual(categoryParam?.value, "mood")
    }

    func testFetchEntriesWithMultipleFilters() async throws {
        let since = Date(timeIntervalSince1970: 1704067200)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = "[]".data(using: .utf8)

        _ = try await client.fetchEntries(
            since: since,
            category: "mood",
            source: "iphone",
            limit: 50
        )

        let url = try XCTUnwrap(mockSession.lastRequest?.url)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = try XCTUnwrap(components?.queryItems)

        XCTAssertTrue(queryItems.contains { $0.name == "since" })
        XCTAssertTrue(queryItems.contains { $0.name == "category" && $0.value == "mood" })
        XCTAssertTrue(queryItems.contains { $0.name == "source" && $0.value == "iphone" })
        XCTAssertTrue(queryItems.contains { $0.name == "limit" && $0.value == "50" })
    }

    // MARK: - Fetch Single Entry Tests

    func testFetchEntryById() async throws {
        let testEntry = createTestEntry()
        let jsonData = try JSONEncoder.iso8601.encode(testEntry)

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries/\(testEntry.id)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = jsonData

        let entry = try await client.fetchEntry(id: testEntry.id)

        XCTAssertEqual(entry.id, testEntry.id)
        XCTAssertTrue(mockSession.lastRequest?.url?.absoluteString.contains(testEntry.id.uuidString) ?? false)
    }

    func testFetchEntryNotFound() async throws {
        let id = UUID()

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries/\(id)")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = """
        {"error": "Entry not found"}
        """.data(using: .utf8)

        do {
            _ = try await client.fetchEntry(id: id)
            XCTFail("Should have thrown server error")
        } catch LifeLogError.serverError(let code, _) {
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Error Handling Tests

    func testNetworkError() async throws {
        let entry = createTestEntry()

        mockSession.nextError = URLError(.notConnectedToInternet)

        do {
            try await client.createEntries([entry])
            XCTFail("Should have thrown network error")
        } catch LifeLogError.networkUnavailable {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testTimeout() async throws {
        let entry = createTestEntry()

        mockSession.nextError = URLError(.timedOut)

        do {
            try await client.createEntries([entry])
            XCTFail("Should have thrown timeout error")
        } catch LifeLogError.timeout {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testInvalidResponseData() async throws {
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = "invalid json".data(using: .utf8)

        do {
            _ = try await client.fetchEntries()
            XCTFail("Should have thrown decoding error")
        } catch LifeLogError.decodingError {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Helpers

    private func createTestEntry() -> LogEntry {
        LogEntry(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: DeviceInfo.source,
            deviceId: DeviceInfo.identifier,
            category: "test",
            data: LogData(text: "Test entry")
        )
    }
}

// MARK: - Mock URLSession

class MockURLSession: URLSessionProtocol {
    var nextData: Data?
    var nextResponse: URLResponse?
    var nextError: Error?
    var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request

        if let error = nextError {
            throw error
        }

        return (nextData ?? Data(), nextResponse ?? URLResponse())
    }
}
