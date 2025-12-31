# Val.town Template for Claude Code

A template repository for building [Val.town](https://val.town) vals using Claude Code, optimized for Claude Code on the web.

## What is This?

This template provides a development environment and guidelines for building Val.town vals with Claude Code. It includes:

- **Development container** with all necessary tools (Deno, Val CLI, GitHub CLI, Claude Code)
- **Development guidelines** in `claude.md` for best practices and Val.town essentials
- **Pre-configured** for test-driven development and Val.town deployment

## Quick Start

### Using This Template

1. **Create a new repository from this template**
   - Click "Use this template" on GitHub
   - Or: Clone and start building

2. **Open in a dev container**
   - GitHub Codespaces: Click "Code" → "Create codespace"
   - VS Code: "Reopen in Container"
   - Claude Code on web: Will automatically use the devcontainer

3. **Authenticate**
   ```bash
   val login
   gh auth login
   ```

4. **Read the guidelines**
   - See `claude.md` for development philosophy and Val.town essentials

5. **Start building**
   ```bash
   # Create your first val
   mkdir -p src
   # Write code and tests following TDD
   # Deploy when ready
   val deploy src/main.ts
   ```

## What's Included

### Development Container (`.devcontainer/`)

Pre-configured with:
- ✅ **Deno** - Val.town runtime environment
- ✅ **Val CLI** - Deploy and manage vals
- ✅ **GitHub CLI** - Git operations and PR management
- ✅ **Claude Code** - AI-assisted development
- ✅ **VS Code extensions** - Deno support and linting

### Development Guide (`claude.md`)

Comprehensive guide covering:
- Val.town essentials (auth, storage, runtime)
- Development methodology (TDD, commits, documentation)
- Technology choices (no React, mobile-responsive)
- Testing strategy
- Project structure recommendations

## Development Philosophy

This template enforces specific best practices:

### ✅ Red-Green-Refactor (TDD)

1. Write failing test → commit
2. Implement feature → commit
3. Refactor → commit

### ✅ Commit Early and Often

- Separate commits for tests and implementation
- Show your work through git history
- Meaningful commit messages

### ✅ Keep Documentation Updated

- README stays current
- API docs reflect actual endpoints
- Architecture notes match reality

### ❌ No React

Val.town vals should be lightweight. Use:
- Vanilla JS/TS
- Web standards
- HTML templates
- Lightweight libraries (htmx, Alpine.js) if needed

### ✅ Mobile-Responsive

Every interface must work on mobile devices.

## Project Structure

Recommended structure for vals:

```
/
├── .devcontainer/          # Dev environment
├── src/                    # Source code
│   ├── handlers/          # HTTP request handlers
│   ├── lib/               # Business logic
│   ├── utils/             # Utilities
│   └── types/             # TypeScript types
├── tests/                 # Tests (mirrors src/)
├── public/                # Static assets (if needed)
├── claude.md              # Development guide
├── README.md              # This file
├── deno.json              # Deno configuration
└── main.ts                # Entry point
```

## Val.town Essentials

### Authentication

```typescript
import { auth } from "@valtown/sdk";

const user = await auth.user(req);
```

### Storage

```typescript
import { blob, sqlite } from "@valtown/sdk";

// Blob storage
await blob.setJSON("key", { data: "value" });

// SQLite
await sqlite.execute("SELECT * FROM users");
```

### Deployment

```bash
# Deploy a val
val deploy main.ts

# View logs
val logs myval

# List vals
val list
```

## Testing

Use Deno's built-in test runner:

```typescript
import { assertEquals } from "https://deno.land/std/testing/asserts.ts";

Deno.test("my feature", () => {
  assertEquals(myFunction(), expected);
});
```

Run tests:
```bash
deno test
```

## Resources

- **[claude.md](./claude.md)** - Complete development guide
- **[Val.town Docs](https://www.val.town/docs)** - Platform documentation
- **[Deno Manual](https://deno.land/manual)** - Runtime documentation

## Contributing

When using this template:

1. Read `claude.md` thoroughly
2. Follow TDD practices
3. Commit early and often
4. Keep this README updated with project-specific info
5. Ask questions when assumptions are unclear

---

**Remember**: Test first. Commit often. No React. Document everything.
