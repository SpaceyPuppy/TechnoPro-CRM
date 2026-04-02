# TechnoPro CRM — Todo / Notes

**Current Status:** Stage 8 Complete ✅ (Ready for Stage 9)

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

## Stage 7 — Auth & Security ✅

- [x] 401 interceptor on web (web/src/api/client.ts — catches 401, auto-logout, redirect to /login)
- [x] 401 interceptor on Flutter (api_client.dart — clears token, Dio error handler)
- [ ] Two-tab localStorage sync (web) — deferred, low priority

## Stage 8 — Procurement & Supply Chain ✅

### 1. Drizzle Schema & Shared Interfaces ✅
- [x] Define `suppliers` table schema (vendor details, lead times, account numbers)
- [x] Define `purchase_orders` table schema (expected deliveries, status)
- [x] Define `po_items` table schema 
- [x] Create Shared TypeScript interfaces (`ISupplier`, `IPurchaseOrder`, `IPOItem`)

### 2. Fastify Routes & Controllers ✅
- [x] Build CRUD routes for `suppliers`
- [x] Build routes to generate POs (`POST /purchase-orders`)
- [x] Build route to calculate average cost margins and receive POs (`POST /purchase-orders/:id/receive` - auto-increments `inventory`)

### 3. Flutter Interface (Operations App) ✅
- [x] Implement Procurement / Suppliers data models (`api_client.dart` / Riverpod integration)
- [x] Build Flutter "Procurement Navigation" logic (Add to navigation rail / bottom tab)
- [x] Build Flutter **Procurement/Purchase Orders Dashboard/List**
- [x] Build Flutter **PO Receiving Workflow View** (with responsive SnackBar status messages)

### 4. React Web App (Admin UI) ✅
- [x] Build Supplier Dashboard (Grid view, search, pagination)
- [x] Build Add/Edit Supplier forms
- [x] Build dynamic PO Builder (Select supplier, dynamically append inventory items, quantity, calculate cost margins, support one-off items)
- [x] Build Purchase Orders list and detail views for backend tracking

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

## Stage 9 — Advanced Inventory & Barcode
- [ ] Implement multi-bin tracking (Warehouse vs Storefront)
- [ ] Implement stocktake workflow and inventory adjustments 
- [ ] Implement low-stock alerts and threshold email triggers
- [ ] Implement barcode printing and USB barcode scanner support in Flutter

## Stage 10 — Point of Sale (POS) Interface
- [ ] Build rapid-checkout touch interface tailored specifically for tablet/desktop
- [ ] Implement split payments (Cash + Card)
- [ ] Connect EFTPOS/Stripe terminal hardware syncing
- [ ] Shift closeouts and drawer reconciliation 

## Stage 11 — E-Commerce Syncing
- [ ] Establish 2-way sync bridge for Shopify/WooCommerce
- [ ] Sync local inventory counts to online database in real-time
- [ ] Ingest online orders into tickets/invoices automatically

## Future Competitive Features
- [ ] **Buy/Sell/Trade (Refurbishment):** Pipeline to intake used devices, absorb parts/labor costs, and output refurbished retail inventory with accurate profit margins.
- [ ] **Automated Comms:** Twilio/SendGrid integration for automated SMS status updates and 30-day post-repair follow-ups.
- [ ] **Customer Portal:** Lightweight web view for clients to check ticket status and pay Stripe invoices via Ticket ID.
- [ ] **Staff Management:** Tie `time_entries` to commission structures and payroll reports.
- [ ] **Accounting Sync:** Cron jobs to push finalized invoices and POs to Xero/QuickBooks.
