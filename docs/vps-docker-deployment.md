# TechnoPro CRM: Docker VPS deployment

This runbook deploys the Fastify API, MySQL, private file storage and Caddy HTTPS proxy from `deploy/compose.vps.yml`. Only ports 80 and 443 are published. MySQL stays on an internal Docker network.

The first deployment should be treated as a release candidate until the Android go-live workflow and a restore drill have passed. Do not expose the old development `docker-compose.yml`; it publishes MySQL and phpMyAdmin and is not a production stack.

## How GitHub delivers TechnoPro

- **The GitHub repository** stores the source code, deployment definitions and history.
- **Pull requests** provide a reviewable boundary before changes enter `main`.
- **GitHub Actions** runs CI, builds the Android APK and container images, creates the guided installer, calculates checksums and publishes each tagged release.
- **GHCR** (GitHub Container Registry, sometimes mistaken for "GHCI") stores the versioned API and migration container images that Docker pulls on the VPS.
- **GitHub Releases** provides the guided installer, Android APK, small deployment kit and checksums for a specific version.
- **GitHub Actions secrets** hold the Android signing material used by the release workflow. They are not included in the repository or server package.

The installer is intentionally small. It downloads the version-matched deployment kit, while Docker Compose pulls the application images from GHCR and the official MySQL and Caddy images from their registries.

## 1. VPS and DNS prerequisites

Recommended starting point:

- Debian 12 or 13, 2 vCPU and 4 GB RAM.
- At least 30 GB of SSD storage, plus a separate backup disk or encrypted remote backup target.
- A domain such as `crm.example.com` with an `A` record (and `AAAA` only if IPv6 is working) pointing to the VPS.
- TCP 80/443 and UDP 443 allowed at the VPS provider firewall. Restrict SSH to your IP where practical.
- SMTP is not required by the current MVP.

Docker warns that published container ports can bypass some UFW/firewalld rules. Use the VPS provider firewall as the first boundary and review Docker's `DOCKER-USER` chain before adding other published services.

Official references:

- [Install Docker Engine on Debian](https://docs.docker.com/engine/install/debian/)
- [Install the Docker Compose plugin](https://docs.docker.com/compose/install/linux/)
- [Caddy automatic HTTPS](https://caddyserver.com/docs/automatic-https)
- [MySQL 8.4 LTS release model](https://dev.mysql.com/doc/refman/8.4/en/mysql-releases.html)

## 2. Docker installation

The guided installer in the next section offers to install Docker Engine and the Compose plugin from Docker's Debian repository when they are missing. Skip to section 3 for the normal installation path.

To install Docker manually instead, run the following as a sudo-capable deployment user:

```bash
sudo apt update
sudo apt install -y ca-certificates curl git openssl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker run --rm hello-world
sudo docker compose version
```

The commands below use `sudo docker`. Adding an account to the `docker` group is equivalent to granting root-level control of the host, so only do that deliberately.

## 3. Install or update TechnoPro

Open the desired GitHub prerelease, download its `install-technopro.sh` asset, inspect it, and run it with `sudo`. Each installer is pinned to the release it came from:

```bash
VERSION=REPLACE_WITH_RELEASE_VERSION
curl -fsSLO "https://github.com/SpaceyPuppy/TechnoPro-CRM/releases/download/v${VERSION}/install-technopro.sh"
less install-technopro.sh
chmod +x install-technopro.sh
sudo ./install-technopro.sh
```

The guided mode asks for the hostname, local backup path, timezone and initial administrator. It generates the database and JWT secrets without displaying them. On later runs it retains the existing configuration, pulls the selected release from GHCR and applies the update. If the version changes while the database is running, it creates a local backup first.

For TechnoPro's current deployment, the same choices can be supplied in one command:

```bash
sudo ./install-technopro.sh \
  --domain technopro.fcpr.au \
  --backup-path /opt/technopro/backups \
  --timezone Australia/Sydney \
  --admin-email chris@fcpr.au \
  --admin-name "Christopher Phelan" \
  --yes
```

The password is still requested using a hidden prompt. Fully unattended operation is possible by adding `--admin-password 'PASSWORD'`, but doing that records the password in shell history and may expose it in the process list.

To update, download `install-technopro.sh` from the newer prerelease and run it. The installer reads `/opt/technopro/app/deploy/.env`, preserves the database, uploads, HTTPS state and secrets, and updates only the versioned deployment files and containers.

The release still includes `technopro-server-VERSION.tar.gz` as a manual recovery package, but normal installation no longer requires extracting it yourself.

After the installer finishes, the deployment files are under:

```bash
cd /opt/technopro/app
```

Never commit `deploy/.env`, a signing keystore or a database dump.

## 4. Validate and start the stack

The installer already runs these commands. They remain documented for troubleshooting or manual control:

Use one consistent Compose command throughout:

```bash
cd /opt/technopro/app
sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml config --quiet
sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml pull
sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml up -d
sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml ps -a
```

The expected state is:

- `db`, `api` and `caddy` are running and healthy.
- `migrate` exited with status 0 after applying `backend/src/db/migrations`.
- No host port exists for MySQL or the API container.

If migration or startup fails, inspect logs before retrying:

```bash
sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml logs --tail=200 migrate api db caddy
```

Verify HTTPS from a different connection:

```bash
curl --fail --show-error https://crm.example.com/api/v1/health
```

Replace the example hostname. A healthy result contains `"status":"ok"`. Caddy obtains and renews the public certificate automatically when DNS and ports 80/443 are correct.

## 5. Create the first administrator

The installer creates the first administrator without writing its password to `.env`. The command below is retained for recovery or a fully manual deployment:

```bash
cd /opt/technopro/app
read -r -p "Admin email: " ADMIN_EMAIL
read -r -p "Admin name: " ADMIN_NAME
read -r -s -p "Admin password (12+ characters): " ADMIN_PASSWORD
printf '\n'
export ADMIN_EMAIL ADMIN_NAME ADMIN_PASSWORD
sudo --preserve-env=ADMIN_EMAIL,ADMIN_NAME,ADMIN_PASSWORD docker compose \
  --env-file deploy/.env \
  -f deploy/compose.vps.yml \
  --profile tools run --rm admin
unset ADMIN_EMAIL ADMIN_NAME ADMIN_PASSWORD
```

The command is idempotent: it does not reset an existing administrator's password. Password resets should be implemented as a separate audited operation.

## 6. Connect the Android app

On the login screen, expand **Server** and enter either:

```text
https://crm.example.com
```

or the full base URL:

```text
https://crm.example.com/api/v1
```

Tap **Test**, save the URL, then sign in. Release Android builds reject cleartext HTTP, so the VPS endpoint must have valid HTTPS.

For a manually signed release APK, create an upload keystore once and keep it backed up outside the repository:

```bash
keytool -genkeypair -v \
  -keystore technopro-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias technopro-upload
```

On the build workstation, copy `flutter/android/key.properties.example` to `flutter/android/key.properties`, fill in the keystore path and passwords, then run:

```bash
chmod +x flutter/android/gradlew
cd flutter
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://crm.example.com/api/v1
```

The APK is written under `flutter/build/app/outputs/flutter-apk/`. Do not lose the keystore; Android updates must be signed with the same key.

## 7. Nightly backups

The backup job writes a checksum-protected database dump and attachment archive. It retains seven daily sets and one set for each of the latest four ISO weeks.

Test it manually:

```bash
cd /opt/technopro/app
sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml \
  --profile tools run --rm backup
sudo find /opt/technopro/backups -maxdepth 2 -type d -print
```

Schedule it with root's cron:

```bash
sudo crontab -e
```

Add this single line (adjust the repository path if needed):

```cron
15 2 * * * cd /opt/technopro/app && /usr/bin/docker compose --env-file deploy/.env -f deploy/compose.vps.yml --profile tools run --rm backup >> /var/log/technopro-backup.log 2>&1
```

A backup on the same VPS is not sufficient long term. Copy `/opt/technopro/backups` to an encrypted remote destination or another physical device when offsite backups are configured, and alert if the nightly job stops producing new sets.

## 8. Mandatory restore drill

First list available sets:

```bash
sudo find /opt/technopro/backups/daily /opt/technopro/backups/weekly \
  -mindepth 1 -maxdepth 1 -type d -printf '%P\n'
```

Restore into a separate Compose project so the live named volumes are untouched. Do not omit `-p technopro-restore-test`:

```bash
cd /opt/technopro/app
sudo docker compose -p technopro-restore-test --env-file deploy/.env \
  -f deploy/compose.vps.yml up -d db

BACKUP_SET=daily/REPLACE_WITH_SET sudo --preserve-env=BACKUP_SET docker compose \
  -p technopro-restore-test --env-file deploy/.env \
  -f deploy/compose.vps.yml --profile tools run --rm restore

sudo docker compose -p technopro-restore-test --env-file deploy/.env \
  -f deploy/compose.vps.yml up -d migrate api
sudo docker compose -p technopro-restore-test --env-file deploy/.env \
  -f deploy/compose.vps.yml ps -a
```

Check the API container is healthy and inspect representative customer, ticket and invoice row counts. Only after that should the drill project be removed:

```bash
sudo docker compose -p technopro-restore-test --env-file deploy/.env \
  -f deploy/compose.vps.yml down --volumes
```

That final command deletes only the explicitly named restore-test project's containers and volumes. It must never be run against the live `technopro` project.

For an actual disaster recovery, stop `api` and `caddy`, take a VPS snapshot if possible, set `BACKUP_SET`, run the same `restore` job without the test project name, then start the stack and re-run the full go-live workflow.

## 9. Preserve an existing TechnoPro database

Do not run the initial migration over an existing schema. Instead:

1. Back up the old database and upload directory.
2. Produce a data-only dump with explicit column names:

   ```bash
   mysqldump --single-transaction --no-create-info --complete-insert \
     --skip-triggers -h OLD_DB_HOST -u OLD_DB_USER -p OLD_DB_NAME \
     > technopro-data-only.sql
   ```

3. Start the clean VPS stack so the checked-in migrations create the current schema.
4. Stop `api` and `caddy`, then load the data-only dump:

   ```bash
   sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml stop api caddy
   sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml exec -T db \
     sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot "$MYSQL_DATABASE"' \
     < technopro-data-only.sql
   ```

5. Copy the old upload directory into the `technopro_uploads` named volume and set its contents to uid/gid 1000.
6. Start the services, inspect logs, and validate customers, tickets, invoices, payments and attachment access before deleting the old system.

Keep the source backup until a later backup from the VPS has itself passed a restore drill.

## 10. Updating TechnoPro

Download `install-technopro.sh` from the desired newer prerelease and run it with `sudo`, as described in section 3. It preserves the current environment and persistent volumes, creates a backup when changing versions while the database is running, and pulls the exact versioned images.

The commands below remain available for manual control:

```bash
cd /opt/technopro/app
sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml \
  --profile tools run --rm backup
sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml pull
sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml up -d
sudo docker compose --env-file deploy/.env -f deploy/compose.vps.yml ps -a
```

Then repeat the Android go-live scenario. Do not automatically prune images or volumes during the first releases; retain a known-good application image until the upgrade is verified.

## Go-live checklist

- DNS resolves to the intended VPS.
- Only SSH, 80 and 443 are reachable externally; MySQL and port 3000 are not.
- HTTPS health check succeeds.
- No demo credentials were seeded.
- Android can create a customer and ticket, add a note/photo/time, invoice it, record a payment once, produce a PDF/receipt and close the ticket.
- A payment request retried with the same idempotency key does not create a duplicate.
- A nightly backup exists off the VPS.
- A clean restore drill has passed.
