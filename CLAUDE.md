# TechnoPro CRM + POS

## Project

Internal CRM + POS for a tech repair shop. Four components:

- **Backend API** — Node.js, TypeScript, Fastify, MySQL, Drizzle ORM
- **Web frontend** — React, TypeScript, Vite (desktop browser admin/management)
- **Flutter app** — Dart, single codebase for Android, Windows, iOS, macOS (operational/field use)

Web app = full admin, reporting, management views on desktop browsers.
Flutter app = tickets, intake, POS, photos, signatures, offline-capable — touch-optimised for tablets and touchscreen devices.

All clients share one backend API and auth system.

## Repo Structure

```
backend/           — Fastify API server (npm workspace)
web/               — React SPA (npm workspace)
packages/shared/   — Shared types, enums, constants (npm workspace)
flutter/           — Flutter app: Android, Windows, iOS, macOS (independent)
docs/              — Architecture, API docs, ADRs
```

## Domain Entities

User (roles: technician, counter, manager, admin), Customer, Device, Ticket, TicketEvent, TicketAttachment, InventoryItem, LineItem, Invoice, Payment, Settings.

## Security — CRITICAL

This system handles sensitive customer and business data. Security is non-negotiable:

- **No secrets in code or git** — all credentials, keys, and connection strings via environment variables only
- **No `.env` files committed** — only `.env.example` with placeholder values
- **Input validation at every API boundary** — never trust client input
- **Parameterised queries only** — no string concatenation in SQL (Drizzle handles this, but be explicit in any raw queries)
- **Auth on every endpoint** — no unprotected routes except health check
- **Role-based access control enforced server-side** — never rely on client-side role checks alone
- **No sensitive data in logs** — sanitise before logging
- **Dependency auditing** — run `npm audit` regularly, no known vulnerable packages
- **CORS, rate limiting, helmet headers** — configured from Stage 1
- **File uploads validated** — type, size, and content checks before storage
- Claude must flag any code that could introduce OWASP Top 10 vulnerabilities and fix immediately

## Coding Conventions

- Clean, idiomatic TypeScript/Dart with clear separation of concerns
- Type definitions/interfaces for all API payloads
- Comments only for non-obvious logic
- No secrets or credentials in code — use environment variables
- Migrations for all schema changes
- Minimal tests for core logic

## Tooling Decisions

- **Package manager:** npm (familiar, cross-platform; can migrate to pnpm later if needed)
- **Monorepo:** npm workspaces — backend/, web/, packages/shared/ as workspaces
- **Web framework:** Fastify (built-in validation, typed routes, plugin encapsulation, async-safe)
- **Database:** MySQL (universal hosting support including cPanel, white-label friendly)
- **ORM:** Drizzle ORM (type-safe, pure TypeScript — no binary dependencies, SQL-like syntax)
- **Linting/formatting:** Biome (single tool, fast, minimal config)
- **Testing:** Vitest (Vite-native, fast, Jest-compatible API)
- **Native apps:** Flutter/Dart — single codebase for Android, Windows, iOS, macOS with offline sync via local SQLite
- **Local dev:** Docker Compose for MySQL + phpMyAdmin (consistent across machines)
- **Password hashing:** bcryptjs (pure JS, no native bindings — portable to all hosts)
- **IDs:** UUIDs as CHAR(36) in MySQL (readable in queries/logs)
- **Docs:** Markdown + Mermaid diagrams, ADRs for architectural decisions

## Developer Machines

Chris develops on four Windows machines. At the start of each session, ask which machine he's on and tailor advice accordingly (e.g. whether Flutter is installed, whether the dev environment needs any setup).

| Machine | Node/Web env | Flutter | Notes |
|---------|-------------|---------|-------|
| Desktop (home) | Set up 2026-03-15 | Not installed | Main dev machine |
| ThinkPad | Set up 2026-03-15 | Not installed | |
| HP Spectre | Unknown | Not installed | |
| Microsoft Surface | Unknown | Not installed | |

Update this table as each machine gets set up.

## Stage Plan

| Stage | Focus | Status |
|-------|-------|--------|
| 0 | Setup, repo structure, tooling, architecture docs | Complete |
| 1 | DB schema, migrations, auth, customer/ticket CRUD, health check | Complete |
| 2 | Web MVP — login, customer pages, ticket pages | Complete |
| 3 | Inventory, line items, invoices, payments, POS basics | Complete |
| 4 | Ticket events, attachments, file upload, tech dashboard, email hooks | Complete |
| 5 | Flutter app — login, tickets, photo capture, tablet UI (Android + Windows) | Not started |
| 6 | Configurable fields, signatures, warranties, deposits, customer tags | Not started |
| 7 | Reporting, exports, audit logs, roles hardening | Not started |

## How to Drive

Tell Claude which stage to work on, e.g. "Start Stage 0" or "Continue Stage 1". Claude will:
1. Restate objectives
2. **Present stack/tool options with pros and cons — discuss and decide together before writing code**
3. Propose/refine structure based on agreed choices
4. Generate code and config
5. Provide migrations, tests, example API calls
6. Summarize changes and how to run locally

## Current State & Resumption Notes

**Last updated:** 2026-03-15
**Last completed stage:** Stage 4
**Next stage:** Stage 5 — Flutter app (login, tickets, photo capture, tablet UI)

### What's done

- **Stage 0 (Complete):** Repo structure, npm workspaces, Biome config, Docker Compose, architecture docs, ADRs for all tooling decisions, environment setup guide.
- **Stage 1 (Complete):** Full backend API is built and verified working:
  - Drizzle schema for all 10 domain entities (users, customers, devices, tickets, ticket_events, ticket_attachments, inventory_items, invoices, payments, line_items)
  - Shared TypeScript types and enums in @technopro/shared
  - Fastify server with plugins: CORS, Helmet, rate limiting, JWT auth, error handler
  - Auth: POST /api/v1/auth/login, GET /api/v1/auth/me (bcryptjs hashing, 12 rounds)
  - Customer CRUD: GET/POST/PATCH/DELETE /api/v1/customers (with search, pagination)
  - Ticket CRUD: GET/POST/PATCH /api/v1/tickets (with status/assignee/customer filters)
  - Ticket events: auto-created on status change, assignment; manual notes via POST /api/v1/tickets/:id/notes
  - Health check: GET /api/v1/health
  - Seed script with 4 test users (admin/manager/technician/counter)
  - Docker Compose for MySQL + phpMyAdmin
  - 11 passing Vitest tests (auth, pagination, ID generation)

### What's next

Stage 2 — Web MVP. Before writing code, Claude should present options and discuss:
- React Router vs TanStack Router
- State management approach (React Query, Zustand, etc.)
- UI component library or headless components vs hand-rolled
- Auth token storage strategy (httpOnly cookies vs localStorage)
- Folder structure for the web app

Stage 2 scope: login page, auth token handling, customer list/detail/create/edit pages, ticket list/detail/create with status updates, error handling, loading states, navigation.

### How to get running on a new machine

See `docs/environment-setup.md` for full step-by-step instructions. Quick version:
1. Clone repo, `npm install`
2. `cp backend/.env.example backend/.env` — set `DB_PASSWORD=technopro_dev` and `JWT_SECRET`
3. `docker compose up -d`
4. `npm run db:push --workspace=backend`
5. `npm run seed --workspace=backend`
6. `npm run backend:dev`
7. Verify: `curl http://localhost:3000/api/v1/health`

### Flutter dev environment setup (required for Stage 5+)

Required on every machine before working on the Flutter app:

**1. Flutter SDK**
- Download latest stable from flutter.dev/docs/get-started/install/windows
- Extract to `C:\flutter` (no spaces in path)
- Add `C:\flutter\bin` to user PATH

**2. Android Studio** (for Android builds + SDK)
- Download from developer.android.com/studio
- During install: enable Android SDK, Android Virtual Device
- After install: `flutter doctor --android-licenses`

**3. Visual Studio 2022** (for Windows desktop builds)
- Community edition is free
- Required workload: **Desktop development with C++**

**4. Scaffold Flutter project** (first time only, from repo root)
```
cd flutter
flutter create --org com.technopro --project-name technopro_crm --platforms android,windows .
```

**5. Install Flutter dependencies**
```
cd flutter
flutter pub get
```

**6. Verify**
```
flutter doctor
```
Green ticks needed for: Flutter, Android toolchain, Windows desktop.

**Device notes:**
- Desktop (home) — Flutter not yet installed (as of 2026-03-16)
- ThinkPad — Flutter not yet installed (as of 2026-03-16)
- HP Spectre — Flutter not yet installed (as of 2026-03-16)
- Microsoft Surface — Flutter not yet installed (as of 2026-03-16)

### Known issues fixed

- Drizzle schema files: removed `.js` extensions from imports (drizzle-kit CJS loader can't resolve them)
- PowerShell curl: use single quotes for JSON bodies, not escaped double quotes
- drizzle-kit audit warnings: 4 moderate esbuild vulnerabilities (dev tooling only, upstream issue, safe to ignore)
