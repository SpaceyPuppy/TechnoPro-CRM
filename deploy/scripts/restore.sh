#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

for variable in DB_HOST DB_NAME DB_ROOT_PASSWORD BACKUP_SET; do
  if [[ -z "${!variable:-}" ]]; then
    echo "$variable is required" >&2
    exit 1
  fi
done

if [[ ! "$DB_NAME" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "DB_NAME contains unsupported characters" >&2
  exit 1
fi
if [[ ! "$BACKUP_SET" =~ ^(daily|weekly)/[A-Za-z0-9._-]+$ ]]; then
  echo "BACKUP_SET must look like daily/20260101T120000Z or weekly/2026-W01" >&2
  exit 1
fi

source_dir="/backups/$BACKUP_SET"
for file in SHA256SUMS database.sql.gz uploads.tar.gz; do
  if [[ ! -f "$source_dir/$file" ]]; then
    echo "Backup is incomplete: missing $file" >&2
    exit 1
  fi
done

(
  cd "$source_dir"
  sha256sum --check SHA256SUMS
)

MYSQL_PWD="$DB_ROOT_PASSWORD" mysql \
  --host="$DB_HOST" \
  --user=root \
  --execute="DROP DATABASE IF EXISTS \`$DB_NAME\`; CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"

gzip -dc "$source_dir/database.sql.gz" | MYSQL_PWD="$DB_ROOT_PASSWORD" mysql \
  --host="$DB_HOST" \
  --user=root \
  "$DB_NAME"

find /uploads -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
tar --numeric-owner -C /uploads -xzf "$source_dir/uploads.tar.gz"
chown -R "${UPLOAD_UID:-1000}:${UPLOAD_GID:-1000}" /uploads

echo "Restore completed from $BACKUP_SET"
