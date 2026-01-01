import XCTest
@testable import LifeLogKit

final class DeviceInfoTests: XCTestCase {

    func testSourceReturnsCorrectPlatform() {
        let source = DeviceInfo.source

        // Source should be one of the expected platforms
        let validSources = ["watch", "iphone", "ipad", "mac"]
        XCTAssertTrue(validSources.contains(source), "Source '\(source)' should be one of: \(validSources)")
    }

    func testSourceIsNotEmpty() {
        let source = DeviceInfo.source
        XCTAssertFalse(source.isEmpty, "Source should not be empty")
    }

    func testIdentifierIsNotEmpty() {
        let identifier = DeviceInfo.identifier
        XCTAssertFalse(identifier.isEmpty, "Identifier should not be empty")
    }

    func testIdentifierIsConsistent() {
        let identifier1 = DeviceInfo.identifier
        let identifier2 = DeviceInfo.identifier

        XCTAssertEqual(identifier1, identifier2, "Identifier should be consistent across calls")
    }

    func testIdentifierHasReasonableLength() {
        let identifier = DeviceInfo.identifier

        // UUID strings are 36 characters, but we might have prefixes
        XCTAssertGreaterThan(identifier.count, 10, "Identifier should have reasonable length")
        XCTAssertLessThan(identifier.count, 100, "Identifier should not be excessively long")
    }

    func testAppGroupIDIsValid() {
        let appGroupID = DeviceInfo.appGroupID

        XCTAssertTrue(appGroupID.hasPrefix("group."), "App Group ID should start with 'group.'")
        XCTAssertTrue(appGroupID.contains("lifelog"), "App Group ID should contain 'lifelog'")
    }
}
