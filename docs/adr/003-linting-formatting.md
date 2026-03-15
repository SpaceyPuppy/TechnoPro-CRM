# ADR 003: Linting & Formatting — Biome

## Status
Accepted

## Context
Needed a linting and formatting solution for TypeScript across backend and web. Options considered: ESLint + Prettier, Biome.

## Decision
Use **Biome** as a single tool for both linting and formatting.

## Trade-offs
- Biome has fewer rules than ESLint (~200 vs ~300+) and a smaller plugin ecosystem
- Biome is significantly faster (Rust-based) and requires only one config file
- If we hit a gap in rule coverage, we can add individual ESLint rules alongside Biome

## Consequences
- Single `biome.json` at project root — no `.eslintrc`, `.prettierrc`, or compatibility plugins
- Consistent formatting and linting across all TypeScript workspaces
- Security rules enabled (e.g., `noDangerouslySetInnerHtml: error`)
