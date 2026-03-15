# ADR 005: Web Framework — Fastify

## Status
Accepted

## Context
Needed a Node.js HTTP framework for the API server. Options considered: Express, Fastify.

## Decision
Use **Fastify** over Express.

## Rationale
- Built-in JSON Schema validation reduces security boilerplate and ensures input is validated before handlers execute
- Async error handling is safe by default — no risk of unhandled promise rejections leaking
- Plugin encapsulation keeps the codebase modular and supports tenant-scoped contexts for future white-labelling
- First-class TypeScript support with typed routes and request/reply objects
- ~3x performance headroom over Express

## Trade-offs
- Smaller community and fewer Stack Overflow answers than Express
- Some middleware packages need Fastify-specific wrappers
- Slightly different mental model (plugins vs flat middleware chain)

## Consequences
- Auth, CORS, rate limiting, helmet implemented as Fastify plugins
- Route validation defined inline via JSON Schema — no separate validation middleware needed
- Backend folder structure uses `plugins/` instead of `middleware/`
