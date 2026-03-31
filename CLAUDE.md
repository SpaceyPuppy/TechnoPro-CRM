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

## Core entities

User (roles: technician, counter, manager, admin), Customer, Device, Ticket, TicketEvent, TicketAttachment, InventoryItem, LineItem, Invoice, Payment, Settings.

## Security — CRITICAL

Customer & business data — security is non-negotiable:

- **No secrets in code/git** — env vars only, `.env.example` only in repo
- **Input validation at all API boundaries** — parameterised queries (Drizzle), never trust client input
- **Auth on every endpoint** — health check exempt only
- **RBAC enforced server-side** — never client-side role checks alone
- **No sensitive data in logs** — sanitise before logging
- **CORS, helmet, rate limiting** — configured from Stage 1
- **File uploads validated** — type, size, content checks before storage
- **Dependency auditing** — run `npm audit` regularly
- **OWASP Top 10:** Claude must flag & fix vulnerabilities immediately

## Coding Conventions

- Idiomatic TypeScript/Dart, clear separation of concerns
- Type definitions for all API payloads
- Comments only for non-obvious logic
- No secrets in code — env vars only
- Migrations for all schema changes
- Minimal tests for core logic

## Tooling Decisions

- **Monorepo:** npm workspaces (backend/, web/, packages/shared/)
- **Backend:** Fastify (typed routes, validation, async-safe), Drizzle ORM (type-safe, pure TS)
- **Database:** MySQL 8 (universal hosting, cPanel)
- **Frontend:** React 19, Tailwind v4, shadcn-style components
- **Native:** Flutter/Dart (single codebase: Android, Windows, iOS, macOS)
- **Dev:** Docker Compose (MySQL + phpMyAdmin), Vitest, Biome
- **Auth:** JWT + bcryptjs, UUIDs as CHAR(36) (readable in logs)
- **Docs:** Markdown + Mermaid, ADRs
- **Windows tools:** Chocolatey for dev tool installation

## Developer Machines

Chris uses four Windows machines. Ask which one at session start.

| Machine | Node/Web | Flutter | Status |
|---------|----------|---------|--------|
| Desktop (home) | ✓ | ✗ | Main dev |
| ThinkPad | ✓ | ✗ | |
| HP Spectre | ? | ✗ | |
| Surface | ✓ | ✓ | All green (2026-03-16) |

## Stage Plan

| Stage | Focus | Status |
|-------|-------|--------|
| 0 | Setup, repo structure, tooling, architecture docs | Complete |
| 1 | DB schema, migrations, auth, customer/ticket CRUD, health check | Complete |
| 2 | Web MVP — login, customer pages, ticket pages | Complete |
| 3 | Inventory, line items, invoices, payments, POS basics | Complete |
| 4 | Ticket events, attachments, file upload, tech dashboard, email hooks | Complete |
| 4.5 | Visual polish — colour scheme, typography, empty states, toasts, skeletons | Complete |
| 5 | Flutter app — login, tickets, customers, inventory, photo capture, tablet UI | Complete |
| 5.5 | Ticket intake form redesign — customer search, device capture, repairs, pattern lock | Complete |
| 6 | Visual overhaul, GST/tax, PDF invoices/quotes, Quotes module, Deposits | Complete |
| 7 | Interface polish, CSV bulk import, scrolling fixes, 401 interceptor, audit logs, roles hardening | Not started |


## Current State

**Updated:** 2026-03-31 | **Completed:** Stage 6 | **Current:** Stage 7

**Surface:** Fully set up (2026-03-16) — Flutter 3.38.5, Docker, Android SDK 36.1.0, VS Build Tools + ATL component. Backend running, DB ready.

### Stages completed (0–6)

- **0–1:** Repo, tooling, backend API (Fastify, Drizzle, auth, MySQL, Docker).
- **2–3:** Web MVP (React, TanStack Query, Tailwind) — customers, tickets, inventory, invoices, line items, payments.
- **4–4.5:** File attachments, dashboard, visual polish (brand colours, Inter font, notifications, skeletons).
- **5–5.5:** Flutter app (Riverpod, go_router, Dio) — tickets, customers, inventory, device capture, camera, signature grid. Ticket intake redesign with device & repair sections. Settings screen (device models, GST).
- **6:** Visual overhaul (dark sidebar), GST/tax settings, PDF invoices/quotes, Quotes module, Deposits.

### Tech stack

**Web:** React 19 + React Router v7, TanStack Query (staleTime 30s), Zustand (persist: `technopro-auth`), Tailwind v4, shadcn-style + CVA + Radix, react-hook-form + zod.

**Flutter:** Riverpod, go_router, Dio + interceptors, camera + file picker, cache-only offline (Drift deferred). UI: bottom nav (mobile) / NavigationRail (tablet/desktop), master-detail on wide screens.

### Known open items (deferred to Stage 7 and later)

- **UX polish:** No loading spinner on customer delete button; no success toast after adding ticket note; customer select capped at 100
- **UI/UX improvements:** Settings - Business Settings overflows on mobile (not scrollable), narrow fields; Device models list not scrollable; Modal views (customer, ticket) need scroll handling; Dashboard polish (other screens need refinement to match quality)
- **Bulk data import:** CSV/XLSX import for device models, customers, inventory — most tools support this for faster setup
- **Auth & security:** No 401 interceptor for auto-logout (expired token in one tab doesn't logout other tabs until next API call)
- **Offline:** Drift SQLite offline sync for Flutter (deferred from Stage 6)
- **Advanced features:** Configurable fields (custom ticket/device fields), audit logs, roles hardening, SMTP email integration

### Test credentials (from seed script)

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@technopro.local | admin123 |
| Manager | manager@technopro.local | manager123 |
| Tech | tech1@technopro.local | tech123 |
| Counter | counter@technopro.local | counter123 |

### Business identity

**Real name:** First Choice Phone Repair. **Logo:** `flutter/assets/image/logo.png` (sidebar, PDFs). **Quotes:** `QTE-00001` format. **SMTP:** Stage 7 (Microsoft 365 first).

### Stage 6 — Complete (6a–6e)

Completed: dark sidebar, GST settings, PDF invoices/quotes, Quotes module (Finance hub, tabbed UI, convert-to-ticket), Deposits (payment type toggle).

**Key decisions:** Quotes extend invoices with `type: invoice | quote`. Quote status: draft → sent → accepted → declined. Quote numbers `QTE-00001`. Dark sidebar: `#0F172A` bg, `#1E3A8A` active, `#93C5FD` text. Mobile nav: 5-slot bottom bar; tablet: full NavigationRail. PDF shares via device email (SMTP deferred to Stage 7).

### Stage 7+ roadmap

- UX polish: delete spinner, success toasts, scroll fixes (Settings, modals, Device models)
- Bulk data import: CSV/XLSX for device models, customers, inventory
- 401 interceptor + auto-logout (two-tab sync)
- Audit logs, roles hardening
- Drift SQLite offline sync for Flutter
- Configurable fields, SMTP integration (Microsoft 365 first)
- Signatures on tickets, warranties on line items, tags on tickets/customers

### Quick setup (new machine)

See `docs/environment-setup.md` for full details.
1. `npm install`
2. `cp backend/.env.example backend/.env` — set `DB_PASSWORD=technopro_dev`, `JWT_SECRET`
3. `docker compose up -d`
4. `npm run db:push --workspace=backend` && `npm run seed --workspace=backend`
5. `npm run backend:dev`
6. Verify: `curl http://localhost:3000/api/v1/health`

### Flutter dev environment setup

See `docs/environment-setup.md` for full steps. Quick: `choco install docker-desktop flutter androidstudio visualstudio2022buildtools -y`, then add ATL component for flutter_secure_storage_windows, then `flutter doctor` (all green needed for Flutter, Android, Windows desktop).

**Device status:** Surface fully set up 2026-03-16 (Flutter 3.38.5, Android SDK 36.1.0, VS Build Tools + ATL). Desktop, ThinkPad, HP Spectre — Flutter not installed yet.

### Known gotchas

- **CORS:** `CORS_ORIGIN` in `backend/.env` must list both `http://localhost:5173` and `http://localhost:5174` (Vite increments if 5173 in use).
- **Drizzle imports:** removed `.js` extensions from schema imports (drizzle-kit CJS loader issue).
- **PowerShell curl:** use single quotes for JSON, not escaped double quotes.
- **mysql2 aggregates:** SUM/MAX return strings — wrap with `Number()` (handled in invoice/dashboard services).
- **drizzle-kit audit:** 4 moderate esbuild vulnerabilities (dev-only, upstream, safe).
