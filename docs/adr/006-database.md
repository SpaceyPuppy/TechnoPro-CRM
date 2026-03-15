# ADR 006: Database — MySQL

## Status
Accepted

## Context
Needed a relational database for the CRM. Options considered: PostgreSQL, MySQL/MariaDB.

## Decision
Use **MySQL** as the primary database.

## Rationale
- Available on virtually all hosting platforms including cPanel shared hosting
- The team has prior production experience with MySQL (mysql2 driver)
- Suitable for white-label deployments where clients may have constrained hosting environments
- PostgreSQL's advanced features (JSONB, native UUIDs, arrays) are not required for this domain

## Trade-offs
- UUIDs stored as `CHAR(36)` or `BINARY(16)` instead of native UUID type
- Weaker JSON querying compared to PostgreSQL's JSONB
- No native enum types with the same flexibility as Postgres (using application-level enums instead)

## Consequences
- Drizzle ORM configured with `mysql2` driver
- UUID generation handled in application code
- Schema designed with MySQL-compatible types
- Deployable on cPanel, VPS, and cloud platforms without database compatibility issues
