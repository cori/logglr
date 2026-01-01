import XCTest
import SwiftData
@testable import LifeLogKit

@MainActor
final class SyncManagerTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var mockSession: MockURLSession!
    var apiClient: APIClient!
    var syncManager: SyncManager!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory container
        let schema = Schema([LogEntryModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext

        // Create mock API client
        mockSession = MockURLSession()
        let apiConfig = try APIConfiguration(
            baseURLString: "https://test.val.run",
            apiKey: "test-key"
        )
        apiClient = APIClient(configuration: apiConfig, session: mockSession)

        // Create sync manager
        syncManager = SyncManager(apiClient: apiClient, modelContainer: container)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        mockSession = nil
        apiClient = nil
        syncManager = nil
        try await super.tearDown()
    }

    // MARK: - Upload Tests

    func testSyncUnsyncedEntries() async throws {
        // Create unsynced entries
        let entry1 = createTestEntry(synced: false)
        let entry2 = createTestEntry(synced: false)
        context.insert(entry1)
        context.insert(entry2)
        try context.save()

        // Mock successful API response
        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = """
        {"created": 2}
        """.data(using: .utf8)

        // Perform sync
        try await syncManager.syncUnsyncedEntries()

        // Verify entries are marked as synced
        let descriptor = FetchDescriptor<LogEntryModel>()
        let allEntries = try context.fetch(descriptor)

        XCTAssertEqual(allEntries.count, 2)
        XCTAssertTrue(allEntries.allSatisfy { $0.synced })
        XCTAssertNotNil(syncManager.lastSyncDate)
    }

    func testSyncNoUnsyncedEntries() async throws {
        // Create only synced entries
        let entry = createTestEntry(synced: true)
        context.insert(entry)
        try context.save()

        // Perform sync
        try await syncManager.syncUnsyncedEntries()

        // Should not make API call
        XCTAssertNil(mockSession.lastRequest)
    }

    func testSyncBatching() async throws {
        // Create 100 unsynced entries (should be batched into 2 batches of 50)
        for _ in 0..<100 {
            let entry = createTestEntry(synced: false)
            context.insert(entry)
        }
        try context.save()

        var requestCount = 0

        // Mock multiple successful responses
        mockSession.dataHandler = { _ in
            requestCount += 1
            return (
                """
                {"created": 50}
                """.data(using: .utf8)!,
                HTTPURLResponse(
                    url: URL(string: "https://test.val.run/api/entries")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        }

        // Perform sync
        try await syncManager.syncUnsyncedEntries()

        // Should have made 2 API calls
        XCTAssertEqual(requestCount, 2)

        // All entries should be synced
        let descriptor = FetchDescriptor<LogEntryModel>()
        let allEntries = try context.fetch(descriptor)
        XCTAssertTrue(allEntries.allSatisfy { $0.synced })
    }

    func testSyncFailure() async throws {
        // Create unsynced entry
        let entry = createTestEntry(synced: false)
        context.insert(entry)
        try context.save()

        // Mock error response
        mockSession.nextError = URLError(.notConnectedToInternet)

        // Sync should throw
        do {
            try await syncManager.syncUnsyncedEntries()
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(error is LifeLogError)
        }

        // Entry should remain unsynced
        let descriptor = FetchDescriptor<LogEntryModel>()
        let allEntries = try context.fetch(descriptor)
        XCTAssertFalse(allEntries.first!.synced)
    }

    // MARK: - Download Tests

    func testFetchEntriesFromAPI() async throws {
        let apiEntry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test",
            category: "test",
            data: LogData(text: "From API")
        )

        let jsonData = try JSONEncoder.iso8601.encode([apiEntry])

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = jsonData

        // Fetch from API
        let count = try await syncManager.fetchEntriesFromAPI()

        XCTAssertEqual(count, 1)

        // Verify entry was saved
        let descriptor = FetchDescriptor<LogEntryModel>()
        let entries = try context.fetch(descriptor)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.text, "From API")
        XCTAssertTrue(entries.first!.synced) // Should be marked as synced
    }

    func testFetchUpdatesExistingEntry() async throws {
        // Create existing entry
        let id = UUID()
        let existing = createTestEntry(synced: true)
        existing.id = id
        existing.text = "Original text"
        context.insert(existing)
        try context.save()

        // Create updated API entry with same ID
        let updatedEntry = LogEntry(
            id: id,
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test",
            category: "test",
            data: LogData(text: "Updated text")
        )

        let jsonData = try JSONEncoder.iso8601.encode([updatedEntry])

        mockSession.nextResponse = HTTPURLResponse(
            url: URL(string: "https://test.val.run/api/entries")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        mockSession.nextData = jsonData

        // Fetch from API
        let newCount = try await syncManager.fetchEntriesFromAPI()

        XCTAssertEqual(newCount, 0) // No new entries, just updated

        // Verify entry was updated
        let descriptor = FetchDescriptor<LogEntryModel>()
        let entries = try context.fetch(descriptor)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.text, "Updated text")
    }

    // MARK: - Full Sync Tests

    func testPerformFullSync() async throws {
        // Create local unsynced entry
        let localEntry = createTestEntry(synced: false)
        context.insert(localEntry)
        try context.save()

        // Mock upload response
        mockSession.dataHandler = { request in
            if request.httpMethod == "POST" {
                return (
                    """
                    {"created": 1}
                    """.data(using: .utf8)!,
                    HTTPURLResponse(
                        url: URL(string: "https://test.val.run/api/entries")!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            } else {
                // GET request
                let apiEntry = LogEntry(
                    id: UUID(),
                    timestamp: Date(),
                    recordedAt: Date(),
                    source: "test",
                    deviceId: "test",
                    data: LogData(text: "From server")
                )
                let jsonData = try! JSONEncoder.iso8601.encode([apiEntry])
                return (
                    jsonData,
                    HTTPURLResponse(
                        url: URL(string: "https://test.val.run/api/entries")!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            }
        }

        // Perform full sync
        let (uploaded, downloaded) = try await syncManager.performFullSync()

        XCTAssertEqual(uploaded, 1)
        XCTAssertEqual(downloaded, 1)

        // Should have 2 entries total
        let descriptor = FetchDescriptor<LogEntryModel>()
        let entries = try context.fetch(descriptor)
        XCTAssertEqual(entries.count, 2)
    }

    // MARK: - Helpers

    private func createTestEntry(synced: Bool) -> LogEntryModel {
        LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "test",
            deviceId: "test-device",
            category: "test",
            synced: synced,
            text: "Test entry"
        )
    }
}

// MARK: - Mock URL Session Enhancement

extension MockURLSession {
    var dataHandler: ((URLRequest) -> (Data, URLResponse))?

    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request

        if let error = nextError {
            throw error
        }

        if let handler = dataHandler {
            return handler(request)
        }

        return (nextData ?? Data(), nextResponse ?? URLResponse())
    }
}
