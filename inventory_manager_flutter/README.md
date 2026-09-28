# AssetFlow Android — Mahzaidex Tech

Developed by Hasnain Zaidi. Flutter builds are separate from the Node hosting server.

## Launcher icon and release build

The QR application icon at `assets/images/default_logo.png` is the default for future builds. From the repository root on Windows run:

```powershell
./scripts/build-branded-apk.ps1
```

The script generates all Android launcher densities and builds the APK without needing a running server. An explicit `-LogoPath C:/path/to/logo.png` overrides the default for that build; `-IconsOnly` updates just the icon resources. Company branding inside the app does not silently change the launcher icon.

The script also works around Windows JDK temporary socket-path failures with a workspace-local socket directory. It replaces `server/public/download/app-release.apk` only after a successful release build.

The version is in `pubspec.yaml`; version 1.2.1+4 means display version 1.2.1 and Android version code 4. Keep the existing application ID (`com.assetflow.inventory_manager_flutter`) and signing key when updating installed copies. The current project uses its established debug keystore for compatibility; protect it and plan any signing-key change separately.

## Features and checks

Administrators can grant individual report access in Settings → Users & Access. Restore, backups, scrapping, user management and permanent inventory deletion always require an administrator. Personal AI keys are managed through the server; no provider key is persisted in the APK or local settings. Scrap reports support batch tags, immutable report history, Excel export and printable PDF download.

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
```

The last command uses the already-generated launcher icons. Use the PowerShell script for the default QR icon or an explicit logo override. Install the APK as an update rather than uninstalling the existing app. Configure the self-hosted HTTPS server address before signing in.

Camera permission denial has a Retry camera action. The scanner resumes with the app and pauses during assignment. Camera lifecycle tests use a simulated camera; confirm scanning on the target Android device before deploying widely. Keep the existing Server URL, Username and Password login flow.
