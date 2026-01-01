/**
 * API Test Script for LifeLog
 *
 * Usage:
 *   deno run --allow-net --allow-env tests/api-test.ts <API_URL> <API_KEY>
 *
 * Example:
 *   deno run --allow-net --allow-env tests/api-test.ts https://username-lifelog.web.val.run my-secret-key
 */

import type { LogEntry } from "../val-town/types.ts";

const API_URL = Deno.args[0] || "http://localhost:8000";
const API_KEY = Deno.args[1] || Deno.env.get("LIFELOG_API_KEY") || "";

if (!API_KEY) {
  console.error("❌ Error: API key not provided");
  console.error("Usage: deno run --allow-net --allow-env tests/api-test.ts <API_URL> <API_KEY>");
  Deno.exit(1);
}

const headers = {
  "Content-Type": "application/json",
  "Authorization": `Bearer ${API_KEY}`,
};

interface TestResult {
  name: string;
  passed: boolean;
  error?: string;
}

const results: TestResult[] = [];

function logTest(name: string, passed: boolean, error?: string) {
  results.push({ name, passed, error });
  const icon = passed ? "✅" : "❌";
  console.log(`${icon} ${name}`);
  if (error) {
    console.log(`   Error: ${error}`);
  }
}

async function runTests() {
  console.log("🧪 Testing LifeLog API");
  console.log(`📍 API URL: ${API_URL}`);
  console.log(`🔑 API Key: ${API_KEY.substring(0, 8)}...`);
  console.log();

  // Test 1: Health check
  try {
    const response = await fetch(`${API_URL}/health`);
    const data = await response.json();
    logTest(
      "Health check",
      response.ok && data.status === "ok",
      !response.ok ? `Status ${response.status}` : undefined
    );
  } catch (error) {
    logTest("Health check", false, String(error));
  }

  // Test 2: Root endpoint
  try {
    const response = await fetch(`${API_URL}/`);
    const data = await response.json();
    logTest(
      "Root endpoint",
      response.ok && data.name === "LifeLog API",
      !response.ok ? `Status ${response.status}` : undefined
    );
  } catch (error) {
    logTest("Root endpoint", false, String(error));
  }

  // Test 3: Auth failure (no token)
  try {
    const response = await fetch(`${API_URL}/api/entries`);
    const data = await response.json();
    logTest(
      "Auth failure without token",
      response.status === 401 && data.error,
      response.ok ? "Should have failed with 401" : undefined
    );
  } catch (error) {
    logTest("Auth failure without token", false, String(error));
  }

  // Test 4: Auth failure (invalid token)
  try {
    const response = await fetch(`${API_URL}/api/entries`, {
      headers: { "Authorization": "Bearer invalid-token" },
    });
    const data = await response.json();
    logTest(
      "Auth failure with invalid token",
      response.status === 401 && data.error,
      response.ok ? "Should have failed with 401" : undefined
    );
  } catch (error) {
    logTest("Auth failure with invalid token", false, String(error));
  }

  // Test 5: Create single entry
  const testEntry: LogEntry = {
    id: crypto.randomUUID(),
    timestamp: new Date().toISOString(),
    recorded_at: new Date().toISOString(),
    source: "test-script",
    device_id: "test-device-1",
    category: "mood",
    data: {
      text: "Test entry from API test script",
      metric: {
        name: "mood",
        value: 7,
        scale_min: 1,
        scale_max: 10,
      },
      tags: ["test", "automated"],
    },
  };

  let createdEntryId = "";

  try {
    const response = await fetch(`${API_URL}/api/entries`, {
      method: "POST",
      headers,
      body: JSON.stringify(testEntry),
    });
    const data = await response.json();
    const passed = response.ok && data.created === 1;
    if (passed) createdEntryId = testEntry.id;
    logTest(
      "Create single entry",
      passed,
      !response.ok ? `Status ${response.status}: ${JSON.stringify(data)}` : undefined
    );
  } catch (error) {
    logTest("Create single entry", false, String(error));
  }

  // Test 6: Create batch entries
  const batchEntries: LogEntry[] = [
    {
      id: crypto.randomUUID(),
      timestamp: new Date(Date.now() - 3600000).toISOString(), // 1 hour ago
      recorded_at: new Date().toISOString(),
      source: "test-script",
      device_id: "test-device-1",
      category: "note",
      data: {
        text: "Batch entry 1",
        tags: ["batch", "test"],
      },
    },
    {
      id: crypto.randomUUID(),
      timestamp: new Date(Date.now() - 7200000).toISOString(), // 2 hours ago
      recorded_at: new Date().toISOString(),
      source: "test-script",
      device_id: "test-device-1",
      category: "work",
      data: {
        text: "Batch entry 2",
      },
    },
  ];

  try {
    const response = await fetch(`${API_URL}/api/entries`, {
      method: "POST",
      headers,
      body: JSON.stringify(batchEntries),
    });
    const data = await response.json();
    logTest(
      "Create batch entries",
      response.ok && data.created === 2,
      !response.ok ? `Status ${response.status}: ${JSON.stringify(data)}` : undefined
    );
  } catch (error) {
    logTest("Create batch entries", false, String(error));
  }

  // Test 7: Get all entries
  try {
    const response = await fetch(`${API_URL}/api/entries`, { headers });
    const data = await response.json();
    logTest(
      "Get all entries",
      response.ok && Array.isArray(data) && data.length >= 3,
      !response.ok ? `Status ${response.status}` : undefined
    );
  } catch (error) {
    logTest("Get all entries", false, String(error));
  }

  // Test 8: Get entry by ID
  if (createdEntryId) {
    try {
      const response = await fetch(`${API_URL}/api/entries/${createdEntryId}`, { headers });
      const data = await response.json();
      logTest(
        "Get entry by ID",
        response.ok && data.id === createdEntryId,
        !response.ok ? `Status ${response.status}` : undefined
      );
    } catch (error) {
      logTest("Get entry by ID", false, String(error));
    }
  }

  // Test 9: Get entries with category filter
  try {
    const response = await fetch(`${API_URL}/api/entries?category=mood`, { headers });
    const data = await response.json();
    const allMood = Array.isArray(data) && data.every((e: LogEntry) => e.category === "mood");
    logTest(
      "Filter entries by category",
      response.ok && allMood,
      !response.ok ? `Status ${response.status}` : !allMood ? "Some entries have wrong category" : undefined
    );
  } catch (error) {
    logTest("Filter entries by category", false, String(error));
  }

  // Test 10: Get entries with source filter
  try {
    const response = await fetch(`${API_URL}/api/entries?source=test-script`, { headers });
    const data = await response.json();
    const allTestScript = Array.isArray(data) && data.every((e: LogEntry) => e.source === "test-script");
    logTest(
      "Filter entries by source",
      response.ok && allTestScript && data.length >= 3,
      !response.ok ? `Status ${response.status}` : !allTestScript ? "Some entries have wrong source" : undefined
    );
  } catch (error) {
    logTest("Filter entries by source", false, String(error));
  }

  // Test 11: Get entries with limit
  try {
    const response = await fetch(`${API_URL}/api/entries?limit=2`, { headers });
    const data = await response.json();
    logTest(
      "Limit results",
      response.ok && Array.isArray(data) && data.length === 2,
      !response.ok ? `Status ${response.status}` : undefined
    );
  } catch (error) {
    logTest("Limit results", false, String(error));
  }

  // Test 12: Get entries with time filter
  const oneHourAgo = new Date(Date.now() - 3600000).toISOString();
  try {
    const response = await fetch(`${API_URL}/api/entries?since=${encodeURIComponent(oneHourAgo)}`, { headers });
    const data = await response.json();
    logTest(
      "Filter by time (since)",
      response.ok && Array.isArray(data),
      !response.ok ? `Status ${response.status}` : undefined
    );
  } catch (error) {
    logTest("Filter by time (since)", false, String(error));
  }

  // Test 13: Upsert (create duplicate ID)
  if (createdEntryId) {
    try {
      const updatedEntry = {
        ...testEntry,
        data: {
          ...testEntry.data,
          text: "Updated test entry",
        },
      };

      const response = await fetch(`${API_URL}/api/entries`, {
        method: "POST",
        headers,
        body: JSON.stringify(updatedEntry),
      });
      const data = await response.json();
      logTest(
        "Upsert existing entry",
        response.ok && data.created === 1,
        !response.ok ? `Status ${response.status}: ${JSON.stringify(data)}` : undefined
      );

      // Verify the update
      const getResponse = await fetch(`${API_URL}/api/entries/${createdEntryId}`, { headers });
      const getdata = await getResponse.json();
      const updated = getdata.data.text === "Updated test entry";
      logTest(
        "Verify upsert worked",
        updated,
        !updated ? "Entry was not updated" : undefined
      );
    } catch (error) {
      logTest("Upsert existing entry", false, String(error));
    }
  }

  // Print summary
  console.log();
  console.log("📊 Test Summary");
  console.log("═".repeat(50));

  const passed = results.filter((r) => r.passed).length;
  const failed = results.filter((r) => !r.passed).length;
  const total = results.length;

  console.log(`Total: ${total}`);
  console.log(`✅ Passed: ${passed}`);
  console.log(`❌ Failed: ${failed}`);
  console.log();

  if (failed > 0) {
    console.log("Failed tests:");
    results.filter((r) => !r.passed).forEach((r) => {
      console.log(`  - ${r.name}`);
      if (r.error) console.log(`    ${r.error}`);
    });
    Deno.exit(1);
  } else {
    console.log("🎉 All tests passed!");
    Deno.exit(0);
  }
}

// Run tests
runTests().catch((error) => {
  console.error("❌ Test suite failed:", error);
  Deno.exit(1);
});
