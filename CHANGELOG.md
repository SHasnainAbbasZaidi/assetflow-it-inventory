# Release notes

## Unreleased

- Separate the overall Dashboard from category management views on web and mobile. Refine the web overview with summary cards, hardware distribution, lifecycle chart and activity panels.
- Align Excel exports and daily Excel backups with the four hardware categories; include personnel and preserve identifiers, assignments, specifications and custom fields on import.
- Validate current-format workbook imports atomically, retain legacy four-sheet support, and include a derived category index in full-state backups without breaking older restores.

## 1.2.0 — 2026-09-24

- Organize the web and Android inventory dashboards into Workstations, Peripherals, Devices and Components, with matching category counts, search, status filters and item actions. Existing records and tag identifiers stay in their original database tables.
- Match the supplied tag reference with stacked details and a top-right QR code: eight 93 × 65 mm workstation tags or sixteen 93 × 30 mm accessory tags per A4 page, at actual size with 10 mm margins. Preserve custom templates; reject oversized content instead of making text unreadable.
- Use the QR application icon by default in future APK builds. Android version is **1.2.0 (3)**; the application ID, signing key and **Server URL, Username, Password** login flow are unchanged.
- Automatically register scrapped items from status updates and Excel imports, with item snapshots, scrap date and operator. Report creation and status changes commit together. Reconcile older scrapped records without inventing missing historical dates or operators.
- Preserve mobile hardware specifications when opening and saving existing records. Keep full-list import and bulk-print actions accessible from the dashboard.
- Include reference screenshots generated with synthetic demonstration data. The mobile screenshot renders the actual Flutter interface in the widget test harness; it is not a physical-device photograph.

### Validation and update

Server regression tests, browser workflows, Flutter tests, and QR decoding checks cover category routing, backup/restore, assignment, roles, encrypted keys, reports, imports and printed tags. Preserve the database, environment configuration and AI key as described in [INSTALLATION.md](INSTALLATION.md). Install the APK over the existing compatible app. Physical Android camera/printer hardware and live paid AI-provider access require deployment-side checks.

See [reference screenshots](docs/screenshots/v1.2.0/README.md).

## 1.1.0 — 2026-09-23

- Preserve existing SQLite records across upgrades: stable database-path resolution, additive startup migration with a pre-upgrade backup, no startup reseeding, and explicit refusal of missing or incompatible databases.
- Replace product attribution with Mahzaidex Tech; developer remains Hasnain Zaidi.
- Use the saved application logo for Android launcher icons and repeatable branded release builds.
- Add administrator inventory/person-wise/warranty/account/audit reports and batch Scrap Items Reports with date/operator details, idempotent transactional scrapping, saved report history, printable PDF and Excel output.
- Add Settings-only Super Power Delete without a new audit record or notification, plus full-state backup/restore and separate daily Excel/restorable backup retention (latest 10 each).
- Add encrypted, per-user OpenAI/Gemini credentials and server-side AI analysis. Remove legacy local plaintext Gemini storage; require HTTPS for remote AI requests.
- Check current account permissions on authenticated requests, restrict account-changing Excel imports to administrators, and prevent reassignment/import overwrite of scrapped records.
- Fix release Android networking permissions and clarify failed data loading instead of showing misleading empty inventory.
- Consolidate installation, update, backup, security and Android build documentation.

### Update notes

Preserve the database, environment file, AI master key and backup directories. In `server/`, run `npm ci`, `npm run db:generate`, then restart the server. Do not initialize or reset an existing database. See [INSTALLATION.md](INSTALLATION.md).

Install APK version **1.1.0 (2)** over the existing compatible installation. Re-enter any old locally stored Gemini key in Settings → AI API Keys. AI provider integration is covered with isolated mocked requests; a live provider key/account is required to validate billing, quota and model access in your deployment.
