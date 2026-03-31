# TechnoPro CRM — Todo / Notes

**Current Stage:** Stage 7 (Interface polish, scrolling fixes, bulk import, 401 interceptor, audit logs)

## Stage 2 Polish (Deferred)

- [ ] Delete customer button has no loading spinner (isPending disables it but no visual feedback)
- [ ] No success confirmation after adding a note on a ticket
- [ ] Customer select on New Ticket loads max 100 — will break at scale
- [x] Status not refreshing on back navigation — fixed (broadened React Query invalidation)

## Stage 7 — Priority Issues

### UX / Loading States
- [ ] Delete customer button has no loading spinner (isPending disables it but no visual feedback)
- [ ] No success toast after adding a note on a ticket

### UI Scrolling & Layout
- [ ] Settings - Business Settings overflows on mobile (not scrollable), text fields too narrow
- [ ] Device models list is not scrollable
- [ ] Customer modal view not scrollable
- [ ] Ticket modal view not scrollable
- [ ] Audit all modal and overflow-prone views for scroll handling

### Interface Polish
- [ ] Dashboard looks good — refine other screens to match quality level
- [ ] General UX/UI polish across all screens

### Bulk Data Import
- [ ] CSV/XLSX import for device models (bulk add, not one-by-one)
- [ ] CSV/XLSX import for customers
- [ ] CSV/XLSX import for inventory items
- [ ] Possibly CSV export for same entities (like most CRM/POS tools)

### Auth & Security
- [ ] 401 interceptor — auto-logout when token expires
- [ ] Two tabs issue: logout in one tab, other tab still shows UI until next API call
- [ ] Review roles hardening (Stage 7 original goal)

### Backend/Data
- [ ] Audit logs (basic: user, action, timestamp, resource ID)
- [ ] Consider offline sync (Drift SQLite) for Flutter — was deferred from Stage 6

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
