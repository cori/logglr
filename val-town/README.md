# LifeLog Val Town Backend

The backend API for LifeLog, built for [Val Town](https://val.town) using Hono framework and SQLite.

## Features

- ✅ RESTful API for log entries
- ✅ Bearer token authentication
- ✅ SQLite persistence
- ✅ Batch entry creation
- ✅ Filtering by category, source, and time
- ✅ Automatic upsert on duplicate IDs
- ✅ CORS enabled for all origins

## API Endpoints

### Public Endpoints

- `GET /` - API information
- `GET /health` - Health check

### Authenticated Endpoints

All endpoints under `/api/*` require authentication via Bearer token.

- `POST /api/entries` - Create one or more entries
- `GET /api/entries` - List entries with optional filters
- `GET /api/entries/:id` - Get a single entry by ID

## Deployment to Val Town

### Step 1: Create a New Val

1. Go to [Val Town](https://val.town)
2. Sign in to your account
3. Click "New Val" → "HTTP"
4. Name it `lifelog` (or your preferred name)

### Step 2: Copy the Code

Copy the contents of `api.ts` into your Val.

**Important:** You need to combine the files for Val Town:

```typescript
// Copy types.ts content here first
// Then copy api.ts content
```

Or use the single-file version: `lifelog-combined.ts` (if you create it).

### Step 3: Set Environment Variable

1. In Val Town, go to Settings → Secrets
2. Add a new secret:
   - Name: `LIFELOG_API_KEY`
   - Value: A strong random string (e.g., generate with `openssl rand -base64 32`)

### Step 4: Save and Deploy

1. Click "Save" or "Deploy"
2. Your API will be available at: `https://YOUR_USERNAME-lifelog.web.val.run`

## Testing

### Using the Test Script

```bash
# From the project root
deno run --allow-net --allow-env tests/api-test.ts \
  https://YOUR_USERNAME-lifelog.web.val.run \
  YOUR_API_KEY
```

### Manual Testing with curl

```bash
# Set variables
export API_URL="https://YOUR_USERNAME-lifelog.web.val.run"
export API_KEY="your-secret-key"

# Health check (no auth required)
curl $API_URL/health

# Create an entry
curl -X POST $API_URL/api/entries \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "'$(uuidgen)'",
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "recorded_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "source": "curl",
    "device_id": "test-device",
    "category": "mood",
    "data": {
      "text": "Testing from curl",
      "metric": {
        "name": "mood",
        "value": 8,
        "scale_min": 1,
        "scale_max": 10
      }
    }
  }'

# List all entries
curl $API_URL/api/entries \
  -H "Authorization: Bearer $API_KEY"

# Filter by category
curl "$API_URL/api/entries?category=mood" \
  -H "Authorization: Bearer $API_KEY"
```

## Query Parameters

### `GET /api/entries`

| Parameter  | Type   | Description                    | Example                   |
|------------|--------|--------------------------------|---------------------------|
| `since`    | string | ISO 8601 timestamp             | `2024-01-01T00:00:00Z`    |
| `until`    | string | ISO 8601 timestamp             | `2024-12-31T23:59:59Z`    |
| `category` | string | Filter by category             | `mood`, `work`, `note`    |
| `source`   | string | Filter by source device        | `watch`, `iphone`, `mac`  |
| `limit`    | number | Max results (default 100)      | `50`                      |
| `offset`   | number | Pagination offset (default 0)  | `100`                     |

## Authentication

All `/api/*` endpoints require a Bearer token:

```
Authorization: Bearer YOUR_API_KEY
```

The API key must match the `LIFELOG_API_KEY` environment variable set in Val Town.

## Data Schema

### LogEntry

```typescript
{
  id: string;              // UUID
  timestamp: string;       // ISO 8601
  recorded_at: string;     // ISO 8601
  source: string;          // "watch", "iphone", etc.
  device_id: string;       // Device identifier
  category?: string;       // Optional category
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
  }
}
```

## Database

The API uses SQLite with the following schema:

```sql
CREATE TABLE entries (
  id TEXT PRIMARY KEY,
  timestamp TEXT NOT NULL,
  recorded_at TEXT NOT NULL,
  source TEXT NOT NULL,
  device_id TEXT NOT NULL,
  category TEXT,
  data TEXT NOT NULL,  -- JSON
  created_at TEXT DEFAULT (datetime('now'))
);
```

Indexes:
- `idx_timestamp` - For chronological queries
- `idx_category` - For category filtering
- `idx_source` - For source filtering

## Troubleshooting

### "LIFELOG_API_KEY environment variable not set"

Make sure you've set the secret in Val Town Settings → Secrets.

### "Unauthorized - invalid API key"

Double-check that the API key in your request matches the one set in Val Town.

### CORS errors

The API has CORS enabled for all origins. If you're still seeing CORS errors, check your request method and headers.

## Local Development

To run locally (for development/testing):

```bash
# Install Deno if you haven't already
# https://deno.land/

# Create a local test file
cat > test-local.ts << 'EOF'
import app from "./val-town/api.ts";

// Mock sqlite for local testing
globalThis.sqlite = {
  execute: async (query: string, params?: any[]) => {
    console.log("SQL:", query, params);
    return { rows: [] };
  }
};

Deno.serve({ port: 8000 }, app);
EOF

# Run it
LIFELOG_API_KEY=test-key deno run --allow-net --allow-env test-local.ts
```

Note: Local development requires mocking the `sqlite` global that Val Town provides.

## License

MIT
