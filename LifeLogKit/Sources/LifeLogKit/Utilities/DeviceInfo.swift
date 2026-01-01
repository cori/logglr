import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

/// Provides device and platform information for log entries
public enum DeviceInfo {

    /// The source platform/device type
    /// Returns: "watch", "iphone", "ipad", or "mac"
    public static var source: String {
        #if os(watchOS)
        return "watch"
        #elseif os(macOS)
        return "mac"
        #elseif os(iOS)
        #if targetEnvironment(macCatalyst)
        return "mac"
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "ipad"
        } else {
            return "iphone"
        }
        #endif
        #else
        return "unknown"
        #endif
    }

    /// A stable device identifier
    /// Uses identifierForVendor on iOS/watchOS, generates stable ID on macOS
    public static var identifier: String {
        #if os(watchOS)
        return WKInterfaceDevice.current().identifierForVendor?.uuidString ?? "unknown-watch-\(UUID().uuidString)"
        #elseif os(macOS)
        // On macOS, try to get a stable identifier from IOKit
        // For MVP, we'll use a UserDefaults-stored UUID
        return macOSIdentifier()
        #elseif os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios-\(UUID().uuidString)"
        #else
        return "unknown-\(UUID().uuidString)"
        #endif
    }

    /// The App Group identifier for sharing data between app targets
    public static var appGroupID: String {
        return "group.com.lifelog.shared"
    }

    // MARK: - Private Helpers

    #if os(macOS)
    private static func macOSIdentifier() -> String {
        let key = "com.lifelog.deviceIdentifier"

        // Try to get existing identifier from UserDefaults
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }

        // Generate and store new identifier
        let newIdentifier = "mac-\(UUID().uuidString)"
        UserDefaults.standard.set(newIdentifier, forKey: key)
        return newIdentifier
    }
    #endif
}
