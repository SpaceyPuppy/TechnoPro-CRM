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
- `POST /time-entries/:id/bill` is idempotent by the time-entry row. The
  transaction locks that row; once `billed_as` is set, later requests return
  the existing invoice and never create another labour line.

## Remaining non-idempotent endpoints

`POST /invoices` and `POST /tickets` (including automatic repair invoice
creation) do not yet accept caller idempotency keys. Mobile clients must not
blindly retry those creation requests after an unknown timeout. Adding durable
creation-request keys is intentionally deferred rather than changing existing
ticket and invoice creation semantics in this verification issue.
