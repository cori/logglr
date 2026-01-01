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
    var imageURL: URL?
    var tags: [String]?
    var extra: [String: AnyCodable]?  // Extensible payload
}

struct Metric: Codable {
    let name: String              // "mood", "energy", "focus", "pain"
    let value: Double             // Numeric value
    var unit: String?             // Optional unit label
    var scale: ClosedRange<Double>?  // e.g., 1...10
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
// TypeScript (API)
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
    image_url?: string;
    tags?: string[];
    [key: string]: unknown;       // Extensible
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
            deviceId: WKInterfaceDevice.current().identifierForVendor?.uuidString ?? "unknown",
            category: "mood",
            data: LogData(
                metric: Metric(name: "mood", value: moodValue),
                tags: ["quick-log"]
            )
        )
        
        // Also log energy as separate metric in same entry or separate?
        // For now, add to extra data
        entry.data.extra = ["energy": energyValue]
        
        modelContext.insert(entry)
        
        showingConfirmation = true
        
        // Trigger sync via Watch Connectivity
        WatchSessionManager.shared.requestSync()
    }
}
```

#### ComplicationController.swift

```swift
import ClockKit
import SwiftUI

class ComplicationController: NSObject, CLKComplicationDataSource {
    
    func complicationDescriptors() async -> [CLKComplicationDescriptor] {
        [
            CLKComplicationDescriptor(
                identifier: "quickLog",
                displayName: "Quick Log",
                supportedFamilies: [.graphicCircular, .graphicCorner, .modularSmall]
            )
        ]
    }
    
    func currentTimelineEntry(for complication: CLKComplication) async -> CLKComplicationTimelineEntry? {
        let template = makeTemplate(for: complication.family)
        return CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
    }
    
    private func makeTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate {
        switch family {
        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularView(
                ComplicationCircularView()
            )
        default:
            return CLKComplicationTemplateGraphicCircularView(
                ComplicationCircularView()
            )
        }
    }
}

struct ComplicationCircularView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.3))
            Image(systemName: "plus.circle.fill")
                .font(.title2)
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
            data.metric = Metric(name: "mood", value: moodValue)
        }
        
        let entry = LogEntryModel(
            id: UUID(),
            timestamp: Date(),
            recordedAt: Date(),
            source: deviceSource,
            deviceId: deviceIdentifier,
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

**Goal:** Basic logging from iPhone, syncing to Val Town

- [ ] Set up Val Town backend
  - [ ] SQLite schema
  - [ ] POST /api/entries endpoint
  - [ ] GET /api/entries endpoint
  - [ ] API key auth
  - [ ] Basic HTML dashboard (list recent entries)
- [ ] Create Xcode project with LifeLogKit package
  - [ ] LogEntry model + SwiftData schema
  - [ ] APIClient
  - [ ] Basic SyncManager
- [ ] iPhone app
  - [ ] Timeline view (list entries)
  - [ ] New entry form (mood, note types)
  - [ ] Settings (API URL, key)
  - [ ] Background sync

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

## Open Questions / Future Decisions

1. **Image storage:** Where to put images? Val Town blob storage? Cloudflare R2? For MVP, skip images.
1. **Conflict resolution:** Last-write-wins is fine for personal use. If entry already exists (same ID), update it.
1. **Metric scales:** Should scales be standardized (always 1-10) or flexible per metric? Start flexible.
1. **Privacy/encryption:** For personal data, might want client-side encryption. Not MVP.
1. **Multiple users:** Single-user for now. Multi-user would need proper auth, user IDs, etc.

-----

## Resources

- [Val Town Documentation](https://docs.val.town/)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Watch Connectivity](https://developer.apple.com/documentation/watchconnectivity)
- [ClockKit Complications](https://developer.apple.com/documentation/clockkit)
- [Drafts Scripting](https://docs.getdrafts.com/docs/actions/scripting)
