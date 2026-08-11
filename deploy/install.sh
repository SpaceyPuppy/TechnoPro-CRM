#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

readonly REPOSITORY="SpaceyPuppy/TechnoPro-CRM"
readonly RELEASE_VERSION="__TECHNOPRO_VERSION__"
readonly INSTALL_ROOT="/opt/technopro"
readonly APP_DIR="$INSTALL_ROOT/app"
readonly ENV_FILE="$APP_DIR/deploy/.env"
readonly ADMIN_MARKER="$INSTALL_ROOT/.admin-created"
readonly SWAP_FILE="/swapfile"

version=""
domain=""
backup_path=""
timezone=""
admin_email=""
admin_name=""
admin_password="${ADMIN_PASSWORD:-}"
swap_size=""
assume_yes=false

usage() {
  cat <<'EOF'
Install or update TechnoPro on a Debian VPS.

Usage:
  sudo ./install-technopro.sh [options]

Options:
  --version VERSION          Release to install; normally embedded by GitHub Actions
  --domain HOSTNAME          Public HTTPS hostname, without https://
  --backup-path PATH         Local backup directory (default: /opt/technopro/backups)
  --timezone TIMEZONE        Container timezone (default: Australia/Sydney)
  --admin-email EMAIL        Initial administrator email
  --admin-name NAME          Initial administrator name
  --admin-password PASSWORD  Initial password; prompting is safer than this option
  --swap-size SIZE           Configure host swap (new-install default: 1G; 0 to skip)
  -y, --yes                  Accept installation confirmations
  -h, --help                 Show this help

Missing values are requested interactively. On an update, the existing domain,
backup path, timezone and secrets are retained unless an option overrides them.
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_value() {
  [[ $# -ge 2 && -n "$2" ]] || die "$1 requires a value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      require_value "$1" "${2:-}"
      version="$2"
      shift 2
      ;;
    --version=*) version="${1#*=}"; shift ;;
    --domain)
      require_value "$1" "${2:-}"
      domain="$2"
      shift 2
      ;;
    --domain=*) domain="${1#*=}"; shift ;;
    --backup-path)
      require_value "$1" "${2:-}"
      backup_path="$2"
      shift 2
      ;;
    --backup-path=*) backup_path="${1#*=}"; shift ;;
    --timezone)
      require_value "$1" "${2:-}"
      timezone="$2"
      shift 2
      ;;
    --timezone=*) timezone="${1#*=}"; shift ;;
    --admin-email)
      require_value "$1" "${2:-}"
      admin_email="$2"
      shift 2
      ;;
    --admin-email=*) admin_email="${1#*=}"; shift ;;
    --admin-name)
      require_value "$1" "${2:-}"
      admin_name="$2"
      shift 2
      ;;
    --admin-name=*) admin_name="${1#*=}"; shift ;;
    --admin-password)
      require_value "$1" "${2:-}"
      admin_password="$2"
      shift 2
      ;;
    --admin-password=*) admin_password="${1#*=}"; shift ;;
    --swap-size)
      require_value "$1" "${2:-}"
      swap_size="$2"
      shift 2
      ;;
    --swap-size=*) swap_size="${1#*=}"; shift ;;
    -y|--yes) assume_yes=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ $EUID -eq 0 ]] || die "run this installer with sudo"

if [[ -z "$version" ]]; then
  [[ "$RELEASE_VERSION" != *TECHNOPRO_VERSION* ]] || \
    die "this source copy needs --version; use the installer attached to a GitHub release"
  version="$RELEASE_VERSION"
fi
version="${version#v}"

[[ "$version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "invalid release version"

env_value() {
  local key="$1"
  local file="$2"
  awk -v key="$key" 'index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }' "$file"
}

prompt_value() {
  local variable="$1"
  local label="$2"
  local default_value="${3:-}"
  local current_value="${!variable:-}"

  [[ -n "$current_value" ]] && return
  [[ -t 0 ]] || die "$label is required when running non-interactively"

  if [[ -n "$default_value" ]]; then
    read -r -p "$label [$default_value]: " current_value
    current_value="${current_value:-$default_value}"
  else
    read -r -p "$label: " current_value
  fi
  [[ -n "$current_value" ]] || die "$label is required"
  printf -v "$variable" '%s' "$current_value"
}

prompt_password() {
  [[ -n "$admin_password" ]] && return
  [[ -t 0 ]] || die "Admin password is required when running non-interactively"
  read -r -s -p "Initial administrator password (12+ characters): " admin_password
  printf '\n'
  [[ -n "$admin_password" ]] || die "Admin password is required"
}

confirm() {
  local message="$1"
  local answer=""

  $assume_yes && return
  [[ -t 0 ]] || die "$message; rerun with --yes to confirm"
  read -r -p "$message [Y/n]: " answer
  [[ ! "$answer" =~ ^[Nn]$ ]] || die "cancelled"
}

update_env_value() {
  local key="$1"
  local value="$2"
  local file="$3"
  local temporary
  temporary="$(mktemp "${file}.XXXXXX")"
  awk -v key="$key" -v value="$value" '
    BEGIN { found = 0 }
    index($0, key "=") == 1 { print key "=" value; found = 1; next }
    { print }
    END { if (!found) print key "=" value }
  ' "$file" > "$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$file"
}

existing_install=false
current_version=""
if [[ -f "$ENV_FILE" ]]; then
  existing_install=true
  current_version="$(env_value TECHNOPRO_VERSION "$ENV_FILE")"
  domain="${domain:-$(env_value TECHNOPRO_DOMAIN "$ENV_FILE")}"
  backup_path="${backup_path:-$(env_value BACKUP_PATH "$ENV_FILE")}"
  timezone="${timezone:-$(env_value TZ "$ENV_FILE")}"
fi

if [[ -z "$swap_size" ]]; then
  if $existing_install; then
    swap_size="preserve"
  elif [[ -t 0 ]]; then
    read -r -p "Host swap size [1G, 0 to skip]: " swap_size
    swap_size="${swap_size:-1G}"
  else
    swap_size="1G"
  fi
fi

if [[ "$swap_size" != "preserve" && "$swap_size" != "0" && ! "$swap_size" =~ ^[1-9][0-9]*[KMGTP]?$ ]]; then
  die "swap size must be 0 or a positive size such as 512M or 1G"
fi

prompt_value domain "Public hostname"
prompt_value backup_path "Backup directory" "/opt/technopro/backups"
prompt_value timezone "Timezone" "Australia/Sydney"

[[ "$domain" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] || \
  die "hostname must not contain a scheme, port or path"
[[ "$backup_path" == /* && "$backup_path" != *:* ]] || die "backup directory must be an absolute path without ':'"
[[ "$timezone" =~ ^[A-Za-z0-9_+/-]+$ ]] || die "invalid timezone"

configure_admin=false
if ! $existing_install || [[ -n "$admin_email" || -n "$admin_name" || -n "$admin_password" ]]; then
  configure_admin=true
  prompt_value admin_email "Initial administrator email"
  prompt_value admin_name "Initial administrator name"
  prompt_password
  [[ "$admin_email" == *@*.* ]] || die "invalid administrator email"
  [[ ${#admin_password} -ge 12 ]] || die "administrator password must contain at least 12 characters"
fi

echo
if $existing_install; then
  echo "TechnoPro update/reapply"
  echo "  Current version: ${current_version:-unknown}"
else
  echo "TechnoPro new installation"
fi
echo "  Target version:  $version"
echo "  Hostname:        $domain"
echo "  Backup path:     $backup_path"
echo "  Timezone:        $timezone"
if [[ "$swap_size" == "preserve" ]]; then
  echo "  Swap:            preserve existing host configuration"
elif [[ "$swap_size" == "0" ]]; then
  echo "  Swap:            disabled by option"
else
  echo "  Swap:            ${swap_size} at $SWAP_FILE when no active swap exists"
fi
confirm "Continue"

configure_swap() {
  [[ "$swap_size" == "preserve" || "$swap_size" == "0" ]] && return 0

  local active_swap
  active_swap="$(swapon --show --noheadings 2>/dev/null || true)"
  if [[ -n "$active_swap" ]]; then
    echo "Active swap detected; leaving the existing host swap configuration unchanged."
    return 0
  fi

  if [[ -e "$SWAP_FILE" ]]; then
    [[ -f "$SWAP_FILE" && ! -L "$SWAP_FILE" ]] || \
      die "$SWAP_FILE exists but is not a regular file; inspect it before rerunning"
    die "$SWAP_FILE exists but is not active; inspect it before rerunning"
  fi

  command -v fallocate >/dev/null 2>&1 || die "fallocate is required to create $SWAP_FILE"
  command -v mkswap >/dev/null 2>&1 || die "mkswap is required to create $SWAP_FILE"
  command -v swapon >/dev/null 2>&1 || die "swapon is required to enable $SWAP_FILE"

  echo "Creating ${swap_size} swap at $SWAP_FILE..."
  fallocate -l "$swap_size" "$SWAP_FILE"
  chmod 600 "$SWAP_FILE"
  mkswap "$SWAP_FILE" >/dev/null
  swapon "$SWAP_FILE"
  if ! grep -Fqx "$SWAP_FILE none swap sw 0 0" /etc/fstab; then
    printf '%s\n' "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
  fi
}

install_dependencies() {
  local missing=false
  local command
  for command in curl tar sha256sum openssl awk; do
    command -v "$command" >/dev/null 2>&1 || missing=true
  done
  $missing || return 0
  command -v apt-get >/dev/null 2>&1 || die "install curl, tar, coreutils, openssl and awk, then rerun"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl coreutils gawk openssl tar
}

install_docker() {
  [[ -r /etc/os-release ]] || die "automatic Docker installation requires Debian"
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "debian" && -n "${VERSION_CODENAME:-}" ]] || \
    die "automatic Docker installation currently supports Debian only"
  command -v dpkg >/dev/null 2>&1 || die "dpkg is required to install Docker"

  echo "Docker Engine is not installed. Installing it from Docker's Debian repository."
  confirm "Install Docker Engine and the Compose plugin"

  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $VERSION_CODENAME
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

install_dependencies
configure_swap
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  install_docker
fi

temporary="$(mktemp -d /tmp/technopro-installer.XXXXXX)"
trap 'rm -rf -- "$temporary"' EXIT

archive="technopro-server-${version}.tar.gz"
release_url="https://github.com/${REPOSITORY}/releases/download/v${version}"
echo "Downloading TechnoPro $version deployment files..."
curl -fsSL "$release_url/$archive" -o "$temporary/$archive"
curl -fsSL "$release_url/SHA256SUMS.txt" -o "$temporary/SHA256SUMS.txt"

checksum_line="$(awk -v archive="$archive" '$2 == archive { print; exit }' "$temporary/SHA256SUMS.txt")"
[[ -n "$checksum_line" ]] || die "$archive is missing from SHA256SUMS.txt"
printf '%s\n' "$checksum_line" | (cd "$temporary" && sha256sum -c -)
tar -xzf "$temporary/$archive" -C "$temporary"
bundle="$temporary/technopro-server-${version}"
[[ -f "$bundle/deploy/compose.vps.yml" ]] || die "release deployment bundle is incomplete"

install -d -m 0750 "$APP_DIR/deploy/scripts" "$APP_DIR/deploy/systemd" "$APP_DIR/docs"
install -m 0644 "$bundle/deploy/compose.vps.yml" "$APP_DIR/deploy/compose.vps.yml"
install -m 0644 "$bundle/deploy/Caddyfile" "$APP_DIR/deploy/Caddyfile"
install -m 0644 "$bundle/deploy/.env.example" "$APP_DIR/deploy/.env.example"
install -m 0644 "$bundle/README.md" "$APP_DIR/README.md"
install -m 0644 "$bundle/docs/vps-docker-deployment.md" "$APP_DIR/docs/vps-docker-deployment.md"
install -m 0755 "$bundle/deploy/scripts/backup.sh" "$APP_DIR/deploy/scripts/backup.sh"
install -m 0755 "$bundle/deploy/scripts/restore.sh" "$APP_DIR/deploy/scripts/restore.sh"
install -m 0755 "$bundle/deploy/scripts/caddy-watchdog.sh" "$APP_DIR/deploy/scripts/caddy-watchdog.sh"
install -m 0644 "$bundle/deploy/systemd/technopro-caddy-watchdog.service" \
  /etc/systemd/system/technopro-caddy-watchdog.service
install -m 0644 "$bundle/deploy/systemd/technopro-caddy-watchdog.timer" \
  /etc/systemd/system/technopro-caddy-watchdog.timer
install -d -m 0700 "$backup_path"

if $existing_install && [[ -n "$current_version" && "$current_version" != "$version" ]]; then
  previous_compose=(docker compose --env-file "$ENV_FILE" -f "$APP_DIR/deploy/compose.vps.yml")
  "${previous_compose[@]}" config --quiet
  if "${previous_compose[@]}" ps --status running --services 2>/dev/null | grep -qx db; then
    echo "Creating a pre-update backup..."
    "${previous_compose[@]}" --profile tools run --rm backup
  fi
fi

if ! $existing_install; then
  db_password="$(openssl rand -hex 32)"
  db_root_password="$(openssl rand -hex 32)"
  jwt_secret="$(openssl rand -hex 48)"
  cat > "$ENV_FILE" <<EOF
TECHNOPRO_DOMAIN=$domain
TECHNOPRO_VERSION=$version
TZ=$timezone

DB_NAME=technopro
DB_USER=technopro
DB_PASSWORD=$db_password
DB_ROOT_PASSWORD=$db_root_password

JWT_SECRET=$jwt_secret
JWT_EXPIRES_IN=12h
MAX_FILE_SIZE_MB=10

BACKUP_PATH=$backup_path
UPLOAD_UID=1000
UPLOAD_GID=1000
EOF
else
  update_env_value TECHNOPRO_DOMAIN "$domain" "$ENV_FILE"
  update_env_value TECHNOPRO_VERSION "$version" "$ENV_FILE"
  update_env_value TZ "$timezone" "$ENV_FILE"
  update_env_value BACKUP_PATH "$backup_path" "$ENV_FILE"
fi
chmod 600 "$ENV_FILE"

compose=(docker compose --env-file "$ENV_FILE" -f "$APP_DIR/deploy/compose.vps.yml")
"${compose[@]}" config --quiet

"${compose[@]}" pull
"${compose[@]}" up -d

systemctl daemon-reload
systemctl enable --now technopro-caddy-watchdog.timer

if $configure_admin; then
  echo "Creating or confirming the initial administrator..."
  ADMIN_EMAIL="$admin_email" \
  ADMIN_NAME="$admin_name" \
  ADMIN_PASSWORD="$admin_password" \
    "${compose[@]}" --profile tools run --rm admin
  install -m 0600 /dev/null "$ADMIN_MARKER"
fi

echo
"${compose[@]}" ps -a
echo
echo "TechnoPro $version is deployed."
echo "API health URL: https://$domain/api/v1/health"
echo "Android server URL: https://$domain"
echo "Re-run the installer attached to a newer release to update."
