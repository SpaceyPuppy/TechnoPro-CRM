# TechnoPro CRM — Roadmap

**Current status:** Service MVP deployed and tested on Android. Stabilisation is the active phase; native procurement remains incomplete and advanced inventory has not started.

The Flutter Windows and Android application is the product. The React application is retained only as implementation reference and is not part of the active release roadmap.

## Status key

- **Verified:** exercised against the deployed VPS and Android release.
- **Implemented:** present in code, but not necessarily proven in the deployed workflow.
- **Partial:** some supporting code exists, but the native workflow is incomplete.
- **Experimental:** present but outside the release gate.
- **Deferred:** intentionally postponed.

## Immediate — Android MVP stabilisation

### Field test

- [x] Install the signed Android APK.
- [x] Connect to the VPS API over HTTPS and log in.
- [x] Exercise the Android service workflow and capture usability issues.
- [ ] Retest the affected workflows after the fixes below are released.
- [ ] Verify the guided installer update/re-run path with the next bundled prerelease.
- [ ] Configure nightly local backups and restore one backup onto a clean database.

### UX fixes from Android testing

- [ ] **Ticket customer picker:** show search results in an anchored overlay/dropdown with a fixed maximum height so results do not push the form down. Debounce search, keep the keyboard usable, and replace results with a compact selected-customer summary once chosen.
- [ ] **Pattern lock:** remove visible numbers; use a familiar Android-style 3×3 pattern surface with larger dots and touch targets, smoother path animation, clear retry/reset behaviour, and subtle haptic feedback where supported.
- [ ] **Invoice service line tax:** add a business default and an inclusive/exclusive tax selector when adding a service line. Show the calculated ex-tax amount, GST and total before saving, and preserve the selected tax treatment on the line item.
- [ ] **PDF sharing/email settings:** load business settings before PDF generation or sharing. Handle missing ABN, business email and other optional branding fields gracefully; explain which required setting is missing and provide a direct route to Settings instead of reporting only “setting not loaded”.
- [ ] **Ticket status changes:** provide an inline status control on ticket detail without entering Edit. Include quick close/resolve actions with confirmation where appropriate, and update lists/dashboard immediately after a change.
- [ ] **Dashboard freshness:** refresh when the Dashboard tab is selected again, when the app resumes, and after mutations that affect dashboard totals. Keep pull-to-refresh, use cached data while revalidating, and avoid disruptive loading flashes.

## Maintenance PRs awaiting merge

- [ ] PR #3 — upgrade GitHub Actions to Node 24.
- [ ] PR #4 — fix the guided installer exiting after confirmation.

Both changes should be merged independently and included in the next bundled prerelease; merging them does not require publishing a release immediately.

## Core Service MVP

### Implemented

- [x] Staff authentication and roles.
- [x] Business settings, GST, labour rate and invoice branding.
- [x] Customers, devices/assets and optional service location.
- [x] Repair, onsite and remote tickets with assignment, priority, scheduling and status.
- [x] Ticket notes, checklists and attachments/photos.
- [x] Timers, manual time entries and bill-once labour invoicing.
- [x] Quotes, invoices, deposits, partial payments and refunds.
- [x] PDF quotes, invoices and receipts.
- [x] Basic inventory search and adding stocked parts to work.
- [x] Dashboard metrics.
- [x] Windows and Android Flutter targets.

### Hardening to perform alongside affected features

- [ ] Audit role enforcement across every API route and corresponding Flutter action.
- [ ] Extend immutable audit events beyond current finance/time coverage to customer, ticket, inventory, procurement and administration changes.
- [ ] Confirm financial and stock mutations use transactions and idempotency consistently.
- [ ] Validate attachment type/size handling and user-facing errors.

## Next feature phase — Complete native procurement

**Status: Partial.** Supplier and purchase-order backend APIs exist. Flutter PO list/detail/receiving code exists, but procurement is not wired into application navigation and the native supplier and PO creation workflows are missing.

- [ ] Add role-gated Procurement navigation and Flutter routes.
- [ ] Make the existing PO list, detail and receiving screens reachable.
- [ ] Build native supplier list, create, edit and delete workflows.
- [ ] Build a native PO creator for stocked and one-off items.
- [ ] Add ticket-linked special orders after the core PO workflow is usable.

Do not begin advanced inventory merely because the old roadmap labelled procurement complete. Complete and test this native workflow first.

## Inventory foundation

**Status: Basic inventory implemented; advanced stock control not started.** Current quantities are mutable values and do not yet form a complete stock history.

- [ ] Add an immutable inventory-movement ledger containing item, quantity delta, reason, source, staff member, timestamp and cost snapshot.
- [ ] Route PO receipts, ticket parts, returns and manual adjustments through one transactional stock service.
- [ ] Add stock adjustment controls and movement history.
- [ ] Add stocktake workflow.
- [ ] Add locations/bins and stock transfers.
- [ ] Add barcode scanning and label printing.
- [ ] Add reorder thresholds and in-app low-stock alerts.
- [ ] Add threshold email alerts after outbound email is configured.

## Point of sale

- [ ] Build a rapid checkout interface for phone, tablet and Windows.
- [ ] Support cash and manually confirmed EFTPOS.
- [ ] Add split tender.
- [ ] Add cash-drawer and register reconciliation.
- [ ] Consider terminal/hardware integrations only after the manual workflow is stable.

## Experimental or partial capabilities

- [ ] **Offline sync:** Drift database, queue and sync components exist, but offline-created records are outside the MVP release gate and need conflict/device testing before being supported.
- [ ] **Bulk import:** backend customer/inventory bulk operations exist, but there is no native CSV/XLSX picker, mapping, validation and import-report workflow.
- [ ] **RBAC UI:** some role-based hiding exists; complete a systematic audit rather than rebuilding it.
- [ ] **Audit events:** finance and billed-time events exist; expand coverage as noted above.

## Deferred

- [ ] CSV/XLSX import presets for RepairDesk, CrazyPOS and ClickUp.
- [ ] Generic CSV/XLSX import and export UI.
- [ ] Buy/sell/trade refurbishment pipeline.
- [ ] Customer portal.
- [ ] Xero or other accounting sync.
- [ ] Ecommerce integrations.
- [ ] Payroll and commissions.
- [ ] Automated customer SMS/email workflows.
- [ ] Automated application updates.

## Delivery workflow

- Use one focused branch and pull request for each feature or fix.
- Merge completed PRs without creating a release for every minor change.
- When a useful group of changes is ready, create one bundled prerelease containing the VPS Docker package and signed Android APK.
- Keep this file as the high-level roadmap. Create GitHub Issues only for work that is ready to enter the implementation queue.
