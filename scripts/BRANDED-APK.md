# Branded Android build

Save a company logo in the web UI first, then run `./scripts/build-branded-apk.ps1` from PowerShell. The local server must be running; `-ServerUrl` selects another server and `-Flutter` selects the Flutter SDK.

The script updates launcher icon resources from the saved logo, builds the release APK and publishes a successful build to the existing download endpoint. Installed apps need to install that APK update to change their launcher icon. Keep the same application ID and signing key to retain installed application data. This project's current release configuration uses the debug signing key; do not change signing keys for an existing installation without planning a migration.

Within the mobile application, company branding and tag appearance settings refresh on the existing server synchronization workflow. Failed settings requests retain cached values. This does not rename or migrate inventory records.
