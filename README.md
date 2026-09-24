# AssetFlow 1.1.0

IT inventory management for web and Android. A product of **Mahzaidex Tech**, developed by **Hasnain Zaidi**.

- Workstations, peripherals, personnel, assignment history, QR scanning and customizable printable tags.
- Administrator reports, including batch Scrap Items Reports with operator/date details and printable PDF/Excel output.
- Daily Excel and full-state backups, manual backup/restore, and Settings-only permanent deletion.
- Personal OpenAI and Google Gemini API keys encrypted on the server; AI inventory analysis and image-assisted item entry.

## Installation and updates

Follow [INSTALLATION.md](INSTALLATION.md). The production web/API server uses Node.js, Express, Prisma and **SQLite**. Flutter is needed only to build Android applications; it is not needed on the hosting server.

**Existing installations:** preserve your `.env`, SQLite database, AI encryption key and backup directories. Run `npm ci`, `npm run db:generate`, then restart from `server/`. Startup performs the supported additive schema upgrade with a pre-upgrade backup. It never resets or seeds existing records. A missing/incompatible database stops startup with an error instead of silently creating a new inventory.

**New installations only:** configure an unused persistent database path and initial administrator password, then run `npm run db:init`. This command refuses to overwrite an existing file. Never run Prisma reset/development migration commands against production data.

## Documentation

- [Self-hosting, safe updates and troubleshooting](INSTALLATION.md)
- [Backups and restore](server/BACKUPS.md)
- [Android launcher branding and release builds](inventory_manager_flutter/README.md)
- [Security and AI credentials](SECURITY.md)
- [Release notes](CHANGELOG.md)

Reports and destructive administration features require an active administrator. All signed-in users can manage their own AI keys in Settings. Excel import is administrator-only because workbooks can contain user accounts. Excel now uses Workstations, Peripherals, Devices, Components, Personnel, Users and Audit Logs sheets. Older four-sheet imports remain supported. Full-state restore uses JSON backups, not the exchange workbook.

## Verification

From `server/`, with Node.js 24 for the isolated SQLite tests:

```sh
node --test tests/*.test.js tests/*.test.cjs
```

Browser tests require Playwright in the local `.build-tools` directory. From the Flutter project:

```sh
flutter analyze --no-fatal-infos
flutter test
```

The release APK and checksums are published in [GitHub Releases](https://github.com/SHasnainAbbasZaidi/assetflow-it-inventory/releases). Keep the same Android application ID and signing key when updating an installed app.

## Inventory dashboard and tag reference

Version 1.2.0 groups inventory into Workstations, Peripherals, Devices and Components on web and Android. Classification is a view of existing records; upgrades do not move or recreate assets. Mobile sign-in remains Server URL, Username and Password. [View the reference screenshots](docs/screenshots/v1.2.0/README.md).

Compact A4 layouts follow the supplied tag reference and preserve actual label size. Scrap status updates and imports automatically register reports. Older scrapped records with missing history are explicitly marked as having an unknown original scrap date/operator.
