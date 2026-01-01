import Foundation
import LifeLogKit

/// Global app state managing API configuration and sync status
@MainActor
final class AppState: ObservableObject {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Published Properties

    @Published var isConfigured: Bool = false
    @Published var apiBaseURL: String = ""
    @Published var lastSyncDate: Date?
    @Published var isSyncing: Bool = false

    // MARK: - Private Properties

    private(set) var apiClient: APIClient?

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let apiBaseURL = "apiBaseURL"
        static let lastSyncDate = "lastSyncDate"
    }

    // MARK: - Initialization

    private init() {
        loadConfiguration()
    }

    // MARK: - Configuration

    /// Load configuration from UserDefaults and Keychain
    func loadConfiguration() {
        // Load API base URL from UserDefaults
        if let savedURL = UserDefaults.standard.string(forKey: Keys.apiBaseURL),
           !savedURL.isEmpty {
            apiBaseURL = savedURL

            // Try to load API key from Keychain
            do {
                let apiKey = try KeychainHelper.retrieve(
                    service: "com.lifelog.api",
                    account: "apiKey"
                )

                // Create API client
                let config = try APIConfiguration(
                    baseURLString: savedURL,
                    apiKey: apiKey
                )
                apiClient = APIClient(configuration: config)
                isConfigured = true

                print("✅ API configuration loaded")
            } catch {
                print("⚠️ Failed to load API key: \(error)")
                isConfigured = false
            }
        }

        // Load last sync date
        if let savedDate = UserDefaults.standard.object(forKey: Keys.lastSyncDate) as? Date {
            lastSyncDate = savedDate
        }
    }

    /// Save configuration to UserDefaults and Keychain
    /// - Parameters:
    ///   - baseURL: The API base URL
    ///   - apiKey: The API key
    func saveConfiguration(baseURL: String, apiKey: String) throws {
        // Validate URL
        guard let url = URL(string: baseURL) else {
            throw LifeLogError.invalidURL
        }

        // Save URL to UserDefaults
        UserDefaults.standard.set(baseURL, forKey: Keys.apiBaseURL)

        // Save API key to Keychain
        try KeychainHelper.save(
            apiKey,
            service: "com.lifelog.api",
            account: "apiKey"
        )

        // Update state
        apiBaseURL = baseURL

        // Create API client
        let config = APIConfiguration(baseURL: url, apiKey: apiKey)
        apiClient = APIClient(configuration: config)
        isConfigured = true

        print("✅ API configuration saved")
    }

    /// Clear all configuration
    func clearConfiguration() {
        UserDefaults.standard.removeObject(forKey: Keys.apiBaseURL)
        try? KeychainHelper.delete(service: "com.lifelog.api", account: "apiKey")

        apiBaseURL = ""
        apiClient = nil
        isConfigured = false
        lastSyncDate = nil

        print("🗑️ Configuration cleared")
    }

    /// Update last sync date
    func updateLastSyncDate() {
        let now = Date()
        lastSyncDate = now
        UserDefaults.standard.set(now, forKey: Keys.lastSyncDate)
    }
}
