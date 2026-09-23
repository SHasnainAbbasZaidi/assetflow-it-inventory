# Administrator tools

AssetFlow is a product of Mahzaidex Tech, developed by Hasnain Zaidi.

Reports are available to active administrators on web and Android. Inventory, person-wise ownership (including direct and workstation-inherited peripheral ownership), warranty, account and audit reports can be previewed and exported to Excel. Account reports never include password hashes.

Super Power Delete is only in Settings. Administrators must select an item and type its exact tag. The item is permanently removed without a new audit entry or notification. Existing audit history and older backups remain intact. Deleting a workstation detaches its peripherals; inherited assigned peripherals return to store. Directly owned peripherals retain their owner.

## Backups

While the Node server runs, it checks every minute whether a daily backup is due. On startup it also checks for a missing or overdue backup. It exports the same transactionally consistent database snapshot into two separate directories next to `package.json`:

- `Backup`: Excel reference exports, latest 10 only. Password hashes are excluded.
- `AutomaticBackups`: complete, restorable JSON state, latest 10 only.
- `ManualBackups`: manual and pre-restore recovery copies. These are retained until an operator removes them.

Files are completed before older backups are removed. Only generated backup filenames are eligible for automatic retention. These directories are excluded from Git and are not publicly served. Set `BACKUP_ROOT` to an absolute persistent directory if deployment replaces the application directory. Run only one scheduled Node instance per database/backup directory. Backups stored on the same drive do not protect against drive loss; administrators can download full-state copies from Settings on web or Android.

Full-state snapshots contain every scalar field from all seven database models: inventory and relationships, personnel, accounts and password hashes, settings (including encoded logos/templates), custom field definitions and audit history. They are data snapshots, not copies of source code, APKs, server `.env` secrets or externally linked files. Excel exports are not full-state restore files.

## Restore

Settings → Backup and Restore accepts a saved server backup or an uploaded full-state JSON file (maximum 100 MB). Type `RESTORE` to confirm replacement. The server verifies the format, checksum and field schema, requires an active administrator account in the backup, saves a recovery snapshot, and restores all database tables in one transaction. Invalid relationships roll back the entire restore. Sign in using credentials from the restored snapshot afterward.

Backups contain sensitive account and settings data. Access is checked against the current active administrator account in the database on every administrator-tools request. Store downloaded backups securely.

Startup now performs the additive database-schema upgrade safely. Previously deleted records still require an existing backup for recovery.

Encrypted AI credentials are included in full-state snapshots. Keep the separate AI master-key file when moving or restoring to another machine; snapshots do not include it. General settings/Excel exports exclude secret entries. Scrap report snapshots are included in full-state backups. See [../SECURITY.md](../SECURITY.md).
