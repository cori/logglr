# LifeLog: Cross-Platform Apple Ecosystem Life Logging App

## Project Overview

A personal life logging system with native Apple apps (Watch, iPhone, iPad, Mac) backed by a simple HTTP API. Designed for minimal-friction capture of timestamped events, moods, locations, metrics, and notes.

### Core Principles

1. **Capture should be effortless** — especially on Watch, logging should require minimal interaction
1. **Flexible data model** — accommodate everything from automatic location pings to freeform journal entries
1. **Offline-first** — entries queue locally and sync when possible
1. **Simple backend** — Val Town HTTP API with SQLite, easily migratable
1. **Integration-friendly** — clean API that Drafts, Obsidian, Shortcuts can call

-----

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Swift Package: LifeLogKit                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Models    │  │  API Client │  │  Local Persistence  │  │
│  │ (LogEntry)  │  │  (HTTP)     │  │  (SwiftData)        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │                 │                    │
    ┌────┴────┐      ┌─────┴─────┐       ┌──────┴──────┐
    │ Watch   │      │  iPhone   │       │    Mac      │
    │  App    │      │  iPad App │       │    App      │
    └─────────┘      └───────────┘       └─────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │   Val Town HTTP API     │
              │   + HTML Dashboard      │
              │   + SQLite storage      │
              └─────────────────────────┘
```

### Sync Strategy

**Phase 1 (MVP):** Direct HTTP sync

- All devices POST directly to API when online
- SwiftData stores entries locally with `synced: Bool` flag
- Background task periodically syncs unsynced entries
- Watch uses Watch Connectivity to relay through iPhone when no direct connection

**Phase 2 (Optional):** CloudKit integration

- Add CloudKit as sync layer for better offline/conflict handling
- API polls or receives webhooks from CloudKit
- Enables sync even when app isn’t running

-----

## Data Model

### LogEntry

```swift
// Swift
struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date           // When the event occurred
    let recordedAt: Date          // When the entry was created
    let source: String            // "watch", "iphone", "mac", "drafts", "shortcut"
    let deviceId: String          // Unique device identifier
    
    var category: String?         // "mood", "work", "location", "health", "note"
    var data: LogData
    
    // Local-only
    var synced: Bool = false
}

struct LogData: Codable {
    var text: String?
    var metric: Metric?
    var location: Location?
    var tags: [String]?
    // Note: imageURL and extra fields deferred to post-MVP
}

struct Metric: Codable {
    let name: String              // "mood", "energy", "focus", "pain"
    let value: Double             // Numeric value
    var unit: String?             // Optional unit label
    var scaleMin: Double?         // e.g., 1
    var scaleMax: Double?         // e.g., 10

    enum CodingKeys: String, CodingKey {
        case name, value, unit
        case scaleMin = "scale_min"
        case scaleMax = "scale_max"
    }
}

struct Location: Codable {
    let latitude: Double
    let longitude: Double
    var accuracy: Double?
    var altitude: Double?
    var placeName: String?        // Reverse geocoded or manual
}
```

```typescript
// TypeScript (API) - MVP version
interface LogEntry {
  id: string;                     // UUID
  timestamp: string;              // ISO 8601
  recorded_at: string;            // ISO 8601
  source: string;
  device_id: string;
  category?: string;
  data: {
    text?: string;
    metric?: {
      name: string;
      value: number;
      unit?: string;
      scale_min?: number;
      scale_max?: number;
    };
    location?: {
      latitude: number;
      longitude: number;
      accuracy?: number;
      altitude?: number;
      place_name?: string;
    };
    tags?: string[];
    // Note: image_url and extensible fields deferred to post-MVP
  };
}
```

### Common Categories

|Category  |Typical Use             |Common Metrics                            |
|----------|------------------------|------------------------------------------|
|`mood`    |Emotional state tracking|mood (1-10), energy (1-10), anxiety (1-10)|
|`work`    |Time/task logging       |focus (1-10), or just text notes          |
|`location`|Automatic check-ins     |location data, place_name                 |
|`health`  |Symptoms, medications   |pain (1-10), custom metrics               |
|`note`    |Freeform journaling     |text, tags                                |

-----

## Val Town Backend

### File Structure

```
val-town/
├── schema.sql              # SQLite schema
├── api.ts                  # Main HTTP handler
├── db.ts                   # Database helpers
├── auth.ts                 # API key validation
├── types.ts                # TypeScript interfaces
└── dashboard.html          # Simple HTML dashboard
```

### SQLite Schema

```sql
-- schema.sql
CREATE TABLE IF NOT EXISTS entries (
    id TEXT PRIMARY KEY,
    timestamp TEXT NOT NULL,          -- ISO 8601
    recorded_at TEXT NOT NULL,        -- ISO 8601
    source TEXT NOT NULL,
    device_id TEXT NOT NULL,
    category TEXT,
    data TEXT NOT NULL,               -- JSON blob
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_timestamp ON entries(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_category ON entries(category);
CREATE INDEX IF NOT EXISTS idx_source ON entries(source);

CREATE TABLE IF NOT EXISTS api_keys (
    key_hash TEXT PRIMARY KEY,        -- SHA-256 of the key
    name TEXT NOT NULL,               -- "iPhone", "Watch", "Drafts"
    created_at TEXT DEFAULT (datetime('now')),
    last_used TEXT
);

-- For future: image storage references
CREATE TABLE IF NOT EXISTS images (
    id TEXT PRIMARY KEY,
    entry_id TEXT REFERENCES entries(id),
    url TEXT NOT NULL,                -- Blob storage URL
    thumbnail_url TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);
```

### API Endpoints

```
POST   /api/entries              Create one or more entries (batch supported)
GET    /api/entries              List entries (with filters)
GET    /api/entries/:id          Get single entry
PUT    /api/entries/:id          Update entry
DELETE /api/entries/:id          Delete entry

GET    /api/entries/stats        Aggregations for dashboard
GET    /api/export               Export all data (JSON or CSV)

GET    /dashboard                HTML dashboard
```

#### Query Parameters for GET /api/entries

|Param     |Type    |Description                  |
|----------|--------|-----------------------------|
|`since`   |ISO 8601|Entries after this timestamp |
|`until`   |ISO 8601|Entries before this timestamp|
|`category`|string  |Filter by category           |
|`source`  |string  |Filter by source             |
|`tag`     |string  |Filter by tag (in data.tags) |
|`search`  |string  |Full-text search in data.text|
|`limit`   |number  |Max results (default 100)    |
|`offset`  |number  |Pagination offset            |

#### Authentication

Simple API key in header:

```
Authorization: Bearer <api-key>
```

Generate keys through the dashboard or a setup script. Keys are stored as SHA-256 hashes.

### Example Val Town Implementation

```typescript
// api.ts
import { Hono } from "npm:hono";
import { cors } from "npm:hono/cors";
import { sqlite } from "https://esm.town/v/std/sqlite";

const app = new Hono();

app.use("/*", cors());
app.use("/api/*", authMiddleware);

// Create entries (supports batch)
app.post("/api/entries", async (c) => {
  const body = await c.req.json();
  const entries = Array.isArray(body) ? body : [body];
  
  const stmt = `
    INSERT INTO entries (id, timestamp, recorded_at, source, device_id, category, data)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `;
  
  for (const entry of entries) {
    await sqlite.execute(stmt, [
      entry.id,
      entry.timestamp,
      entry.recorded_at,
      entry.source,
      entry.device_id,
      entry.category || null,
      JSON.stringify(entry.data)
    ]);
  }
  
  return c.json({ created: entries.length });
});

// List entries with filters
app.get("/api/entries", async (c) => {
  const { since, until, category, source, limit = "100", offset = "0" } = c.req.query();
  
  let query = "SELECT * FROM entries WHERE 1=1";
  const params: any[] = [];
  
  if (since) {
    query += " AND timestamp >= ?";
    params.push(since);
  }
  if (until) {
    query += " AND timestamp <= ?";
    params.push(until);
  }
  if (category) {
    query += " AND category = ?";
    params.push(category);
  }
  if (source) {
    query += " AND source = ?";
    params.push(source);
  }
  
  query += " ORDER BY timestamp DESC LIMIT ? OFFSET ?";
  params.push(parseInt(limit), parseInt(offset));
  
  const results = await sqlite.execute(query, params);
  const entries = results.rows.map(row => ({
    ...row,
    data: JSON.parse(row.data as string)
  }));
  
  return c.json(entries);
});

export default app.fetch;
```

-----

## Swift Apps

### Project Structure

```
LifeLog/
├── LifeLogKit/                    # Shared Swift Package
│   ├── Sources/
│   │   ├── Models/
│   │   │   ├── LogEntry.swift
│   │   │   ├── LogData.swift
│   │   │   └── Metric.swift
│   │   ├── Persistence/
│   │   │   ├── PersistenceController.swift
│   │   │   └── SyncManager.swift
│   │   ├── API/
│   │   │   ├── APIClient.swift
│   │   │   └── APIConfiguration.swift
│   │   └── Utilities/
│   │       ├── LocationManager.swift
│   │       └── DeviceIdentifier.swift
│   └── Package.swift
│
├── LifeLog/                       # iOS/iPadOS/macOS app
│   ├── App/
│   │   └── LifeLogApp.swift
│   ├── Views/
│   │   ├── Timeline/
│   │   │   ├── TimelineView.swift
│   │   │   └── EntryRow.swift
│   │   ├── Entry/
│   │   │   ├── NewEntryView.swift
│   │   │   ├── MoodEntryView.swift
│   │   │   └── NoteEntryView.swift
│   │   ├── Dashboard/
│   │   │   └── DashboardView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   ├── Extensions/
│   └── Resources/
│
├── LifeLogWatch/                  # watchOS app
│   ├── App/
│   │   └── LifeLogWatchApp.swift
│   ├── Views/
│   │   ├── QuickLogView.swift     # Main interaction
│   │   ├── MoodSliderView.swift
│   │   └── ComplicationViews.swift
│   ├── Complications/
│   │   └── ComplicationController.swift
│   └── WatchConnectivity/
│       └── WatchSessionManager.swift
│
└── LifeLog.xcodeproj
```

### LifeLogKit Core Components

#### APIClient.swift

```swift
import Foundation

public actor APIClient {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    
    public init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = URLSession.shared
    }
    
    public func createEntries(_ entries: [LogEntry]) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/entries"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.iso8601.encode(entries)
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw APIError.requestFailed
        }
    }
    
    public func fetchEntries(since: Date? = nil, category: String? = nil) async throws -> [LogEntry] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/entries"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []
        
        if let since {
            queryItems.append(URLQueryItem(name: "since", value: ISO8601DateFormatter().string(from: since)))
        }
        if let category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder.iso8601.decode([LogEntry].self, from: data)
    }
}
```

#### SyncManager.swift

```swift
import Foundation
import SwiftData

@Observable
public class SyncManager {
    private let apiClient: APIClient
    private let modelContainer: ModelContainer
    
    public var isSyncing = false
    public var lastSyncDate: Date?
    
    public init(apiClient: APIClient, modelContainer: ModelContainer) {
        self.apiClient = apiClient
        self.modelContainer = modelContainer
    }
    
    @MainActor
    public func syncUnsyncedEntries() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<LogEntryModel>(
            predicate: #Predicate { !$0.synced }
        )
        
        do {
            let unsynced = try context.fetch(descriptor)
            guard !unsynced.isEmpty else { return }
            
            let entries = unsynced.map { $0.toLogEntry() }
            try await apiClient.createEntries(entries)
            
            // Mark as synced
            for model in unsynced {
                model.synced = true
            }
            try context.save()
            
            lastSyncDate = Date()
        } catch {
            print("Sync failed: \(error)")
        }
    }
}
```

#### LocationManager.swift

```swift
import CoreLocation
import Combine

public class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    
    @Published public var currentLocation: CLLocation?
    @Published public var authorizationStatus: CLAuthorizationStatus
    
    public override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    public func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    public func requestCurrentLocation() {
        manager.requestLocation()
    }
    
    public func locationData() -> Location? {
        guard let loc = currentLocation else { return nil }
        return Location(
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            accuracy: loc.horizontalAccuracy,
            altitude: loc.altitude
        )
    }
}

extension LocationManager: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}
```

### Watch App Specifics

#### QuickLogView.swift

```swift
import SwiftUI

struct QuickLogView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var moodValue: Double = 5
    @State private var energyValue: Double = 5
    @State private var showingConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Mood slider
                VStack(alignment: .leading) {
                    Text("Mood")
                        .font(.caption)
                    Slider(value: $moodValue, in: 1...10, step: 1)
                    Text("\(Int(moodValue))")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                }
                
                // Energy slider
                VStack(alignment: .leading) {
                    Text("Energy")
                        .font(.caption)
                    Slider(value: $energyValue, in: 1...10, step: 1)
                    Text("\(Int(energyValue))")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                }
                
                // Quick log button
                Button("Log") {
                    logMood()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("Quick Log")
        .sensoryFeedback(.success, trigger: showingConfirmation)
    }
    
    private func logMood() {
        let entry = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: "watch",
            deviceId: DeviceInfo.identifier,
            category: "mood",
            data: LogData(
                text: "Energy: \(Int(energyValue))",  // MVP: store energy in text
                metric: Metric(
                    name: "mood",
                    value: moodValue,
                    scaleMin: 1,
                    scaleMax: 10
                ),
                tags: ["quick-log"]
            )
        )

        modelContext.insert(entry)

        showingConfirmation = true

        // Trigger sync via Watch Connectivity
        WatchSessionManager.shared.requestSync()
    }
}
```

#### QuickLogWidget.swift (WidgetKit Complication)

```swift
import WidgetKit
import SwiftUI

struct QuickLogWidget: Widget {
    let kind: String = "QuickLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickLogProvider()) { entry in
            QuickLogWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Log")
        .description("Tap to quickly log your mood")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

struct QuickLogEntry: TimelineEntry {
    let date: Date
}

struct QuickLogProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickLogEntry {
        QuickLogEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickLogEntry) -> ()) {
        completion(QuickLogEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLogEntry>) -> ()) {
        let entry = QuickLogEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct QuickLogWidgetView: View {
    let entry: QuickLogEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .widgetAccentable()
        }
    }
}
```

#### WatchSessionManager.swift

```swift
import WatchConnectivity

class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()
    
    private var session: WCSession?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    func requestSync() {
        guard let session, session.isReachable else {
            // Queue for later
            return
        }
        
        session.sendMessage(["action": "sync"], replyHandler: nil)
    }
    
    func sendEntry(_ entry: LogEntry) {
        guard let session else { return }
        
        do {
            let data = try JSONEncoder.iso8601.encode(entry)
            
            if session.isReachable {
                session.sendMessageData(data, replyHandler: nil)
            } else {
                // Transfer in background
                try session.updateApplicationContext(["pendingEntry": data])
            }
        } catch {
            print("Failed to send entry: \(error)")
        }
    }
}

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Watch session activated: \(activationState.rawValue)")
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        // Handle received entry from watch
        // Decode and save to local store, trigger sync
    }
}
```

### iPhone/iPad/Mac App Views

#### TimelineView.swift

```swift
import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LogEntryModel.timestamp, order: .reverse) private var entries: [LogEntryModel]
    
    @State private var selectedCategory: String?
    @State private var showingNewEntry = false
    
    var filteredEntries: [LogEntryModel] {
        guard let category = selectedCategory else { return entries }
        return entries.filter { $0.category == category }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByDay, id: \.0) { day, dayEntries in
                    Section(day.formatted(date: .abbreviated, time: .omitted)) {
                        ForEach(dayEntries) { entry in
                            EntryRow(entry: entry)
                        }
                    }
                }
            }
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Button("All") { selectedCategory = nil }
                        Divider()
                        ForEach(categories, id: \.self) { cat in
                            Button(cat.capitalized) { selectedCategory = cat }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                NewEntryView()
            }
        }
    }
    
    private var groupedByDay: [(Date, [LogEntryModel])] {
        Dictionary(grouping: filteredEntries) { entry in
            Calendar.current.startOfDay(for: entry.timestamp)
        }
        .sorted { $0.key > $1.key }
    }
    
    private var categories: [String] {
        Set(entries.compactMap(\.category)).sorted()
    }
}
```

#### NewEntryView.swift

```swift
import SwiftUI

struct NewEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var entryType: EntryType = .mood
    @State private var text = ""
    @State private var moodValue: Double = 5
    @State private var includeLocation = true
    @State private var tags: [String] = []
    
    @StateObject private var locationManager = LocationManager()
    
    enum EntryType: String, CaseIterable {
        case mood = "Mood"
        case note = "Note"
        case work = "Work"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $entryType) {
                    ForEach(EntryType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                
                switch entryType {
                case .mood:
                    moodSection
                case .note:
                    noteSection
                case .work:
                    workSection
                }
                
                Section {
                    Toggle("Include Location", isOn: $includeLocation)
                }
                
                Section("Tags") {
                    TagEditor(tags: $tags)
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEntry() }
                }
            }
        }
        .onAppear {
            if includeLocation {
                locationManager.requestCurrentLocation()
            }
        }
    }
    
    @ViewBuilder
    private var moodSection: some View {
        Section {
            VStack {
                Text("Mood: \(Int(moodValue))")
                    .font(.headline)
                Slider(value: $moodValue, in: 1...10, step: 1)
            }
            
            TextField("Notes (optional)", text: $text, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    @ViewBuilder
    private var noteSection: some View {
        Section {
            TextField("What's on your mind?", text: $text, axis: .vertical)
                .lineLimit(5...15)
        }
    }
    
    @ViewBuilder
    private var workSection: some View {
        Section {
            TextField("What are you working on?", text: $text, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    private func saveEntry() {
        var data = LogData()
        data.text = text.isEmpty ? nil : text
        data.tags = tags.isEmpty ? nil : tags
        
        if includeLocation {
            data.location = locationManager.locationData()
        }
        
        if entryType == .mood {
            data.metric = Metric(
                name: "mood",
                value: moodValue,
                scaleMin: 1,
                scaleMax: 10
            )
        }
        
        let entry = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: DeviceInfo.source,
            deviceId: DeviceInfo.identifier,
            category: entryType.rawValue.lowercased(),
            data: data
        )

        modelContext.insert(entry)
        dismiss()
    }
}
```

-----

## External Integrations

### Drafts Action

```javascript
// Drafts Action: Log to LifeLog
const apiURL = "https://YOUR_VAL_TOWN_URL/api/entries";
const apiKey = "YOUR_API_KEY"; // Store in Drafts credentials

const entry = {
  id: UUID.make(),
  timestamp: new Date().toISOString(),
  recorded_at: new Date().toISOString(),
  source: "drafts",
  device_id: device.model,
  category: draft.tags.length > 0 ? draft.tags[0] : "note",
  data: {
    text: draft.content,
    tags: draft.tags
  }
};

const http = HTTP.create();
const response = http.request({
  url: apiURL,
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Authorization": `Bearer ${apiKey}`
  },
  data: entry
});

if (response.success) {
  app.displaySuccessMessage("Logged!");
} else {
  app.displayErrorMessage("Failed to log");
  context.fail();
}
```

### Apple Shortcuts

Create shortcuts that:

1. **Quick Mood Log** — Prompt for 1-10 rating, POST to API
1. **Voice Note** — Dictate text, POST as note
1. **Location Check-in** — Get current location, POST with place name

### Obsidian Plugin (future)

- Daily note integration: parse structured entries from daily notes
- Or: dedicated command to log from Obsidian

-----

## Development Phases

### Phase 1: Foundation (MVP)

**Goal:** Complete end-to-end flow: Watch → iPhone → Val Town → Timeline

**Estimated scope:** True MVP with Watch, iPhone, and backend

#### Backend (Val Town)
- [ ] Set up Val Town project
  - [ ] Create new Val
  - [ ] Set up SQLite schema (simplified MVP version)
  - [ ] Configure environment variable for API key
- [ ] Implement API endpoints
  - [ ] POST /api/entries (create, with batch support)
  - [ ] GET /api/entries (list with basic filters)
  - [ ] GET /api/entries/:id (single entry)
  - [ ] Auth middleware (bearer token)
- [ ] Testing
  - [ ] Test script for endpoints
  - [ ] Verify CORS configuration
  - [ ] Test with curl/Postman

#### LifeLogKit (Shared Swift Package)
- [ ] Project setup
  - [ ] Create Swift Package with proper structure
  - [ ] Set up unit test target
  - [ ] Configure for iOS 17+ and watchOS 10+
- [ ] Models layer
  - [ ] LogEntry (API model - Codable struct)
  - [ ] LogData, Metric, Location (API models)
  - [ ] LogEntryModel (SwiftData @Model class)
  - [ ] Conversion extensions (LogEntry ↔ LogEntryModel)
  - [ ] Unit tests (100% coverage for encoding/decoding)
- [ ] Utilities
  - [ ] DeviceInfo (source + identifier)
  - [ ] ISO8601 date formatters
  - [ ] KeychainHelper
  - [ ] AppGroup constants
- [ ] API Client
  - [ ] APIClient actor
  - [ ] createEntries (POST)
  - [ ] fetchEntries (GET)
  - [ ] Error handling (LifeLogError enum)
  - [ ] Unit tests with mocked URLSession
- [ ] Persistence
  - [ ] PersistenceController (SwiftData container)
  - [ ] App Group configuration
  - [ ] Schema migration support
- [ ] Sync
  - [ ] SyncManager (@Observable class)
  - [ ] syncUnsyncedEntries logic
  - [ ] Background sync scheduling (BGTaskScheduler)
  - [ ] Unit tests with mocked API

#### iPhone App
- [ ] Project setup
  - [ ] Create Xcode project (iOS + watchOS targets)
  - [ ] Add LifeLogKit package dependency
  - [ ] Configure App Group entitlements
  - [ ] Set up SwiftData container
- [ ] Settings & Onboarding
  - [ ] SettingsView (API URL, API key input)
  - [ ] First launch flow
  - [ ] Keychain storage for API key
- [ ] Timeline
  - [ ] TimelineView (list entries, grouped by day)
  - [ ] EntryRow component
  - [ ] Pull to refresh → sync
  - [ ] Category filter menu
- [ ] New Entry
  - [ ] NewEntryView (mood slider + optional note)
  - [ ] Save to SwiftData
  - [ ] Trigger immediate sync
  - [ ] Success feedback
- [ ] App lifecycle
  - [ ] BGTaskScheduler registration
  - [ ] Sync on launch
  - [ ] Watch Connectivity session setup
- [ ] Watch Connectivity (iPhone side)
  - [ ] Receive entries from Watch
  - [ ] Save to SwiftData
  - [ ] Trigger sync

#### Watch App
- [ ] Project setup
  - [ ] Configure watchOS target
  - [ ] Add LifeLogKit dependency
  - [ ] Share App Group with iPhone
- [ ] Quick Log
  - [ ] QuickLogView (mood slider)
  - [ ] Save to local SwiftData
  - [ ] Send to iPhone via Watch Connectivity
  - [ ] Haptic feedback on save
- [ ] Widget/Complication
  - [ ] WidgetKit extension target
  - [ ] AccessoryCircular widget
  - [ ] Deep link to QuickLogView
- [ ] Watch Connectivity (Watch side)
  - [ ] WCSession setup
  - [ ] Send message when reachable
  - [ ] Application context for offline

#### Testing & Polish
- [ ] End-to-end testing
  - [ ] Watch log → appears on iPhone → syncs to API
  - [ ] iPhone log → syncs to API
  - [ ] Offline queue → sync when online
  - [ ] Fetch from API → populates timeline
- [ ] UI polish
  - [ ] Loading states
  - [ ] Error alerts
  - [ ] Empty states
  - [ ] Accessibility labels
- [ ] Documentation
  - [ ] README with setup instructions
  - [ ] API documentation
  - [ ] Code comments for complex logic

### Phase 2: Watch + Location

**Goal:** Minimal-friction logging from Watch, automatic location

- [ ] Watch app
  - [ ] Quick mood log view
  - [ ] Complication for instant access
  - [ ] Watch Connectivity sync to phone
- [ ] Location features
  - [ ] Optional location on all entries
  - [ ] Background location tracking (configurable)
  - [ ] Reverse geocoding for place names
- [ ] iPhone improvements
  - [ ] Dashboard view (charts, streaks)
  - [ ] Search/filter entries

### Phase 3: Integrations + Polish

**Goal:** Connect external tools, improve UX

- [ ] Drafts action
- [ ] Apple Shortcuts examples
- [ ] iPad + Mac apps (mostly layout work)
- [ ] Export/backup functionality
- [ ] Dashboard improvements (web)
- [ ] Widgets (iOS, macOS)

### Phase 4: Advanced (Optional)

- [ ] CloudKit sync layer
- [ ] Image attachments
- [ ] HealthKit integration (automatic workout logs)
- [ ] Obsidian plugin
- [ ] Siri intents

-----

## Configuration

### Environment Variables (Val Town)

```
LIFELOG_API_KEYS=key1_hash,key2_hash  # SHA-256 hashes of valid keys
```

### App Configuration

Store in Keychain:

- `apiBaseURL`: URL to Val Town endpoint
- `apiKey`: User’s API key

-----

## Testing Strategy

### Unit Tests

- Model encoding/decoding
- API client request formation
- Sync logic (mock API)

### Integration Tests

- Round-trip: create entry → sync → fetch → verify
- Offline queue → sync when online

### Manual Testing

- Watch complication tap → log → appears on phone → syncs to server
- Drafts action → entry appears in timeline

-----

## Technical Decisions

### MVP Scope

**True MVP Definition:** The minimal version that demonstrates the complete flow:
- Watch app → log mood → sync through iPhone → Val Town backend → view in timeline

**Included in MVP:**
- Val Town backend with SQLite (POST/GET entries, simple auth)
- iPhone app (timeline view, basic new entry form, settings)
- Watch app (quick mood log with complication)
- Watch Connectivity for sync relay
- SwiftData local persistence with sync queue

**Explicitly Excluded from MVP:**
- Web dashboard (API only for now)
- iPad/Mac apps (use iPhone app via Catalyst if needed)
- Drafts/Shortcuts integrations
- Background location tracking
- Image attachments
- Export functionality
- Charts/analytics
- Multiple metric types (mood only for MVP)

### Data Model Decisions

#### 1. Metric Scale Representation

**Decision:** Use `scale_min` and `scale_max` in JSON for compatibility

```swift
// Swift
struct Metric: Codable {
    let name: String
    let value: Double
    var unit: String?
    var scaleMin: Double?
    var scaleMax: Double?

    enum CodingKeys: String, CodingKey {
        case name, value, unit
        case scaleMin = "scale_min"
        case scaleMax = "scale_max"
    }
}
```

**Rationale:** JSON doesn't have a native range type. Min/max is universal and works across all platforms.

#### 2. Extensible Data Field

**Decision:** Skip the `extra` field in MVP, add when needed

```swift
// MVP version - simplified
struct LogData: Codable {
    var text: String?
    var metric: Metric?
    var location: Location?
    var tags: [String]?
    // Skip imageURL and extra for MVP
}
```

**Rationale:**
- AnyCodable adds complexity (requires third-party package or custom implementation)
- MVP doesn't need extensibility yet
- Can add later as `[String: String]` or proper AnyCodable when requirements are clear

#### 3. Watch Energy + Mood Handling

**Decision:** Single entry with mood metric, store energy in text note

```swift
// QuickLogView creates one entry:
let entry = LogEntryModel(
    category: "mood",
    data: LogData(
        text: "Energy: \(Int(energyValue))",  // Simple approach for MVP
        metric: Metric(name: "mood", value: moodValue, scaleMin: 1, scaleMax: 10)
    )
)
```

**Post-MVP:** Add support for multiple metrics per entry when needed.

### Swift Architecture

#### 4. Model Layer Separation

**Decision:** Two-layer model architecture

```
┌─────────────────────────────────────────────────┐
│ LogEntry (struct, Codable)                      │
│ - API transfer object                           │
│ - Immutable, value semantics                    │
│ - JSON encoding/decoding                        │
└─────────────────────────────────────────────────┘
                    ↕
         Conversion Methods
                    ↕
┌─────────────────────────────────────────────────┐
│ LogEntryModel (class, @Model)                   │
│ - SwiftData persistence                         │
│ - Mutable, reference semantics                  │
│ - Includes synced flag                          │
└─────────────────────────────────────────────────┘
```

**Rationale:**
- Separation of concerns: API vs persistence
- SwiftData models need reference semantics (@Model requires class)
- API models benefit from value semantics (struct)
- Clear conversion boundary

#### 5. Device Identification

**Decision:** Create `DeviceInfo` utility

```swift
enum DeviceInfo {
    static var source: String {
        #if os(watchOS)
        return "watch"
        #elseif os(macOS)
        return "mac"
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        #endif
    }

    static var identifier: String {
        #if os(watchOS)
        return WKInterfaceDevice.current().identifierForVendor?.uuidString ?? "unknown-watch"
        #elseif os(macOS)
        // Use IOPlatformUUID or generate stable ID
        return "mac-\(UUID())"  // TODO: Make stable across launches
        #else
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios"
        #endif
    }
}
```

### Backend Decisions

#### 6. Val Town Framework & Implementation

**Decision:** Use Hono framework with Val Town's SQLite

**Rationale:**
- Hono is lightweight, fast, and well-supported on Val Town
- Built-in middleware (CORS, auth)
- Type-safe routing
- Val Town's SQLite is adequate for single-user MVP

**Authentication:**
```typescript
// Simple bearer token approach
// Initial setup: Manually create API key via Val Town secrets
const API_KEY = Deno.env.get("LIFELOG_API_KEY");

function authMiddleware(c, next) {
  const auth = c.req.header("Authorization");
  if (!auth || !auth.startsWith("Bearer ")) {
    return c.json({ error: "Unauthorized" }, 401);
  }
  const token = auth.substring(7);
  if (token !== API_KEY) {
    return c.json({ error: "Invalid token" }, 401);
  }
  return next();
}
```

**For MVP:** Single API key stored in Val Town environment variable. No key generation endpoint.

#### 7. Database Schema Simplification

**Decision:** Defer the `api_keys` and `images` tables to post-MVP

```sql
-- MVP schema
CREATE TABLE IF NOT EXISTS entries (
    id TEXT PRIMARY KEY,
    timestamp TEXT NOT NULL,
    recorded_at TEXT NOT NULL,
    source TEXT NOT NULL,
    device_id TEXT NOT NULL,
    category TEXT,
    data TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_timestamp ON entries(timestamp DESC);
```

**Rationale:** MVP uses single API key from environment variable.

### iOS/watchOS Decisions

#### 8. Widgets & Complications

**Decision:** Use WidgetKit for watchOS 9+ (skip legacy ClockKit)

```swift
// Use WidgetKit with AccessoryCircular family
struct QuickLogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickLog", provider: Provider()) { entry in
            QuickLogWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Log")
        .supportedFamilies([.accessoryCircular])
    }
}
```

**Rationale:**
- Modern API (iOS 16+, watchOS 9+)
- Better performance
- Unified across platforms
- ClockKit is deprecated

**Minimum deployment targets:**
- iOS 17.0 (for latest SwiftData features)
- watchOS 10.0 (for WidgetKit complications)
- macOS 14.0 (post-MVP)

#### 9. Background Sync Strategy

**Decision:** BGTaskScheduler with URLSession background uploads

```swift
// Register background task
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.lifelog.sync",
    using: nil
) { task in
    handleBackgroundSync(task: task as! BGAppRefreshTask)
}

// Schedule opportunistic sync
func scheduleBackgroundSync() {
    let request = BGAppRefreshTaskRequest(identifier: "com.lifelog.sync")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min
    try? BGTaskScheduler.shared.submit(request)
}
```

**Sync frequency:**
- Immediate when online and entry created
- Background task: every 15-60 minutes when app is backgrounded
- On app launch: sync if last sync > 5 minutes ago

**Rationale:**
- BGTaskScheduler is the modern approach (iOS 13+)
- System manages scheduling based on device conditions
- Respects battery and network constraints

#### 10. Watch Connectivity Implementation

**Decision:** Use WCSession with application context for offline queue

**Strategy:**
1. Watch creates entry → saves to local SwiftData
2. If iPhone is reachable → send via `sendMessage` (immediate)
3. If iPhone not reachable → update `applicationContext` (when possible)
4. iPhone receives → saves to its SwiftData → syncs to API

**Rationale:**
- `sendMessage`: Fast, real-time when connected
- `applicationContext`: Guaranteed eventual delivery
- Fallback ensures no data loss

### Testing Strategy

#### 11. Test Coverage Approach

**Decision:** Red-Green-Refactor with pragmatic coverage

**Coverage targets:**
- Models (encoding/decoding): 100%
- API client: 80%+ (mock URLSession)
- Sync logic: 80%+ (mock API)
- UI: Smoke tests only for MVP (test key user paths exist)

**Test structure:**
```
Tests/
├── LifeLogKitTests/
│   ├── Models/
│   │   ├── LogEntryTests.swift
│   │   └── MetricTests.swift
│   ├── API/
│   │   └── APIClientTests.swift
│   └── Sync/
│       └── SyncManagerTests.swift
└── LifeLogUITests/
    └── SmokeTests.swift
```

**TDD workflow per feature:**
1. Write failing test → commit "test: add test for X"
2. Implement → commit "feat: implement X"
3. Refactor → commit "refactor: improve X"

### Deployment & Configuration

#### 12. Val Town Deployment

**Decision:** Single-file deployment for MVP

```typescript
// val-town/lifelog-api.ts
// Contains all backend logic in one val for simplicity
// Can split into modules post-MVP
```

**Rationale:** Val Town works best with single-file vals for simple projects. Can refactor to imports later.

#### 13. API Configuration in Apps

**Decision:** Store in UserDefaults + Keychain

```swift
// UserDefaults: API base URL (not sensitive)
UserDefaults.standard.set("https://username-lifelog.web.val.run", forKey: "apiBaseURL")

// Keychain: API key (sensitive)
KeychainHelper.save(apiKey, service: "com.lifelog.api", account: "apiKey")
```

**Shared between Watch & iPhone:**
- Use App Group for shared UserDefaults
- Use App Group Keychain for shared API key

```swift
// App Group ID
let appGroupID = "group.com.lifelog.shared"
```

### Error Handling

#### 14. Error Handling Pattern

**Decision:** Structured errors with user-facing messages

```swift
enum LifeLogError: LocalizedError {
    case networkUnavailable
    case unauthorized
    case invalidResponse
    case syncFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: return "No internet connection"
        case .unauthorized: return "Invalid API key"
        case .invalidResponse: return "Server error"
        case .syncFailed(let error): return "Sync failed: \(error.localizedDescription)"
        }
    }
}
```

**For MVP:** Simple error alerts. Post-MVP: toast notifications, retry logic.

### Dependencies

#### 15. External Dependencies

**Swift Packages (all official Apple frameworks):**
- SwiftData (persistence)
- WatchConnectivity (watch sync)
- CoreLocation (location)
- WidgetKit (complications)

**No third-party dependencies for MVP.**

**Val Town:**
- Hono (`npm:hono`)
- Val Town standard library (`https://esm.town/v/std/sqlite`)

**Rationale:** Minimize dependencies for MVP. Keep it simple and maintainable.

-----

## Open Questions / Future Decisions

1. **Image storage:** Where to put images? Val Town blob storage? Cloudflare R2? For MVP, skip images.
1. **Conflict resolution:** Last-write-wins is fine for personal use. If entry already exists (same ID), update it.
1. **Metric scales:** Should scales be standardized (always 1-10) or flexible per metric? Start flexible.
1. **Privacy/encryption:** For personal data, might want client-side encryption. Not MVP.
1. **Multiple users:** Single-user for now. Multi-user would need proper auth, user IDs, etc.

-----

## Resources

### Backend
- [Val Town Documentation](https://docs.val.town/)
- [Hono Framework](https://hono.dev/)
- [Val Town SQLite](https://docs.val.town/std/sqlite/)

### Swift & iOS
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [WidgetKit](https://developer.apple.com/documentation/widgetkit)
- [Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity)
- [BGTaskScheduler](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)

### Integrations (Post-MVP)
- [Drafts Scripting](https://docs.getdrafts.com/docs/actions/scripting)
- [Shortcuts User Guide](https://support.apple.com/guide/shortcuts/)
