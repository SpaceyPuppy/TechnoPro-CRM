# TechnoPro CRM — Todo / Notes

## Stage 2 Polish

- [ ] Delete customer button has no loading spinner (isPending disables it but no visual feedback)
- [ ] No success confirmation after adding a note on a ticket
- [ ] Customer select on New Ticket loads max 100 — will break at scale (revisit Stage 6)
- [ ] No 401 interceptor — expired token won't auto-logout (Stage 7)
- [ ] Two tabs open: logout in one, other tab still shows UI until next API call
- [x] Status not refreshing on back navigation — fixed (broadened React Query invalidation)

## Stage 3 — Inventory, Line Items, Invoices, Payments, POS

**Decisions locked:**
- Tax: $0 for now — Stage 6 adds settings-driven GST % (critical for AU businesses)
- Invoice numbers: INV-00001 format, auto-incremented
- Line items added directly to invoice (not to ticket first) for Stage 3
- Partial payments supported
- Invoices can be standalone OR linked to a ticket

## Stage 4 — Ticket Events, Attachments, File Upload, Tech Dashboard

## Stage 5 — Flutter App

## Stage 6 — Configurable Fields, Signatures, Warranties, Deposits, Tags

- [ ] Tax/GST settings — percentage configurable, applied to invoices

## Stage 7 — Reporting, Exports, Audit Logs, Roles Hardening
