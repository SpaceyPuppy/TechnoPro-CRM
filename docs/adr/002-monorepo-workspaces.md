# ADR 002: Monorepo with npm Workspaces

## Status
Accepted

## Context
Backend and web frontend share TypeScript types for API payloads, enums, and constants. Needed to decide between fully separate projects vs a monorepo with shared code.

## Decision
Use **npm workspaces** with three workspaces:
- `backend/` — Express API
- `web/` — React SPA
- `packages/shared/` — Shared types, enums, constants

Android remains independent (Kotlin, separate build system).

## Trade-offs
- Slightly more root-level config than separate repos
- Shared types propagate changes to both consumers immediately — this is a feature, but requires care
- npm workspaces are simpler than pnpm/yarn workspaces but sufficient for our needs

## Consequences
- API contract types defined once in `@technopro/shared`, consumed by both backend and web
- Single `npm install` at root sets up everything
- White-label ready: shared package can carry tenant-agnostic contracts
