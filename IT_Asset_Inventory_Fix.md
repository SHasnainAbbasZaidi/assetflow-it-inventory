# AI Code Builder Prompt — IT Asset Inventory App: Bug Fix, Excel Engine & Server Architecture

## Role and Context

Act as a **Senior Full-Stack Developer** specializing in **Flutter (mobile client)** and **Node.js (backend + server-side web delivery)**. I have an existing IT Asset Inventory App with logical errors in the current codebase. The full architecture and business logic requirements are documented in the attached `.md` file — read it fully before making any changes and treat it as the source of truth whenever it conflicts with what you infer from the code.

## Critical Architecture Constraint (read this first)

The **Flutter codebase must remain exactly as it is structurally** — it is my mobile client and I am not abandoning it. However, **the production server must never require the Flutter SDK, Dart runtime, or any Flutter build tooling installed on it.**

Concretely:
- **Backend runtime = Node.js only.** All API logic, database access, Excel import/export, QR-tag resolution, and auth run in Node.js (Express or Fastify). Nothing about the backend should assume Flutter is present on the host.
- **Flutter build artifacts are produced elsewhere.** Mobile builds (APK/IPA) are compiled locally or in CI and distributed directly to devices — the server never touches this.
- **If a browser-accessible version is wanted later**, `flutter build web` is run once (locally/CI) to produce a static `build/web` folder of plain HTML/JS/CSS. Node/Express then just serves that folder as static files (`express.static`) — this is a one-time build step, not a server dependency. The server still never installs Flutter.
- Document this separation clearly in the README/deployment notes you generate, so it's obvious at a glance that "Node server" and "Flutter build" are two independent, non-overlapping concerns.

## Task

Perform a deep, end-to-end analysis of the Flutter frontend and Node.js backend. Identify and fix all logical errors, bring the code into strict alignment with the attached `.md` requirements, and implement a complete, production-grade Excel import/export engine matching the exact structure of `IT Asset Database.xlsx`. Deliver corrected code, not just a list of problems.

## Suggested Stack (adjust only if the existing codebase already commits to something incompatible — state the discrepancy if so)

- **Backend:** Node.js + Express (or Fastify), `exceljs` for Excel I/O (preferred over `xlsx`/SheetJS for styling + streaming large files), an ORM (Prisma or Sequelize) over PostgreSQL (or the existing DB if already chosen), JWT-based auth, `multer` for file uploads.
- **Frontend:** Existing Flutter app, state management as currently used (Provider/Riverpod/BLoC — inspect and stay consistent, don't introduce a second pattern), `mobile_scanner` or `qr_code_scanner` for camera QR reads, `http`/`dio` for API calls.

---

## 1. Excel Data Import & Database Mapping

Build bidirectional Excel handling for `IT Asset Database.xlsx`, exactly matching these 4 sheets and columns:

| Sheet | Columns |
|---|---|
| **Workstations** | `Workstation Tag`, `User Name`, `Device Type`, `Motherboard`, `Processor & Gen`, `RAM`, `SSD`, `HDD`, `GPU`, `Status`, `Assigned Date`, `PDF File`, `Notes` |
| **Peripherals** | `Peripheral Tag`, `Category`, `Model Specs`, `Workstation Tag`, `Status`, `Purchase Date`, `Warranty Expiry`, `Brand / Manufacturer`, `Quantity`, `Storage Capacity`, `GPU Specs` |
| **Users** | `Email`, `Full Name`, `Role`, `Status` |
| **Audit Logs** | `Log ID`, `Timestamp`, `User Email`, `Asset Tag`, `Action Taken` |

Requirements:
- **Schema alignment:** Ensure DB tables/models carry every one of the above fields, with correct types (dates as real date columns, `Quantity` as integer, etc.), not just whatever the code currently has.
- **Import logic:**
  - Parse all 4 sheets in one pass; validate required fields per row before writing (e.g., `Workstation Tag` and `Peripheral Tag`/`Log ID` are non-null and unique).
  - Upsert semantics: if a `Workstation Tag` / `Peripheral Tag` already exists, update it; otherwise insert. Never silently duplicate rows on re-import.
  - Referential integrity: a Peripheral's `Workstation Tag` must resolve to an existing Workstation — if it doesn't, flag the row in an import error report instead of crashing the whole import or inserting an orphaned reference.
  - Audit Logs are **append-only on import** — never update/overwrite an existing `Log ID`.
  - Return a structured import summary (rows inserted, rows updated, rows skipped with reasons) rather than a bare success/fail boolean.
  - Reject/report malformed rows without aborting the entire file — partial success with a clear error list beats an all-or-nothing failure.
- **Export logic:** Generate a `.xlsx` with the same 4 sheets, same column order and headers, pulling live data from the DB. Dates must round-trip correctly (export as actual Excel dates, not strings), and the exported file must re-import cleanly (export → import → identical data, no drift).

## 2. Global QR Code Scanning & Search Logic

- Audit the Flutter camera scanning flow and the backend search endpoint(s).
- A scanned code must trigger **one global lookup** that checks both `Workstation Tag` and `Peripheral Tag` — not two separate manual searches.
- Backend: expose a single endpoint (e.g., `GET /api/assets/lookup/:tag`) that checks Workstations first, then Peripherals, and returns a discriminated result (`{ type: "workstation" | "peripheral", data: {...} }`) or a clean 404 if no match.
- Frontend: on scan success, call that endpoint once and route to the correct detail screen (`WorkstationDetailScreen` vs `PeripheralDetailScreen`) based on the returned `type` — eliminate any duplicated or category-specific scan handlers if they exist.
- Handle the "not found" and "camera permission denied" cases explicitly in the UI rather than failing silently.

## 3. Asset Lifecycle & Status Validation

- **Creation:** Every new Workstation and Peripheral must default to status `"In Store"` at the DB layer (not just in the UI form), so direct API calls can't bypass the default.
- **Retire flow:** Decommissioning must be a **status update**, never a row delete. Confirm the "Retire" action sets status to `"Retired"` or `"Out of Order"` (per the `.md` file's exact enum) and preserves all historical fields and audit history.
- **Restore flow:** Verify (or build) an endpoint/UI action to move an asset from `"Retired"` back to `"In Store"`, and confirm this transition is logged in Audit Logs.
- Enforce status transitions server-side against whatever state machine the `.md` file defines (e.g., don't allow `"Retired" → "Assigned"` directly if that's not a valid transition) — reject invalid transitions with a clear 4xx error rather than allowing silent writes.

## 4. Code Quality & State Management

- **Flutter:** Trace what happens to on-screen state after a status change or reassignment — confirm the relevant provider/notifier/bloc actually emits a new state and the detail + list screens rebuild, rather than showing stale cached data until a manual refresh.
- **Node.js:** Review controllers/middleware for: consistent error response shape, input validation (missing fields, wrong types, invalid enum values) before hitting the DB, and proper HTTP status codes (400 vs 404 vs 409 vs 500) instead of everything falling through to a generic 500.
- Flag any place where the running code contradicts the `.md` file's stated business rules, and fix the code (not the doc).

---

## Execution Instructions for AI

1. Read the attached `.md` file fully and treat it as the authoritative spec.
2. Review the Node.js backend: DB schema, models, API routes, and Excel import/export logic (`exceljs`). Confirm no part of the backend has any Flutter/Dart dependency.
3. Review the Flutter frontend: UI logic, state management, API integration, and QR scan handling. Do not change its overall architecture — fix defects in place.
4. Produce, in order:
   - A summary of every logical error found, grouped by the 4 functional areas above.
   - The exact corrected code blocks (backend and frontend), each labeled with its file path.
   - A short deployment note confirming the server runs on Node.js alone, with Flutter builds handled as a separate, out-of-band step.
