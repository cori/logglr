import XCTest
@testable import LifeLogKit

final class KeychainHelperTests: XCTestCase {

    let testService = "com.lifelog.test"
    let testAccount = "test-account"

    override func setUp() {
        super.setUp()
        // Clean up any existing test data
        try? KeychainHelper.delete(service: testService, account: testAccount)
    }

    override func tearDown() {
        // Clean up after tests
        try? KeychainHelper.delete(service: testService, account: testAccount)
        super.tearDown()
    }

    // MARK: - Save Tests

    func testSaveString() throws {
        let testValue = "test-api-key-12345"

        try KeychainHelper.save(testValue, service: testService, account: testAccount)

        // Verify it was saved
        let retrieved = try KeychainHelper.retrieve(service: testService, account: testAccount)
        XCTAssertEqual(retrieved, testValue)
    }

    func testSaveOverwritesExisting() throws {
        let firstValue = "first-value"
        let secondValue = "second-value"

        // Save first value
        try KeychainHelper.save(firstValue, service: testService, account: testAccount)

        // Save second value (should overwrite)
        try KeychainHelper.save(secondValue, service: testService, account: testAccount)

        // Verify second value is stored
        let retrieved = try KeychainHelper.retrieve(service: testService, account: testAccount)
        XCTAssertEqual(retrieved, secondValue)
    }

    func testSaveEmptyString() throws {
        let emptyValue = ""

        try KeychainHelper.save(emptyValue, service: testService, account: testAccount)

        let retrieved = try KeychainHelper.retrieve(service: testService, account: testAccount)
        XCTAssertEqual(retrieved, emptyValue)
    }

    func testSaveLongString() throws {
        // Test with a long API key
        let longValue = String(repeating: "a", count: 1000)

        try KeychainHelper.save(longValue, service: testService, account: testAccount)

        let retrieved = try KeychainHelper.retrieve(service: testService, account: testAccount)
        XCTAssertEqual(retrieved, longValue)
    }

    func testSaveSpecialCharacters() throws {
        let specialValue = "key-!@#$%^&*()_+-=[]{}|;':\",./<>?"

        try KeychainHelper.save(specialValue, service: testService, account: testAccount)

        let retrieved = try KeychainHelper.retrieve(service: testService, account: testAccount)
        XCTAssertEqual(retrieved, specialValue)
    }

    // MARK: - Retrieve Tests

    func testRetrieveNonExistentThrows() {
        XCTAssertThrowsError(try KeychainHelper.retrieve(service: testService, account: "non-existent")) { error in
            XCTAssertTrue(error is KeychainHelper.KeychainError)
        }
    }

    func testRetrieveAfterDelete() throws {
        // Save, delete, then try to retrieve
        try KeychainHelper.save("test", service: testService, account: testAccount)
        try KeychainHelper.delete(service: testService, account: testAccount)

        XCTAssertThrowsError(try KeychainHelper.retrieve(service: testService, account: testAccount))
    }

    // MARK: - Delete Tests

    func testDelete() throws {
        // Save a value
        try KeychainHelper.save("test", service: testService, account: testAccount)

        // Delete it
        try KeychainHelper.delete(service: testService, account: testAccount)

        // Verify it's gone
        XCTAssertThrowsError(try KeychainHelper.retrieve(service: testService, account: testAccount))
    }

    func testDeleteNonExistentDoesNotThrow() {
        // Deleting a non-existent item should not throw
        XCTAssertNoThrow(try KeychainHelper.delete(service: testService, account: "non-existent"))
    }

    // MARK: - Multiple Items Tests

    func testMultipleAccountsInSameService() throws {
        let account1 = "account1"
        let account2 = "account2"
        let value1 = "value1"
        let value2 = "value2"

        defer {
            try? KeychainHelper.delete(service: testService, account: account1)
            try? KeychainHelper.delete(service: testService, account: account2)
        }

        // Save two different accounts in the same service
        try KeychainHelper.save(value1, service: testService, account: account1)
        try KeychainHelper.save(value2, service: testService, account: account2)

        // Verify both are stored independently
        XCTAssertEqual(try KeychainHelper.retrieve(service: testService, account: account1), value1)
        XCTAssertEqual(try KeychainHelper.retrieve(service: testService, account: account2), value2)
    }

    func testMultipleServicesWithSameAccount() throws {
        let service1 = "com.lifelog.service1"
        let service2 = "com.lifelog.service2"
        let value1 = "value1"
        let value2 = "value2"

        defer {
            try? KeychainHelper.delete(service: service1, account: testAccount)
            try? KeychainHelper.delete(service: service2, account: testAccount)
        }

        // Save same account in different services
        try KeychainHelper.save(value1, service: service1, account: testAccount)
        try KeychainHelper.save(value2, service: service2, account: testAccount)

        // Verify both are stored independently
        XCTAssertEqual(try KeychainHelper.retrieve(service: service1, account: testAccount), value1)
        XCTAssertEqual(try KeychainHelper.retrieve(service: service2, account: testAccount), value2)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess() throws {
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10

        DispatchQueue.concurrentPerform(iterations: 10) { index in
            do {
                let value = "value-\(index)"
                try KeychainHelper.save(value, service: testService, account: "\(testAccount)-\(index)")
                let retrieved = try KeychainHelper.retrieve(service: testService, account: "\(testAccount)-\(index)")
                XCTAssertEqual(retrieved, value)
                try KeychainHelper.delete(service: testService, account: "\(testAccount)-\(index)")
                expectation.fulfill()
            } catch {
                XCTFail("Concurrent access failed: \(error)")
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
