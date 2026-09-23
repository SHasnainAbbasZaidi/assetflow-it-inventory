# Release notes

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
