# TechnoPro CRM

Internal CRM and point-of-sale system for a tech repair shop. Three clients share one backend API.

---

## Repo structure

```
backend/           Node.js API server (Fastify + Drizzle ORM)
web/               React SPA — admin/management (desktop browser)
flutter/           Flutter app — tickets, intake, POS, photos (Android, Windows, iOS, macOS)
packages/shared/   Shared TypeScript types and enums (npm workspace)
docs/              Architecture, API docs, ADRs
```

---

## Tech stack

### Backend (`backend/`)

| Concern | Choice |
|---|---|
| Runtime | Node.js (ESM, TypeScript via `tsx`) |
| Framework | Fastify 5 |
| ORM | Drizzle ORM |
| Database | MySQL 8 |
| Auth | JWT (`@fastify/jwt`) + bcryptjs |
| File uploads | `@fastify/multipart` |
| Security | `@fastify/helmet`, `@fastify/cors`, `@fastify/rate-limit` |
| IDs | UUID v4, stored as `CHAR(36)` |

### Web frontend (`web/`)

| Concern | Choice |
|---|---|
| Framework | React 19 + React Router v7 |
| State | Zustand (auth, persisted) + TanStack Query v5 (server state) |
| Forms | react-hook-form + Zod |
| UI | Tailwind v4, shadcn-style components (Radix UI + CVA) |
| Icons | Lucide React |
| Notifications | Sonner |
| Build | Vite |

### Flutter app (`flutter/`)

| Concern | Choice |
|---|---|
| State | Riverpod 2 (+ riverpod_generator) |
| Navigation | go_router |
| HTTP | Dio 5 (interceptors for auth + 401 handling) |
| Local storage | drift_flutter (SQLite, offline cache) + flutter_secure_storage |
| Camera / files | camera, image_picker, file_picker |
| PDF | pdf + printing |
| Offline detection | connectivity_plus |
| Targets | Android, Windows, iOS, macOS (single codebase) |

### Shared types (`packages/shared/`)

Published as the internal npm package `@technopro/shared`. Contains all API request/response interfaces and enums consumed by both `backend/` and `web/`.

---

## Database schema

13 tables managed by Drizzle ORM migrations.

| Table | Description |
|---|---|
| `users` | Staff accounts — roles: `technician`, `counter`, `manager`, `admin` |
| `customers` | Customer records (name, email, phone, notes) |
| `devices` | Customer devices (brand, model, IMEI, serial, password/pattern lock) |
| `device_models` | Lookup table of known device models (manufacturer + name, used in intake) |
| `tickets` | Repair jobs — linked to customer + optional device; status, priority, due date |
| `ticket_events` | Immutable audit log of notes, status changes, assignments per ticket |
| `ticket_attachments` | File attachments (photos, documents) linked to tickets |
| `time_entries` | Labour time tracking per ticket; start/stop timer, hourly rate snapshot |
| `inventory_items` | Parts/products — SKU, price, cost, optional stock quantity |
| `invoices` | Invoices and quotes — `type: invoice|quote`, status lifecycle, GST |
| `line_items` | Individual items on an invoice (labour `service` or part) |
| `payments` | Payments against an invoice — cash, card, EFTPOS, bank transfer; type: `deposit|payment|refund` |
| `app_settings` | Key/value store for business details, GST rate, invoice notes, labour rate |

---

## API

REST JSON API. All endpoints under `/api/v1/`. Every response is wrapped:

```json
{ "data": { ... } }
```

Paginated responses:

```json
{
  "data": [ ... ],
  "pagination": { "page": 1, "pageSize": 20, "totalCount": 42, "totalPages": 3 }
}
```

Errors:

```json
{ "error": { "code": "NOT_FOUND", "message": "Customer not found" } }
```

### Authentication

`POST /api/v1/auth/login` → `{ token, user }`. All subsequent requests require `Authorization: Bearer <token>`.

### Roles and permissions

| Role | Permissions |
|---|---|
| `technician` | Read everything; create/update tickets; start/stop/bill time entries |
| `counter` | + Create invoices, line items, payments |
| `manager` | + Delete customers/inventory; manage settings, device models; void invoices; import CSV |
| `admin` | Full access |

RBAC enforced server-side via `requireRole()` on each route.

### Endpoints summary

| Resource | Endpoints |
|---|---|
| Auth | `POST /auth/login` |
| Users | `GET /users`, `GET /users/:id`, `POST /users`, `PATCH /users/:id` |
| Customers | `GET/POST /customers`, `GET/PATCH/DELETE /customers/:id`, `POST /customers/import` |
| Devices | `GET/POST /devices`, `GET/PATCH/DELETE /devices/:id` |
| Tickets | `GET/POST /tickets`, `GET/PATCH /tickets/:id`, events, attachments |
| Time entries | `POST /tickets/:id/time-entries/start`, `POST /time-entries/:id/stop`, `/bill` |
| Inventory | `GET/POST /inventory`, `GET/PATCH/DELETE /inventory/:id`, `POST /inventory/import` |
| Invoices | `GET/POST /invoices`, `GET /invoices/:id`, status, quote-status, convert-to-ticket, line items, payments |
| Settings | `GET/PATCH /settings`, device models CRUD + `POST /settings/device-models/import` |
| Dashboard | `GET /dashboard/stats` |
| Health | `GET /health` |

---

## Development setup

**Prerequisites:** Node 20+, Docker Desktop, Flutter SDK (for mobile/desktop builds).

```bash
# 1. Install dependencies
npm install

# 2. Configure environment
cp backend/.env.example backend/.env
# Set DB_PASSWORD=technopro_dev and a JWT_SECRET

# 3. Start MySQL
docker compose up -d

# 4. Push schema + seed
npm run db:push --workspace=backend
npm run seed --workspace=backend

# 5. Start backend
npm run backend:dev

# 6. Start web
npm run web:dev
```

Verify: `curl http://localhost:3000/api/v1/health`

### Test credentials

| Role | Email | Password |
|---|---|---|
| Admin | admin@technopro.local | admin123 |
| Manager | manager@technopro.local | manager123 |
| Technician | tech1@technopro.local | tech123 |
| Counter | counter@technopro.local | counter123 |

### Flutter

```bash
cd flutter
flutter pub get
flutter run -d windows   # or android, etc.
```

See `docs/environment-setup.md` for full Flutter toolchain setup (Android SDK, VS Build Tools + ATL component for Windows).

---

## Key conventions

- All monetary values stored and transmitted as `DECIMAL` strings (`"149.99"`) — no floating point
- UUIDs stored as `CHAR(36)` for readability in logs
- Offline-capable Flutter app: Drift SQLite cache, write queue for mutations, FK rewriting on sync
- PDF invoices/quotes generated client-side in Flutter using bundled Inter fonts
- No secrets in code — environment variables only (see `backend/.env.example`)
