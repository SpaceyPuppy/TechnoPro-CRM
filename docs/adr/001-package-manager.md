# ADR 001: Package Manager — npm

## Status
Accepted

## Context
Needed a package manager for the Node.js backend and React web frontend. Options considered: npm, pnpm, yarn v4.

## Decision
Use **npm** — it's familiar, cross-platform, and has zero extra setup. The team already uses it on other projects.

## Trade-offs
- npm is slower than pnpm and has weaker dependency isolation (phantom deps possible)
- These limitations are manageable at our current scale
- Migration to pnpm is straightforward if needed later (only lockfile and CI scripts change, no app code affected)

## Consequences
- No additional tooling to install on dev machines
- Workspaces supported natively via npm workspaces
- Will not block white-labelling or scaling
