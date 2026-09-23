# AssetFlow Android — Mahzaidex Tech

Developed by Hasnain Zaidi. Flutter builds are separate from the Node hosting server.

## Launcher icon and release build

Save the application logo in web Settings → Company Details & Logo, then from the repository root on Windows run:

```powershell
./scripts/build-branded-apk.ps1 -ServerUrl http://localhost:3000
```

Alternatively pass `-LogoPath C:/path/to/application-logo.png`. The script saves the uploaded source as `assets/images/launcher_logo.png`, generates every Android launcher density, then builds the release APK. The saved source/icons are versioned so subsequent normal Flutter builds retain the chosen logo. If no logo is saved on the server, the build script reuses the saved launcher source; it does not substitute the Flutter icon. Use `-IconsOnly` to update just the icon resources.

The script also works around Windows JDK temporary socket-path failures with a workspace-local socket directory. It replaces `server/public/download/app-release.apk` only after a successful release build.

The version is in `pubspec.yaml`; version 1.1.0+2 means display version 1.1.0 and Android version code 2. Keep the existing application ID (`com.assetflow.inventory_manager_flutter`) and signing key when updating installed copies. The current project uses its established debug keystore for compatibility; protect it and plan any signing-key change separately.

## Features and checks

Reports and Settings-only destructive controls require an administrator. Personal AI keys are managed through the server; no provider key is persisted in the APK or local settings. Scrap reports support batch tags, immutable report history, Excel export and printable PDF download.

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
```

The last command uses the already-generated launcher icons. Use the PowerShell script whenever the uploaded logo changes. Install the APK as an update rather than uninstalling the existing app. Configure the self-hosted HTTPS server address before signing in.
