# TechnoPro server release

This bundle runs the TechnoPro API, MySQL and Caddy HTTPS proxy using versioned images from GitHub Container Registry. It does not require the source repository or a local image build.

## Quick start

The normal installation path is the `install-technopro.sh` asset attached to the same GitHub release. It asks for the required values and the host swap size, defaulting to a 1 GB swap file on new installs when no active swap exists, then generates secrets and starts the stack. Re-run the installer from a newer release to update.

This archive is retained as the version-matched deployment kit used by the installer and as a manual recovery option. For a manual deployment:

1. Point an `A` DNS record such as `crm.example.com` at the VPS.
2. Install Docker Engine and the Docker Compose plugin.
3. Copy `deploy/.env.example` to `deploy/.env`, set the domain, and replace every example password/secret.
4. Create the backup directory configured by `BACKUP_PATH`.
5. For a shared or 2 GB VPS, configure host swap before starting the stack; the manual bundle does not change host swap automatically.
6. Start the stack:

   ```bash
   cp deploy/.env.example deploy/.env
   chmod 600 deploy/.env
   sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml config --quiet
   sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml pull
   sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml up -d
   sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml ps -a
   ```

7. Create the first administrator using the command in `docs/vps-docker-deployment.md`.
8. Open `https://YOUR_DOMAIN/api/v1/health`, then configure the same server URL on the Android login screen.

Read `docs/vps-docker-deployment.md` before putting real data into the system. It covers firewalling, administrator creation, nightly backups, restore testing, updates and the complete go-live checklist.
