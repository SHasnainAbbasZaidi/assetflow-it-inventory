# IT Asset Inventory fix summary

## Excel and database

The previous project had no Node database schema or XLSX engine; it only stored a generic asset shape in Hive/IndexedDB and exported/imported a seven-column CSV. This lost the required workstation/peripheral fields, did not preserve real dates, had no four-sheet round-trip, and could silently replace data by generic ID.

`server/prisma/schema.prisma` now defines normalized Workstation, Peripheral, AppUser, and append-only AuditLog tables. It persists the exact status labels (including `In Store`) while keeping safe application enum keys. `server/src/services/excel-service.js` accepts and emits the exact required headers/order, writes Excel date cells, upserts tags, validates integer quantity and dates, reports invalid rows without rolling back valid ones, rejects orphaned peripherals, and never overwrites existing audit-log IDs.

## QR lookup

The Flutter scanner previously searched a locally cached generic list and opened the same edit dialog for every result; there was no API lookup or camera permission handling. It now calls one `GET /api/assets/lookup/:tag` through `AssetApiService`; the server checks a workstation first and then a peripheral and returns a discriminated result. The Flutter UI displays workstation and peripheral details separately and renders a permission-denied/manual-entry path.

## Lifecycle

The old client allowed hard deletion and arbitrary statuses such as `Available` and `In Use`. The production API never deletes an asset, defaults all creates to `IN_STORE`, exposes restore, logs each lifecycle update, and only permits: In Store → Assigned/Retired/Out of Order; Assigned → In Store/Retired/Out of Order; Out of Order → In Store/Retired; Retired → In Store. Invalid changes return HTTP 409.

## State and API quality

The old Flutter provider did notify on many local Hive mutations, but it was disconnected from any authoritative server and its scan flow showed stale local data. The scanner now uses the authenticated server response. The Node API validates every write with Zod, uses a consistent `{ error: { code, message, details } }` body, returns 400/401/404/409 appropriately, and logs lifecycle changes transactionally.

The legacy browser `app.js` remains an unrelated IndexedDB demo and is not the production server. Do not deploy it as the backend.
