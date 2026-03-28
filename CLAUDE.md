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
- **Package manager (Windows):** Chocolatey — installed on all of Chris's machines, use it for installing dev tools

## Developer Machines

Chris develops on four Windows machines. At the start of each session, ask which machine he's on and tailor advice accordingly (e.g. whether Flutter is installed, whether the dev environment needs any setup).

| Machine | Node/Web env | Flutter | Notes |
|---------|-------------|---------|-------|
| Desktop (home) | Set up 2026-03-15 | Not installed | Main dev machine |
| ThinkPad | Set up 2026-03-15 | Not installed | |
| HP Spectre | Unknown | Not installed | |
| Microsoft Surface | Set up 2026-03-16 | Ready 2026-03-16 | Flutter 3.38.5, Docker 29.2.1, Android SDK 36.1.0 — all green. ATL component added manually to VS Build Tools (required by flutter_secure_storage_windows) |

Update this table as each machine gets set up.

## Stage Plan

| Stage | Focus | Status |
|-------|-------|--------|
| 0 | Setup, repo structure, tooling, architecture docs | Complete |
| 1 | DB schema, migrations, auth, customer/ticket CRUD, health check | Complete |
| 2 | Web MVP — login, customer pages, ticket pages | Complete |
| 3 | Inventory, line items, invoices, payments, POS basics | Complete |
| 4 | Ticket events, attachments, file upload, tech dashboard, email hooks | Complete |
| 4.5 | Visual polish — colour scheme, typography, empty states, toasts, skeletons | Complete |
| 5 | Flutter app — login, tickets, customers, inventory, photo capture, tablet UI | In progress |
| 6 | Configurable fields, GST/tax settings, signatures, warranties, deposits, tags | Not started |
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

**Last updated:** 2026-03-28
**Last completed stage:** Stage 4.5 (all committed, verified working)
**Next stage:** Stage 5 — Flutter app (in progress)
**After Stage 5:** Stage 6 — Configurable fields, GST/tax, signatures, warranties, deposits, tags

**Surface fully set up (2026-03-16):** Flutter 3.38.5, Docker 29.2.1, Android SDK 36.1.0, VS 2026 Build Tools — `flutter doctor` all green. ATL component added to VS Build Tools (needed for flutter_secure_storage_windows). Backend running, DB migrated and seeded.

### What's done

- **Stage 0 (Complete):** Repo structure, npm workspaces, Biome config, Docker Compose, architecture docs, ADRs.
- **Stage 1 (Complete):** Full backend API — Drizzle schema, auth, customer/ticket CRUD, health check, seed script, 11 Vitest tests.
- **Stage 2 (Complete):** Web MVP — React 19, React Router v7, TanStack Query, Zustand, Tailwind v4, shadcn-style components. Login, customers, tickets (full CRUD + status + notes + history).
- **Stage 3 (Complete):** Inventory CRUD, invoices (standalone + ticket-linked), line items, payments, auto-status progression (draft→open→paid). INV-00001 sequential numbering.
- **Stage 4 (Complete):** File attachments on tickets (@fastify/multipart + @fastify/static, 10MB, UUID-prefixed filenames). Live dashboard (stats, overdue, revenue, recent activity, "My Tickets" for tech/counter roles). GET /api/v1/users for assignment dropdowns. Assigned To field on ticket forms.
- **Stage 4.5 (Complete):** Visual polish — brand colour scheme, Inter font, toast notifications (sonner), skeleton loading states, empty states across all pages.
- **Stage 5 (In Progress):** Flutter app scaffold complete and building. Login (with token race condition fix), tickets, customers, inventory, invoices/line items/payments all implemented. Adaptive split view (master-detail on wide screens). Three-tier layout (desktop tables vs card lists), touch detection, Inter font. Ticket attachments screen added.

### Tech stack decisions (web)

- **Framework:** React 19 + React Router v7
- **Data fetching:** TanStack Query (staleTime 30s, retry 1)
- **State:** Zustand with persist (localStorage key: `technopro-auth`)
- **Styling:** Tailwind v4 (`@tailwindcss/vite` plugin, `@theme inline` tokens, no config file)
- **Components:** Hand-rolled shadcn-style with CVA + Radix primitives
- **Forms:** react-hook-form + zod

### Tech stack decisions (Flutter — Stage 5)

- **State:** Riverpod
- **Navigation:** go_router (compatible with future offline/Drift layer)
- **HTTP:** Dio with interceptors
- **Offline:** Cache-only for Stage 5, full Drift SQLite sync in Stage 6
- **Camera:** `camera` package (direct preview/control) + file picker fallback on Windows
- **Scope:** Login, Tickets, Customers, Inventory — match web features as closely as possible. Bottom nav (mobile) / NavigationRail (tablet/desktop). Master-detail split view on wide screens.

### Known open items (deferred)

- **Stage 2 polish:** No loading spinner on customer delete button; no success toast after adding ticket note; customer select capped at 100 (revisit Stage 6); no 401 interceptor for auto-logout (Stage 7)
- **Stage 6:** GST/tax % in settings — critical for AU businesses, applied to invoices
- **Stage 6:** Drift SQLite offline sync for Flutter
- **Stage 7:** 401 interceptor, audit logs, roles hardening

### Test credentials (seed script)

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@technopro.local | admin123 |
| Manager | manager@technopro.local | manager123 |
| Technician | tech1@technopro.local | tech123 |
| Counter | counter@technopro.local | counter123 |

### What's next

Stage 5 in progress. Core screens (login, tickets, customers, inventory, invoices) done. Adaptive layouts and desktop table views complete. Remaining Stage 5 work:
- Camera/photo capture on tickets (Android — `camera` package; Windows — file picker fallback)
- Polish: pull-to-refresh, better error messages, empty states per-screen
- Test on physical Android device / Windows desktop
- Offline indicator (UI only for Stage 5; full Drift sync deferred to Stage 6)

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

**1. Flutter SDK + Android Studio + Docker Desktop** (via Chocolatey — preferred)
```
choco install docker-desktop flutter androidstudio -y
```
Reboot after. Then open Android Studio → Settings → SDK Manager → SDK Tools tab → check **Android SDK Command-line Tools** → Apply. Then: `flutter doctor --android-licenses`

**2. Visual Studio C++ workload** (for Windows desktop builds)
- VS 2022 Community: `choco install visualstudio2022community` with workload `Microsoft.VisualStudio.Workload.NativeDesktop`
- Or if VS Build Tools already installed (check `choco list`): add `visualstudio2022-workload-vctools`
- Note: VS 2026 Build Tools also satisfies this requirement (confirmed on Surface)

**3. Add ATL component** (required by flutter_secure_storage_windows — run in elevated PowerShell)
```powershell
& "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools" --add Microsoft.VisualStudio.Component.VC.ATL --quiet --norestart
```
For VS 2022: replace `\18\` with `\2022\`.

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
- Microsoft Surface — Fully set up 2026-03-16, all green

### Known issues / gotchas

- **CORS:** `backend/.env` `CORS_ORIGIN` must list the Vite port. Default is `http://localhost:5173` but if port 5173 is in use Vite increments to 5174 — add both: `CORS_ORIGIN=http://localhost:5173,http://localhost:5174`
- **Drizzle schema files:** removed `.js` extensions from imports (drizzle-kit CJS loader can't resolve them)
- **PowerShell curl:** use single quotes for JSON bodies, not escaped double quotes
- **drizzle-kit audit warnings:** 4 moderate esbuild vulnerabilities — dev tooling only, upstream issue, safe to ignore
- **mysql2 aggregates:** SUM/MAX return as strings in JS — always wrap with `Number()`. Already handled in invoice and dashboard services.
