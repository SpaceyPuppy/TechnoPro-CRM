# Financial mutation safety

The billing services use database transactions for invoice finalisation, line
item/tax-total recalculation, payment/refund recording, and time billing. They
use integer hundredths (`bigint`) for GST, totals, payments, refunds, and timed
labour calculations; database decimal strings are never converted through
JavaScript floating point for those calculations.

## Retry behaviour

- `POST /invoices/:id/payments` requires an `Idempotency-Key` header. A retry
  with the same key and canonical amount, method, type and reference returns
  the original payment. Reusing a key with changed payment details returns
  `IDEMPOTENCY_CONFLICT` rather than applying a second payment or refund.
- Ticket invoice creation and draft-to-open transition capture stopped,
  billable time entries in one database transaction. Each entry is linked to
  its labour line through `billed_as`, so retries never create a second labour
  line. Once linked to an invoice, the entry's billable flag cannot be changed.
- `POST /time-entries/:id/bill` remains a compatibility endpoint and rejects
  non-billable entries. New clients should use the ticket invoice workflow.

## Remaining non-idempotent endpoints

`POST /invoices` and `POST /tickets` (including automatic repair invoice
creation) do not yet accept caller idempotency keys. Mobile clients must not
blindly retry those creation requests after an unknown timeout. Adding durable
creation-request keys is intentionally deferred rather than changing existing
ticket and invoice creation semantics in this verification issue.
