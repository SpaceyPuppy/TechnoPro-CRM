# TechnoPro CRM: Docker VPS deployment

This runbook deploys the Fastify API, MySQL, private file storage and Caddy HTTPS proxy from `deploy/compose.vps.yml`. Only ports 80 and 443 are published. MySQL stays on an internal Docker network.

The first deployment should be treated as a release candidate until the Android go-live workflow and a restore drill have passed. Do not expose the old development `docker-compose.yml`; it publishes MySQL and phpMyAdmin and is not a production stack.

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

## 2. Install Docker from Docker's Debian repository

Run as a sudo-capable deployment user:

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

## 3. Put TechnoPro on the VPS

Download the versioned server bundle from the matching GitHub prerelease. The first MVP release uses `0.1.0-mvp.1`:

```bash
VERSION=0.1.0-mvp.1
cd /tmp
curl -fLO "https://github.com/SpaceyPuppy/TechnoPro-CRM/releases/download/v${VERSION}/technopro-server-${VERSION}.tar.gz"
curl -fLO "https://github.com/SpaceyPuppy/TechnoPro-CRM/releases/download/v${VERSION}/SHA256SUMS.txt"
grep "technopro-server-${VERSION}.tar.gz" SHA256SUMS.txt | sha256sum -c -

sudo install -d -m 0750 /opt/technopro
sudo chown "$USER":"$USER" /opt/technopro
tar -xzf "technopro-server-${VERSION}.tar.gz"
mv "technopro-server-${VERSION}" /opt/technopro/app
cd /opt/technopro/app
```

The bundle contains versioned prebuilt container references, so the VPS does not need the source repository or a local image build.

Create the production environment file:

```bash
cp deploy/.env.example deploy/.env
chmod 600 deploy/.env
openssl rand -base64 48
openssl rand -base64 48
openssl rand -base64 48
```

Put three different generated values into `DB_PASSWORD`, `DB_ROOT_PASSWORD` and `JWT_SECRET`. Also set:

- `TECHNOPRO_DOMAIN` to the DNS name, without `https://`.
- `BACKUP_PATH` to an existing directory on a separate mounted disk where possible.
- `TZ` if the business is outside `Australia/Sydney`.

Create and protect the backup directory:

```bash
sudo install -d -m 0700 /mnt/technopro-backups
```

Never commit `deploy/.env`, a signing keystore or a database dump.

## 4. Validate and start the stack

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

The demo seed is deliberately not used in production. Supply the first administrator through temporary shell variables so the password is not written to `.env`:

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
sudo find /mnt/technopro-backups -maxdepth 2 -type d -print
```

Schedule it with root's cron:

```bash
sudo crontab -e
```

Add this single line (adjust the repository path if needed):

```cron
15 2 * * * cd /opt/technopro/app && /usr/bin/docker compose --env-file deploy/.env -f deploy/compose.vps.yml --profile tools run --rm backup >> /var/log/technopro-backup.log 2>&1
```

A backup on the same VPS is not sufficient. Copy `/mnt/technopro-backups` to an encrypted remote destination or another physical device, and alert if the nightly job stops producing new sets.

## 8. Mandatory restore drill

First list available sets:

```bash
sudo find /mnt/technopro-backups/daily /mnt/technopro-backups/weekly \
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

Take a backup before every update. Download and verify the new server bundle as described in section 3, preserve the current `deploy/.env`, and then set `TECHNOPRO_VERSION` to the new release version. Pull and start the exact versioned images:

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
