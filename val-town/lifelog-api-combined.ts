/**
 * LifeLog API - Val Town Backend (Combined Single File)
 *
 * Deploy this file directly to Val Town as an HTTP val.
 *
 * Environment variables required:
 * - LIFELOG_API_KEY: Bearer token for authentication
 *
 * @see README.md for deployment and usage instructions
 */

import { Hono } from "npm:hono@4";
import { cors } from "npm:hono@4/cors";

// ============================================================================
// Types
// ============================================================================

export interface LogEntry {
  id: string;
  timestamp: string;
  recorded_at: string;
  source: string;
  device_id: string;
  category?: string;
  data: LogData;
}

export interface LogData {
  text?: string;
  metric?: Metric;
  location?: Location;
  tags?: string[];
}

export interface Metric {
  name: string;
  value: number;
  unit?: string;
  scale_min?: number;
  scale_max?: number;
}

export interface Location {
  latitude: number;
  longitude: number;
  accuracy?: number;
  altitude?: number;
  place_name?: string;
}

export interface EntryRow {
  id: string;
  timestamp: string;
  recorded_at: string;
  source: string;
  device_id: string;
  category: string | null;
  data: string;
  created_at: string;
}

export interface CreateEntriesResponse {
  created: number;
}

export interface ErrorResponse {
  error: string;
}

// ============================================================================
// Database Setup
// ============================================================================

declare const sqlite: {
  execute: (query: string, params?: any[]) => Promise<{ rows: any[] }>;
};

async function initializeDatabase() {
  const schema = `
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
    CREATE INDEX IF NOT EXISTS idx_category ON entries(category) WHERE category IS NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_source ON entries(source);
  `;

  await sqlite.execute(schema);
}

// ============================================================================
// Application
// ============================================================================

const app = new Hono();

// CORS configuration
app.use("/*", cors());

// Auth middleware
async function authMiddleware(c: any, next: () => Promise<void>) {
  const auth = c.req.header("Authorization");

  if (!auth || !auth.startsWith("Bearer ")) {
    return c.json({ error: "Unauthorized - missing or invalid Authorization header" } as ErrorResponse, 401);
  }

  const token = auth.substring(7);
  const apiKey = Deno.env.get("LIFELOG_API_KEY");

  if (!apiKey) {
    console.error("LIFELOG_API_KEY environment variable not set");
    return c.json({ error: "Server configuration error" } as ErrorResponse, 500);
  }

  if (token !== apiKey) {
    return c.json({ error: "Unauthorized - invalid API key" } as ErrorResponse, 401);
  }

  await next();
}

app.use("/api/*", authMiddleware);

// ============================================================================
// Routes
// ============================================================================

app.get("/", (c) => {
  return c.json({
    name: "LifeLog API",
    version: "1.0.0-mvp",
    endpoints: [
      "POST /api/entries - Create entries",
      "GET /api/entries - List entries",
      "GET /api/entries/:id - Get single entry",
      "GET /health - Health check",
    ],
  });
});

app.get("/health", (c) => {
  return c.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.post("/api/entries", async (c) => {
  try {
    await initializeDatabase();

    const body = await c.req.json();
    const entries: LogEntry[] = Array.isArray(body) ? body : [body];

    for (const entry of entries) {
      if (!entry.id || !entry.timestamp || !entry.recorded_at || !entry.source || !entry.device_id || !entry.data) {
        return c.json({
          error: "Invalid entry: missing required fields (id, timestamp, recorded_at, source, device_id, data)"
        } as ErrorResponse, 400);
      }
    }

    const stmt = `
      INSERT INTO entries (id, timestamp, recorded_at, source, device_id, category, data)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        timestamp = excluded.timestamp,
        recorded_at = excluded.recorded_at,
        source = excluded.source,
        device_id = excluded.device_id,
        category = excluded.category,
        data = excluded.data
    `;

    for (const entry of entries) {
      await sqlite.execute(stmt, [
        entry.id,
        entry.timestamp,
        entry.recorded_at,
        entry.source,
        entry.device_id,
        entry.category || null,
        JSON.stringify(entry.data),
      ]);
    }

    return c.json({ created: entries.length } as CreateEntriesResponse);
  } catch (error) {
    console.error("Error creating entries:", error);
    return c.json({
      error: `Failed to create entries: ${error instanceof Error ? error.message : String(error)}`
    } as ErrorResponse, 500);
  }
});

app.get("/api/entries", async (c) => {
  try {
    await initializeDatabase();

    const { since, until, category, source, limit = "100", offset = "0" } = c.req.query();

    const limitNum = Math.min(parseInt(limit) || 100, 1000);
    const offsetNum = parseInt(offset) || 0;

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
    params.push(limitNum, offsetNum);

    const result = await sqlite.execute(query, params);

    const entries: LogEntry[] = result.rows.map((row: EntryRow) => ({
      id: row.id,
      timestamp: row.timestamp,
      recorded_at: row.recorded_at,
      source: row.source,
      device_id: row.device_id,
      category: row.category || undefined,
      data: JSON.parse(row.data),
    }));

    return c.json(entries);
  } catch (error) {
    console.error("Error fetching entries:", error);
    return c.json({
      error: `Failed to fetch entries: ${error instanceof Error ? error.message : String(error)}`
    } as ErrorResponse, 500);
  }
});

app.get("/api/entries/:id", async (c) => {
  try {
    await initializeDatabase();

    const id = c.req.param("id");

    const result = await sqlite.execute(
      "SELECT * FROM entries WHERE id = ?",
      [id]
    );

    if (result.rows.length === 0) {
      return c.json({ error: "Entry not found" } as ErrorResponse, 404);
    }

    const row = result.rows[0] as EntryRow;
    const entry: LogEntry = {
      id: row.id,
      timestamp: row.timestamp,
      recorded_at: row.recorded_at,
      source: row.source,
      device_id: row.device_id,
      category: row.category || undefined,
      data: JSON.parse(row.data),
    };

    return c.json(entry);
  } catch (error) {
    console.error("Error fetching entry:", error);
    return c.json({
      error: `Failed to fetch entry: ${error instanceof Error ? error.message : String(error)}`
    } as ErrorResponse, 500);
  }
});

// Export the fetch handler for Val Town
export default app.fetch;
