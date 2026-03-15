# ADR 004: Testing Framework — Vitest

## Status
Accepted

## Context
Needed a testing framework for backend services and web components. Options considered: Jest, Vitest.

## Decision
Use **Vitest** for all TypeScript testing.

## Trade-offs
- Jest has a larger ecosystem and more community examples
- Vitest shares Vite's transform pipeline (already used for web), so TypeScript works out of the box with no extra config
- Vitest API is Jest-compatible (`describe`, `it`, `expect`), so migration either direction is low-cost
- Vitest is noticeably faster for test runs

## Consequences
- One testing framework across backend, web, and shared packages
- No need for ts-jest, SWC transforms, or separate TypeScript test configuration
- Tests run with `vitest run` (CI) or `vitest` (watch mode)
