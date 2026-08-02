#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

for variable in DB_HOST DB_NAME DB_USER DB_PASSWORD; do
  if [[ -z "${!variable:-}" ]]; then
    echo "$variable is required" >&2
    exit 1
  fi
done

if [[ ! "$DB_NAME" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "DB_NAME contains unsupported characters" >&2
  exit 1
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
daily_root="/backups/daily"
weekly_root="/backups/weekly"
destination="$daily_root/$timestamp"
temporary="${destination}.partial"

mkdir -p "$daily_root" "$weekly_root" "$temporary"
trap 'rm -rf -- "$temporary"' EXIT

MYSQL_PWD="$DB_PASSWORD" mysqldump \
  --host="$DB_HOST" \
  --user="$DB_USER" \
  --single-transaction \
  --quick \
  --no-tablespaces \
  --routines \
  --triggers \
  --events \
  --set-gtid-purged=OFF \
  "$DB_NAME" | gzip -9 > "$temporary/database.sql.gz"

tar --numeric-owner -C /uploads -czf "$temporary/uploads.tar.gz" .
(
  cd "$temporary"
  sha256sum database.sql.gz uploads.tar.gz > SHA256SUMS
)

mv "$temporary" "$destination"
trap - EXIT

week="$(date -u +%G-W%V)"
if [[ ! -e "$weekly_root/$week" ]]; then
  cp -a "$destination" "$weekly_root/$week"
fi

prune_sets() {
  local root="$1"
  local keep="$2"
  local entries=()
  mapfile -t entries < <(find "$root" -mindepth 1 -maxdepth 1 -type d -print | sort)
  while (( ${#entries[@]} > keep )); do
    local oldest="${entries[0]}"
    if [[ "$oldest" != "$root/"* ]]; then
      echo "Refusing to prune unexpected path: $oldest" >&2
      exit 1
    fi
    rm -rf -- "$oldest"
    entries=("${entries[@]:1}")
  done
}

prune_sets "$daily_root" 7
prune_sets "$weekly_root" 4

echo "Backup completed: $destination"
