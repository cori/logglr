import Foundation
import Security

/// A helper for securely storing and retrieving strings from the Keychain
public enum KeychainHelper {

    // MARK: - Errors

    public enum KeychainError: Error, LocalizedError {
        case itemNotFound
        case duplicateItem
        case invalidData
        case unexpectedStatus(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "Item not found in keychain"
            case .duplicateItem:
                return "Item already exists in keychain"
            case .invalidData:
                return "Invalid data format"
            case .unexpectedStatus(let status):
                return "Keychain error: \(status)"
            }
        }
    }

    // MARK: - Public Methods

    /// Save a string to the keychain
    /// - Parameters:
    ///   - string: The string to save
    ///   - service: The service identifier (e.g., "com.lifelog.api")
    ///   - account: The account identifier (e.g., "apiKey")
    ///   - accessGroup: Optional access group for sharing between apps
    /// - Throws: KeychainError if the operation fails
    public static func save(
        _ string: String,
        service: String,
        account: String,
        accessGroup: String? = nil
    ) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Try to update existing item first
        var query = buildQuery(service: service, account: account, accessGroup: accessGroup)
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            // Successfully updated existing item
            return
        case errSecItemNotFound:
            // Item doesn't exist, create new one
            break
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }

        // Create new item
        query[kSecValueData as String] = data
        let addStatus = SecItemAdd(query as CFDictionary, nil)

        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    /// Retrieve a string from the keychain
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account identifier
    ///   - accessGroup: Optional access group
    /// - Returns: The stored string
    /// - Throws: KeychainError if the item is not found or cannot be decoded
    public static func retrieve(
        service: String,
        account: String,
        accessGroup: String? = nil
    ) throws -> String {
        var query = buildQuery(service: service, account: account, accessGroup: accessGroup)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return string
    }

    /// Delete an item from the keychain
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account identifier
    ///   - accessGroup: Optional access group
    /// - Throws: KeychainError if the operation fails (except for item not found)
    public static func delete(
        service: String,
        account: String,
        accessGroup: String? = nil
    ) throws {
        let query = buildQuery(service: service, account: account, accessGroup: accessGroup)
        let status = SecItemDelete(query as CFDictionary)

        // Don't throw error if item doesn't exist
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Private Helpers

    private static func buildQuery(
        service: String,
        account: String,
        accessGroup: String?
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}
