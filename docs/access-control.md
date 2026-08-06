# Access control matrix

Every `/api/v1` route is public only where stated below. All remaining routes
first require a valid staff JWT; hiding an action in Flutter is never an API
authorization boundary.

| Area and routes | Technician | Counter | Manager | Admin |
| --- | --- | --- | --- | --- |
| `GET /health`, `POST /auth/login` | Public | Public | Public | Public |
| `GET /auth/me` | Yes | Yes | Yes | Yes |
| `GET /dashboard/stats` | Yes | Yes | Yes | Yes |
| `GET /customers`, `GET /customers/:id`, `POST /customers`, `PATCH /customers/:id` | Yes | Yes | Yes | Yes |
| `POST /customers/import`, `DELETE /customers/:id` | No | No | Yes | Yes |
| `GET /tickets`, `GET /tickets/:id`, `GET /tickets/:id/events`, `GET /ticket-events` | Yes | Yes | Yes | Yes |
| `POST /tickets`, `PATCH /tickets/:id`, ticket notes and ticket checklist mutations | Yes* | Yes* | Yes | Yes |
| `GET /tickets/:id/attachments`, attachment file download, upload and delete | Yes | Yes | Yes | Yes |
| `GET /time-entries/current`, ticket time-entry list, start, manual entry, stop, billable toggle and legacy bill | Yes | Yes | Yes | Yes |
| `GET /inventory`, `GET /inventory/:id` | Yes | Yes | Yes | Yes |
| Inventory create, update, import and delete | No | No | Yes | Yes |
| `GET /invoices`, `GET /invoices/:id` and all invoice/quote, line-item, payment and refund mutations | No | Yes | Yes | Yes |
| Invoice status changes, quote conversion | No | No | Yes | Yes |
| `GET /users` (active assignment directory) | Yes | Yes | Yes | Yes |
| `GET /users?includeInactive=true`, create and update staff accounts | No | No | No | Yes |
| `GET /settings` (business settings and tax configuration) | No | Yes | Yes | Yes |
| Update business settings; device-model create, update, import and delete | No | No | Yes | Yes |
| `GET /settings/device-models` | Yes | Yes | Yes | Yes |
| All supplier and purchase-order routes, including receiving | No | No | Yes | Yes |

`*` Technicians and counters can make normal operational ticket changes, notes
and checklist updates. A manager or administrator is required to change ticket
assignment, close a ticket, or cancel a ticket. The server accepts only the
defined state transitions; closed and cancelled tickets cannot be reopened by
the current API.

## Intentional exceptions

- All authenticated staff can read customer, ticket, inventory, device-model,
  attachment and active-staff-assignment data because each is required for the
  field-service workflow. The API does not rely on Flutter navigation hiding
  for these decisions.
- Counters can read, but not modify, business settings so invoices and PDFs can
  use the configured business identity and GST rate. Flutter exposes the
  settings screens only to managers and administrators.
- Attachment deletion remains an operational permission for all staff. The
  attachment audit trail records its uploader; expanded immutable audit-event
  coverage is tracked separately in issue #14.
