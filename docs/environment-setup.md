# Environment Setup

## Prerequisites

- **Node.js** >= 22.x LTS ([download](https://nodejs.org/))
- **Docker Desktop** — for local MySQL (`choco install docker-desktop -y`, restart after install)
- **Git**
- **Flutter SDK** >= 3.x ([install](https://docs.flutter.dev/get-started/install)) — for Stage 5+ native app development
- **Android Studio** — for Android emulator and tooling (Flutter plugin)
- **Visual Studio** with C++ desktop workload — for Windows Flutter builds

## New Machine Setup (step by step)

```bash
# 1. Clone the repo
git clone <repo-url>
cd TechnoPro-CRM

# 2. Install all workspace dependencies from root
npm install

# 3. Set up environment files
cp backend/.env.example backend/.env
cp web/.env.example web/.env

# 4. Edit backend/.env — set these values:
#    DB_PASSWORD=technopro_dev
#    JWT_SECRET=<any-random-string>
#    (all other defaults are correct for Docker setup)

# 5. Start MySQL + phpMyAdmin via Docker
docker compose up -d
# Wait ~15 seconds for MySQL to be healthy

# 6. Push schema to database
npm run db:push --workspace=backend

# 7. Seed test users and core data
npm run seed --workspace=backend

# 8. Seed procurement test data (Suppliers, POs)
npm run seed:procurement --workspace=backend

# 9. Start the backend
npm run backend:dev
```

## Test Users (created by seed script)

| Email                    | Role       | Password   |
|--------------------------|------------|------------|
| admin@technopro.local    | admin      | admin123   |
| manager@technopro.local  | manager    | manager123 |
| tech1@technopro.local    | technician | tech123    |
| counter@technopro.local  | counter    | counter123 |

## Verify Everything Works

```bash
# Health check
curl http://localhost:3000/api/v1/health

# Login (PowerShell — use single quotes for JSON)
curl -X POST http://localhost:3000/api/v1/auth/login -H "Content-Type: application/json" -d '{"email":"admin@technopro.local","password":"admin123"}'
```

## Local URLs

- **Backend API:** http://localhost:3000
- **phpMyAdmin:** http://localhost:8080 (root / technopro_dev)
- **Web app:** http://localhost:5173 (Stage 2+)

## Running Locally

```bash
# From project root:

# Start backend API server (port 3000)
npm run backend:dev

# Start web dev server (port 5173)
npm run web:dev
```

## Linting & Formatting

```bash
# Check for issues
npm run lint

# Auto-fix issues
npm run lint:fix

# Format all files
npm run format
```

## Testing

```bash
# Run backend tests
npm test --workspace=backend

# Run web tests
npm test --workspace=web
```

## Docker Commands

```bash
# Start MySQL + phpMyAdmin
docker compose up -d

# Stop (keeps data)
docker compose down

# Stop and delete data (full reset)
docker compose down -v

# After a full reset, re-push schema and re-seed:
npm run db:push --workspace=backend
npm run seed --workspace=backend
```

## Cross-Machine Sync

Everything needed to develop is in the repo:
- Tooling config: `biome.json`, `tsconfig.json` files, `package.json` workspaces
- Environment templates: `.env.example` files (copy to `.env` on each machine)
- Architecture context: `CLAUDE.md`, `docs/`
- Docker: `docker-compose.yml` for identical MySQL setup everywhere

The only local setup needed per machine:
1. Install Node.js >= 20 and Docker Desktop
2. `npm install`
3. Copy `.env.example` → `.env` and set `DB_PASSWORD=technopro_dev` + `JWT_SECRET`
4. `docker compose up -d`
5. `npm run db:push --workspace=backend`
6. `npm run seed --workspace=backend`
7. (Stage 5+) Install Flutter SDK, run `flutter pub get` in `flutter/`

## Known Issues

- **PowerShell curl:** Use single quotes for JSON bodies, not escaped double quotes
- **drizzle-kit audit warnings:** 4 moderate vulnerabilities in esbuild (dev tooling only, not production) — upstream issue, safe to ignore
