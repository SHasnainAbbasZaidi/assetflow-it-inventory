# Self-hosting AssetFlow

## Preserve state separately from deployments

The database is SQLite. Production state must live outside a replaceable checkout, container image or release directory. Example persistent locations on Linux:

- Database: `/var/lib/assetflow/assetflow.db`
- Backups: `/var/lib/assetflow/backups/`
- AI master key: `/var/lib/assetflow/.assetflow-ai.key`
- Environment configuration: `/etc/assetflow/assetflow.env`

Use a persistent volume for these paths in a container. Restrict the directory to the service account (`chmod 700` on Linux) and secret files to mode `600`. Preserve the same paths across upgrades. Never delete or overwrite state directories as part of deploying code.

Install Node.js 22 or 24, npm, Git, and a process manager such as systemd or PM2. The server does not require Flutter, Android Studio or PostgreSQL.

## Existing installation: safe update

1. Stop the AssetFlow process cleanly during the update. Locate the database currently used by its `DATABASE_URL`; do not replace `.env` with the example file. A legacy `file:./dev.db` points to `server/prisma/dev.db`, independent of the working directory.
2. Make a SQLite-consistent backup. With the process stopped, preserve the database and any `-wal`/`-shm` files together, or use SQLite's `.backup` command. Keep previous backups and the AI key file.
3. Pull the release into the existing checkout, or switch the code directory while retaining the persistent environment file and database. If relocating the database, copy the stopped database to the persistent location and verify its records before changing `DATABASE_URL`; keep the original copy.
4. In `server/`, run:

   ```sh
   npm ci
   npm run db:generate
   npm start
   ```

5. Startup checks that the database file/tables exist, makes a pre-upgrade database snapshot beside it when required, and adds the missing peripheral-owner column/index without replacing records. Other incompatible schemas stop startup with a diagnostic. Do not respond to such an error with a reset.
6. Verify `/health`, log in, check known asset tags and personnel assignments, and confirm scheduled backups are present. For PM2 restart the configured process after installation instead of leaving an extra `npm start` process running.

**Do not run `prisma migrate reset`, `prisma db push --force-reset`, `prisma migrate dev` or `db:init` to update an existing installation.** `db:migrate` is now an idempotent, additive schema verification command; normal startup runs the same check.

## New installation only

Clone the repository and install server dependencies. Create a persistent environment file (or `server/.env` for local development). Example:

```dotenv
DATABASE_URL="file:/var/lib/assetflow/assetflow.db"
BACKUP_ROOT="/var/lib/assetflow/backups"
JWT_SECRET="replace-with-at-least-32-random-characters"
INITIAL_ADMIN_EMAIL="admin@example.com"
INITIAL_ADMIN_PASSWORD="choose-a-unique-password-at-least-12-characters"
PORT=3000
```

On Windows use an absolute URL such as `file:C:/AssetFlowData/assetflow.db`. Generate a JWT secret with `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"` and put the value only in the environment file, never in source control.

Set `ASSETFLOW_ENV_FILE=/etc/assetflow/assetflow.env` in the process environment when using a separate configuration file. Then, from `server/`:

```sh
npm ci
npm run db:generate
npm run db:init
npm start
```

Initialization exclusively creates a new database and refuses any existing file. The initial password is used only by `db:init`; normal startup does not recreate default accounts or alter assignments. Remove the bootstrap password from the environment after provisioning if desired.

## PM2 and HTTPS

Start one process for the database/backup schedule, for example:

```sh
ASSETFLOW_ENV_FILE=/etc/assetflow/assetflow.env pm2 start /opt/assetflow/server/src/server.js --name assetflow
pm2 save
```

Configure Nginx on the same host to terminate HTTPS and proxy to `127.0.0.1:3000`. Restrict direct access to port 3000 at the firewall. Example within your TLS virtual host:

```nginx
client_max_body_size 105m;
location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 180s;
}
```

Redirect port 80 to HTTPS. The app trusts proxy headers only from loopback. AI key management and AI calls require HTTPS, except direct loopback development requests. If a reverse proxy runs in a separate container, configure an equivalent trusted network deliberately rather than exposing an untrusted forwarded-header setup.

## Empty lists after an update

A load failure now shows an explicit error rather than an empty dashboard. Check server logs and the configured database location first. The missing `peripherals.personnel_id` column is upgraded automatically. If startup says the database is missing, reconnect the existing persistent file/volume; do not initialize a replacement. If data was actually deleted before this release, restore an existing valid backup. Code updates cannot reconstruct deleted records without a backup.

## Android

Install the release APK as an update using the same package/signature. Configure the server's HTTPS address in the Android app. Do not uninstall the existing application just to update it. [Build instructions](inventory_manager_flutter/README.md) cover the stored application logo and versioning.
