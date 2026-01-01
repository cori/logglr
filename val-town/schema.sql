-- LifeLog SQLite Schema (MVP version)
-- Simplified schema for single-user personal logging

CREATE TABLE IF NOT EXISTS entries (
    id TEXT PRIMARY KEY,
    timestamp TEXT NOT NULL,
    recorded_at TEXT NOT NULL,
    source TEXT NOT NULL,
    device_id TEXT NOT NULL,
    category TEXT,
    data TEXT NOT NULL,               -- JSON blob
    created_at TEXT DEFAULT (datetime('now'))
);

-- Index for chronological queries (most common access pattern)
CREATE INDEX IF NOT EXISTS idx_timestamp ON entries(timestamp DESC);

-- Index for category filtering
CREATE INDEX IF NOT EXISTS idx_category ON entries(category) WHERE category IS NOT NULL;

-- Index for source filtering (useful for debugging device-specific issues)
CREATE INDEX IF NOT EXISTS idx_source ON entries(source);
