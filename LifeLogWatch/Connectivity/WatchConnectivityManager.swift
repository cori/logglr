import Foundation
import WatchConnectivity
import LifeLogKit

/// Manages Watch Connectivity for syncing with iPhone
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = WatchConnectivityManager()

    // MARK: - Published Properties

    @Published private(set) var isReachable = false
    @Published private(set) var lastSyncDate: Date?

    // MARK: - Private Properties

    private var session: WCSession?

    // MARK: - Initialization

    private override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Public Methods

    /// Send a log entry to the iPhone
    /// - Parameter entry: The entry to send
    func sendEntry(_ entry: LogEntry) {
        guard let session = session else {
            print("❌ Watch Connectivity not supported")
            return
        }

        do {
            let data = try JSONEncoder.iso8601.encode(entry)

            if session.isReachable {
                // iPhone is reachable, send immediately
                let message = ["entry": data]
                session.sendMessage(message, replyHandler: { reply in
                    print("✅ Entry sent to iPhone, reply: \(reply)")
                }) { error in
                    print("❌ Failed to send entry: \(error)")
                    // Fall back to application context
                    self.sendViaApplicationContext(entry: entry, data: data)
                }
            } else {
                // iPhone not reachable, use application context
                sendViaApplicationContext(entry: entry, data: data)
            }
        } catch {
            print("❌ Failed to encode entry: \(error)")
        }
    }

    /// Request sync from iPhone
    func requestSync() {
        guard let session = session, session.isReachable else {
            print("⚠️ iPhone not reachable, cannot request sync")
            return
        }

        let message = ["action": "sync"]
        session.sendMessage(message, replyHandler: { reply in
            print("✅ Sync requested, reply: \(reply)")
        }) { error in
            print("❌ Failed to request sync: \(error)")
        }
    }

    // MARK: - Private Methods

    private func sendViaApplicationContext(entry: LogEntry, data: Data) {
        guard let session = session else { return }

        do {
            // Use timestamp as key to avoid overwriting
            let context = ["entry_\(entry.timestamp.timeIntervalSince1970)": data]
            try session.updateApplicationContext(context)
            print("✅ Entry queued via application context")
        } catch {
            print("❌ Failed to update application context: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                print("❌ Watch session activation failed: \(error)")
            } else {
                print("✅ Watch session activated: \(activationState.rawValue)")
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
            print("📱 iPhone reachability changed: \(session.isReachable)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            print("📨 Received message from iPhone: \(message.keys)")

            // Handle sync acknowledgment
            if let action = message["action"] as? String, action == "syncComplete" {
                lastSyncDate = Date()
                print("✅ Sync acknowledged by iPhone")
            }
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            print("📨 Received message with reply handler from iPhone")
            replyHandler(["status": "received"])
        }
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            print("📨 Received application context from iPhone: \(applicationContext.keys.count) items")
            // Handle any configuration updates from iPhone if needed
        }
    }
}
