# AssetFlow deployment

`server/` is the production API. It runs **Node.js only**: Express, Prisma/PostgreSQL, ExcelJS, and no Flutter SDK or Dart runtime.

1. Copy `server/.env.example` to `server/.env` and set PostgreSQL and a strong JWT secret.
2. In `server/`, run `npm install`, `npm run db:generate`, `npm run db:migrate`, then `npm start`.
3. Build Android/iOS or web Flutter artifacts locally or in CI. Mobile APK/IPA files go directly to devices. If a web UI is desired, run `flutter build web` outside the server and set `FLUTTER_WEB_DIR` to its prebuilt `build/web` directory. Express only serves static HTML/JS/CSS; it never builds Flutter.

The Excel routes require a Bearer token. Import accepts `multipart/form-data` with field `file`; export is `GET /api/excel/export`. Both use the exact four-sheet `IT Asset Database.xlsx` schema.
