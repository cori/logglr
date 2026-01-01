/**
 * LifeLog API - Val Town Backend
 *
 * A simple HTTP API for personal life logging with support for
 * Watch, iPhone, iPad, and Mac clients.
 *
 * Environment variables required:
 * - LIFELOG_API_KEY: Bearer token for authentication
 */

import { Hono } from "npm:hono@4";
import { cors } from "npm:hono@4/cors";
import type {
  LogEntry,
  CreateEntriesResponse,
  ErrorResponse,
  EntryRow,
} from "./types.ts";

// Initialize Hono app
const app = new Hono();

// CORS configuration - allow all origins for MVP
app.use("/*", cors());

// Database setup
// Note: In Val Town, sqlite is available as a global
// For local development, you'll need to mock this
declare const sqlite: {
  execute: (query: string, params?: any[]) => Promise<{ rows: any[] }>;
};

/**
 * Authentication middleware
 * Validates bearer token against LIFELOG_API_KEY environment variable
 */
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

// Apply auth middleware to all /api/* routes
app.use("/api/*", authMiddleware);

/**
 * Initialize database schema
 * Called automatically on first request
 */
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

/**
 * POST /api/entries
 * Create one or more log entries (batch supported)
 *
 * Request body: LogEntry | LogEntry[]
 * Response: { created: number }
 */
app.post("/api/entries", async (c) => {
  try {
    await initializeDatabase();

    const body = await c.req.json();
    const entries: LogEntry[] = Array.isArray(body) ? body : [body];

    // Validate entries
    for (const entry of entries) {
      if (!entry.id || !entry.timestamp || !entry.recorded_at || !entry.source || !entry.device_id || !entry.data) {
        return c.json({
          error: "Invalid entry: missing required fields (id, timestamp, recorded_at, source, device_id, data)"
        } as ErrorResponse, 400);
      }
    }

    // Insert entries
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

/**
 * GET /api/entries
 * List entries with optional filters
 *
 * Query parameters:
 * - since: ISO 8601 timestamp (entries after this time)
 * - until: ISO 8601 timestamp (entries before this time)
 * - category: Filter by category
 * - source: Filter by source device
 * - limit: Max results (default 100, max 1000)
 * - offset: Pagination offset (default 0)
 */
app.get("/api/entries", async (c) => {
  try {
    await initializeDatabase();

    const { since, until, category, source, limit = "100", offset = "0" } = c.req.query();

    // Validate and parse limit/offset
    const limitNum = Math.min(parseInt(limit) || 100, 1000);
    const offsetNum = parseInt(offset) || 0;

    // Build query
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

    // Parse data JSON in each row
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

/**
 * GET /api/entries/:id
 * Get a single entry by ID
 */
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

/**
 * Health check endpoint
 */
app.get("/health", (c) => {
  return c.json({ status: "ok", timestamp: new Date().toISOString() });
});

/**
 * Root endpoint
 */
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

// Export the fetch handler for Val Town
export default app.fetch;
