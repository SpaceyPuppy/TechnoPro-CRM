# TechnoPro CRM — Todo / Notes

**Current Stage:** Stage 7 (in progress: 7a–7d complete, 7e WIP)

## Stage 7 — Completed ✅

### UX / Loading States ✅
- [x] Delete customer button has loading spinner (web)
- [x] Success toast after adding note on ticket (already existed)

### UI Scrolling & Layout ✅
- [x] Flutter: AlwaysScrollableScrollPhysics for Windows mouse wheel
- [x] Web: Scroll containers for ticket detail history, customer detail tickets table
- [x] Settings screens fully scrollable (Flutter + Web)

### Feature Parity ✅
- [x] Flutter: Customer delete with confirmation dialog
- [x] Flutter: Inventory delete with confirmation dialog
- [x] Flutter: Customer search (name/email/phone)
- [x] Web: Ticket search (ticket # or summary)
- [x] Flutter: Ticket search (ticket # or summary)

### Web Settings Module ✅
- [x] Business Settings page (name, ABN, address, phone, email, GST rate, invoice notes)
- [x] Device Models CRUD (add/edit/delete, grouped by manufacturer)
- [x] Settings hub page

### Web Finance Hub (Quotes) ✅
- [x] Tabbed Finance page (Invoices + Quotes)
- [x] Quote status actions (Draft → Sent → Accept/Decline → Convert to Ticket)
- [x] Quote detail view with lifecycle
- [x] Quote creation (InvoiceCreatePage with type selector)

## Stage 7 — In Progress 🔄

### Auth & Security
- [x] 401 interceptor on web (web/src/api/client.ts — catches 401, auto-logout, redirect)
- [ ] Two-tab sync via localStorage listener (web pending)
- [ ] Flutter: 401 interceptor in Dio client (pending)

## Stage 7 — Deferred (Low Priority)

### Bulk Data Import
- [ ] CSV/XLSX import: device models, customers, inventory
- [ ] CSV export functionality

### Backend/Data
- [ ] Audit logs (user, action, timestamp, resource ID)
- [ ] Drift SQLite offline sync (Flutter)

### Roles Hardening
- [ ] RBAC audit and enforcement
- [ ] UI role-based action hiding (tech/counter roles)

## Historical Notes

### Stage 3 Decisions (Locked)
- Tax: $0 for now — Stage 6 added settings-driven GST % (critical for AU businesses) ✓
- Invoice numbers: INV-00001 format, auto-incremented ✓
- Partial payments supported ✓
- Invoices can be standalone OR linked to a ticket ✓

### Stage 6 (Complete)
- [x] Visual overhaul — dark sidebar, theme, chips, stat tiles
- [x] GST + business settings (app_settings table, backend routes, Flutter settings screen)
- [x] PDF invoices + quotes (pdf + printing packages)
- [x] Quotes — Finance hub (/finance), tabbed Invoices/Quotes, quote status actions, convert-to-ticket
- [x] Deposits — payment type toggle (Deposit/Payment/Refund), grouped payments display
