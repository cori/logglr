// TypeScript types for LifeLog API
// These match the Swift models defined in the PLAN.md

export interface LogEntry {
  id: string;                     // UUID
  timestamp: string;              // ISO 8601
  recorded_at: string;            // ISO 8601
  source: string;                 // "watch", "iphone", "ipad", "mac"
  device_id: string;              // Device identifier
  category?: string;              // "mood", "work", "location", "health", "note"
  data: LogData;
}

export interface LogData {
  text?: string;
  metric?: Metric;
  location?: Location;
  tags?: string[];
}

export interface Metric {
  name: string;                   // "mood", "energy", "focus", "pain"
  value: number;                  // Numeric value
  unit?: string;                  // Optional unit label
  scale_min?: number;             // e.g., 1
  scale_max?: number;             // e.g., 10
}

export interface Location {
  latitude: number;
  longitude: number;
  accuracy?: number;
  altitude?: number;
  place_name?: string;            // Reverse geocoded or manual
}

// Database row type (includes created_at)
export interface EntryRow {
  id: string;
  timestamp: string;
  recorded_at: string;
  source: string;
  device_id: string;
  category: string | null;
  data: string;                   // JSON stringified LogData
  created_at: string;
}

// API response types
export interface CreateEntriesResponse {
  created: number;
}

export interface ErrorResponse {
  error: string;
}
