# API Conventions

## Base URL

All API endpoints are prefixed with `/api/v1`.

## Authentication

- Auth via `Authorization: Bearer <jwt-token>` header
- Login endpoint returns JWT token
- Token contains user ID and role
- Middleware validates token and attaches user to request context

## HTTP Methods

| Method | Use |
|--------|-----|
| GET    | Retrieve resource(s) |
| POST   | Create a new resource |
| PATCH  | Partially update a resource |
| DELETE | Remove a resource |

PUT is avoided — use PATCH for partial updates.

## URL Patterns

```
GET    /api/v1/customers          — List customers
POST   /api/v1/customers          — Create customer
GET    /api/v1/customers/:id      — Get customer by ID
PATCH  /api/v1/customers/:id      — Update customer
DELETE /api/v1/customers/:id      — Delete customer

GET    /api/v1/customers/:id/tickets  — List tickets for a customer (nested resource)

POST   /api/v1/purchase-orders/:id/receive — Perform a state-change action on a resource
```

## Request Bodies

- JSON only (`Content-Type: application/json`)
- File uploads use `multipart/form-data`
- All fields use camelCase

## Response Format

### Success

```json
{
  "data": { ... }
}
```

### Success (list with pagination)

```json
{
  "data": [ ... ],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "totalCount": 85,
    "totalPages": 5
  }
}
```

### Error

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable description",
    "details": [
      { "field": "email", "message": "Invalid email format" }
    ]
  }
}
```

## HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200  | Success |
| 201  | Created |
| 204  | No content (successful delete) |
| 400  | Bad request / validation error |
| 401  | Unauthorized (missing or invalid token) |
| 403  | Forbidden (insufficient role) |
| 404  | Not found |
| 409  | Conflict (duplicate resource) |
| 422  | Unprocessable entity |
| 429  | Rate limited |
| 500  | Internal server error (no sensitive details exposed) |

## Pagination

Query parameters:
- `page` (default: 1)
- `pageSize` (default: 20, max: 100)

## Filtering & Search

Query parameters on list endpoints:
- `search` — free-text search across relevant fields
- `status`, `priority`, etc. — enum filters
- `sortBy` — field name (default varies by resource)
- `sortOrder` — `asc` or `desc` (default: `desc` for dates, `asc` for names)

## Dates

All dates are ISO 8601 in UTC: `2026-03-15T10:30:00.000Z`

## IDs

All entity IDs are UUIDs (v4).
