# Claude Code Guide for Val.town Development

This repository is a template for building Val.town vals using Claude Code. This guide captures essential knowledge about working with Val.town and establishes development best practices.

## Val.town Essentials

### What is Val.town?

Val.town is a serverless platform for running JavaScript/TypeScript code. Each "val" is a function that can be:
- HTTP endpoints (web servers, APIs, webhooks)
- Scheduled functions (cron jobs)
- Email handlers
- Background jobs

### Val.town Runtime Environment

- **Runtime**: Deno runtime with web-standard APIs
- **CLI Available**: The `val` CLI is available in the development environment
- **Deploy Target**: Code developed here will be deployed as Val.town vals

### Val.town Built-in Features

#### Authentication (@valtown/sdk auth)

Val.town provides built-in authentication utilities:

```typescript
import { auth } from "@valtown/sdk";

// Check if user is authenticated
const user = await auth.user(req);
if (!user) {
  return new Response("Unauthorized", { status: 401 });
}

// Get user information
console.log(user.id, user.username);
```

#### Storage (@valtown/sdk blob and sqlite)

Val.town offers multiple storage options:

**Blob Storage** - For files and binary data:
```typescript
import { blob } from "@valtown/sdk";

// Store data
await blob.setJSON("mykey", { data: "value" });

// Retrieve data
const data = await blob.getJSON("mykey");

// List keys
const keys = await blob.list();

// Delete data
await blob.delete("mykey");
```

**SQLite** - For structured data:
```typescript
import { sqlite } from "@valtown/sdk";

// Execute queries
await sqlite.execute(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    name TEXT,
    email TEXT
  )
`);

// Insert data
await sqlite.execute(
  "INSERT INTO users (name, email) VALUES (?, ?)",
  ["Alice", "alice@example.com"]
);

// Query data
const results = await sqlite.execute("SELECT * FROM users");
```

#### Environment Variables

Access secrets and configuration:
```typescript
// Stored in Val.town settings
const apiKey = Deno.env.get("API_KEY");
```

## Development Philosophy and Methodology

### Red-Green-Refactor (TDD)

We follow test-driven development rigorously:

1. **Red**: Write a failing test first
   - Commit the failing test: `git commit -m "test: add failing test for feature X"`

2. **Green**: Write minimal code to make the test pass
   - Commit the implementation: `git commit -m "feat: implement feature X"`

3. **Refactor**: Improve the code while keeping tests green
   - Commit refactoring: `git commit -m "refactor: improve feature X implementation"`

**Coverage Expectations**:
- **Feature Coverage**: Good - Most user-facing features should have tests
- **Function Coverage**: Reasonable - Core business logic should be tested, not every helper

### Commit Early and Often

Show your work through granular commits:

- ✅ Separate commits for failing tests and implementations
- ✅ Meaningful commit messages following conventional commits
- ✅ Commit after each discrete change
- ❌ Don't bundle multiple features in one commit
- ❌ Don't wait until "everything is perfect"

Example commit flow:
```bash
git commit -m "test: add test for user authentication"
git commit -m "feat: implement user authentication"
git commit -m "test: add test for token expiration"
git commit -m "feat: handle token expiration"
git commit -m "refactor: extract token validation logic"
git commit -m "docs: update README with auth instructions"
```

### Documentation is Living

Keep documentation synchronized with code:

- Update README.md when adding features
- Document API endpoints as you create them
- Update architecture notes when making structural changes
- Remove outdated documentation immediately
- **Never let docs lag behind code**

### Technology Choices

#### ❌ No React

This bears repeating: **Do not use React**.

Val.town vals should be lightweight and framework-free. Use:
- Vanilla JavaScript/TypeScript
- Web standards (fetch, Request, Response)
- HTML templates (template literals, tagged templates)
- CSS (vanilla, no preprocessors unless necessary)
- Progressive enhancement

#### ✅ Use What Makes Sense

Beyond "no React," choose the best tool for the job:
- **TypeScript** for type safety
- **Deno standard library** for utilities
- **Web Components** if you need component architecture
- **htmx** or **Alpine.js** for lightweight interactivity
- **Tailwind CDN** if you want utility CSS (via CDN)

#### Mobile-Responsive Always

Every interface must work well on mobile:
- Use responsive CSS (flexbox, grid, media queries)
- Test on various viewport sizes
- Touch-friendly UI elements
- Performance matters on mobile networks

### Val CLI Architecture

The `val` CLI is available in your development environment:

```bash
# Deploy a val
val deploy myfunction.ts

# List your vals
val list

# Run a val locally
val run myfunction.ts

# Get val logs
val logs myval
```

**Architect accordingly**:
- Develop locally with the val CLI
- Test before deploying
- Use `val` commands in your development workflow
- Understand that your code will run in Val.town's Deno runtime

### Be Prepared, Be Opinionated, Challenge Assumptions

#### Ask Questions Often

- Don't assume requirements are complete
- Clarify ambiguity before coding
- Ask about edge cases
- Question technology choices (even suggesting alternatives)

Examples of good questions:
- "Should unauthenticated users see a login page or a 401?"
- "Do we need pagination for this list, or is the dataset small?"
- "Should we use blob storage or SQLite for this data? SQLite would enable queries."

#### Be Opinionated

You're encouraged to have and share opinions:
- "I recommend SQLite over blob storage here because we'll need to query by date"
- "Let's use a simple HTML form instead of a complex client-side solution"
- "This should be two separate vals - one for the API, one for the cron job"

#### Challenge Unacknowledged Assumptions

Surface hidden assumptions:
- "You mentioned 'users' - are we building multi-user auth or single-user?"
- "This assumes the API always returns data - should we handle empty states?"
- "Are we optimizing for read or write performance?"

## Testing Strategy

### Test Runner

Use Deno's built-in test runner:

```typescript
import { assertEquals } from "https://deno.land/std/testing/asserts.ts";

Deno.test("feature X should do Y", async () => {
  const result = await myFunction();
  assertEquals(result, expectedValue);
});
```

Run tests:
```bash
deno test
```

### What to Test

✅ **Do test**:
- Business logic
- API endpoints (request/response)
- Data transformations
- Authentication flows
- Error handling

❌ **Don't test**:
- Val.town SDK functions (they're tested)
- Third-party libraries
- Trivial getters/setters

### Test Organization

```
/
├── src/
│   ├── handlers/
│   │   └── user.ts
│   └── utils/
│       └── validation.ts
├── tests/
│   ├── handlers/
│   │   └── user.test.ts
│   └── utils/
│       └── validation.test.ts
└── main.ts
```

## Project Structure Recommendations

```
/
├── .devcontainer/          # Dev container configuration
├── src/                    # Source code
│   ├── handlers/          # HTTP handlers
│   ├── lib/               # Business logic
│   ├── utils/             # Utilities
│   └── types/             # TypeScript types
├── tests/                 # Tests (mirrors src/)
├── public/                # Static assets (if needed)
├── claude.md              # This file
├── README.md              # Project documentation
├── deno.json              # Deno configuration
└── main.ts                # Entry point
```

## Quick Start Checklist

When starting a new val project from this template:

- [ ] Read this entire claude.md file
- [ ] Update README.md with project-specific information
- [ ] Set up initial project structure
- [ ] Write your first failing test
- [ ] Implement the feature to pass the test
- [ ] Commit both (separately)
- [ ] Deploy to Val.town using `val deploy`
- [ ] Ask questions about anything unclear
- [ ] Keep documentation updated as you build

## Resources

- [Val.town Documentation](https://www.val.town/docs)
- [Val.town SDK Reference](https://www.val.town/docs/sdk)
- [Deno Manual](https://deno.land/manual)
- [Deno Standard Library](https://deno.land/std)

---

Remember: **No React. Test first. Commit often. Document everything. Ask questions.**
