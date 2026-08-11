#!/usr/bin/env bash
set -Eeuo pipefail

# This watchdog repairs only the Docker runtime state that made Caddy appear
# running while it had no proxy-network endpoint or host port bindings. It does
# not attempt to recover application or database failures.

readonly APP_DIR="/opt/technopro/app"
readonly ENV_FILE="$APP_DIR/deploy/.env"
readonly COMPOSE_FILE="$APP_DIR/deploy/compose.vps.yml"
readonly LOCK_FILE="/run/technopro-caddy-watchdog.lock"
readonly STATE_DIR="/var/lib/technopro"
readonly LAST_RECOVERY_FILE="$STATE_DIR/caddy-watchdog-last-recovery"
readonly MIN_RECOVERY_INTERVAL_SECONDS=600

log() {
  printf '%s\n' "[technopro-caddy-watchdog] $*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

env_value() {
  local key="$1"
  awk -v key="$key" 'index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }' "$ENV_FILE"
}

[[ -r "$ENV_FILE" ]] || fail "missing deployment environment file: $ENV_FILE"
[[ -r "$COMPOSE_FILE" ]] || fail "missing Compose file: $COMPOSE_FILE"
command -v docker >/dev/null 2>&1 || fail "docker is not available"
command -v curl >/dev/null 2>&1 || fail "curl is not available"
command -v flock >/dev/null 2>&1 || fail "flock is not available"

exec 9>"$LOCK_FILE"
flock -n 9 || {
  log "another watchdog invocation is already running; skipping"
  exit 0
}

compose=(docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE")
domain="$(env_value TECHNOPRO_DOMAIN)"
[[ -n "$domain" ]] || fail "TECHNOPRO_DOMAIN is missing from $ENV_FILE"

api_container="$("${compose[@]}" ps -q api 2>/dev/null || true)"
[[ -n "$api_container" ]] || {
  log "API container is absent; not attempting Caddy recovery"
  exit 0
}

api_health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$api_container" 2>/dev/null || true)"
[[ "$api_health" == "healthy" ]] || {
  log "API health is '$api_health'; not attempting Caddy recovery"
  exit 0
}

caddy_container="$("${compose[@]}" ps -q caddy 2>/dev/null || true)"
network_attached=false
ports_published=false

if [[ -n "$caddy_container" ]]; then
  network_state="$(docker inspect --format '{{if index .NetworkSettings.Networks "technopro_proxy"}}attached{{end}}' "$caddy_container" 2>/dev/null || true)"
  [[ "$network_state" == "attached" ]] && network_attached=true

  port_state="$(docker port "$caddy_container" 2>/dev/null || true)"
  if grep -Fqx '80/tcp -> 0.0.0.0:80' <<<"$port_state" && \
     grep -Fqx '443/tcp -> 0.0.0.0:443' <<<"$port_state"; then
    ports_published=true
  fi
fi

if $network_attached && $ports_published; then
  if curl --fail --silent --show-error --max-time 15 \
    --resolve "$domain:443:127.0.0.1" \
    "https://$domain/api/v1/health" >/dev/null; then
    log "Caddy network, port bindings and local HTTPS health check are healthy"
  else
    log "Caddy bindings are present but the local HTTPS health check failed; not recreating Caddy automatically"
  fi
  exit 0
fi

log "Caddy recovery condition detected (network_attached=$network_attached ports_published=$ports_published)"

mkdir -p "$STATE_DIR"
now="$(date +%s)"
if [[ -f "$LAST_RECOVERY_FILE" ]]; then
  previous="$(cat "$LAST_RECOVERY_FILE" 2>/dev/null || true)"
  if [[ "$previous" =~ ^[0-9]+$ ]] && (( now - previous < MIN_RECOVERY_INTERVAL_SECONDS )); then
    log "last recovery was $(( now - previous )) seconds ago; rate-limited"
    exit 0
  fi
fi

printf '%s\n' "$now" > "$LAST_RECOVERY_FILE"
log "recreating only the Caddy service to restore Docker networking and host port bindings"
"${compose[@]}" up -d --no-deps --force-recreate caddy

recovered_caddy="$("${compose[@]}" ps -q caddy 2>/dev/null || true)"
[[ -n "$recovered_caddy" ]] || fail "Caddy recreation did not produce a container"

recovered_network="$(docker inspect --format '{{if index .NetworkSettings.Networks "technopro_proxy"}}attached{{end}}' "$recovered_caddy" 2>/dev/null || true)"
recovered_ports="$(docker port "$recovered_caddy" 2>/dev/null || true)"
[[ "$recovered_network" == "attached" ]] || fail "Caddy remains detached from technopro_proxy"
grep -Fqx '80/tcp -> 0.0.0.0:80' <<<"$recovered_ports" || fail "Caddy did not publish TCP 80"
grep -Fqx '443/tcp -> 0.0.0.0:443' <<<"$recovered_ports" || fail "Caddy did not publish TCP 443"

curl --fail --silent --show-error --max-time 15 \
  --resolve "$domain:443:127.0.0.1" \
  "https://$domain/api/v1/health" >/dev/null || fail "local HTTPS health check failed after Caddy recreation"

log "Caddy recovery completed and local HTTPS health check passed"
