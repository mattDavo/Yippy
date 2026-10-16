#!/usr/bin/env sh
# Deploys the sync server on the VPS behind the existing reverse proxy: preflight -> build -> release -> verify.
#
#   sh deploy.sh              pull, build, release and verify; a release that fails verification is rolled back
#   sh deploy.sh --check      run every precondition and change nothing
#   sh deploy.sh --no-pull    deploy the code as it is checked out
#   sh deploy.sh --rollback   return to the previous verified release (the image only; the data volume is untouched)
#
# Overrides (environment): SYNC_COMPOSE_FILE (docker-compose.prod.yml), SYNC_HEALTH_TIMEOUT (90 seconds).
set -eu

MODE=deploy
PULL=1
for arg in "$@"; do
  case "$arg" in
    --check) MODE=check ;;
    --rollback) MODE=rollback ;;
    --no-pull) PULL=0 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (use --check, --rollback or --no-pull)" >&2; exit 2 ;;
  esac
done

cd "$(dirname "$0")"
COMPOSE_FILE="${SYNC_COMPOSE_FILE:-docker-compose.prod.yml}"
HEALTH_TIMEOUT="${SYNC_HEALTH_TIMEOUT:-90}"
IMAGE=cairn-sync-server

log() { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*"; }
step() { printf '\n== %s\n' "$*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

COMPOSE="docker compose"
if ! docker compose version >/dev/null 2>&1; then
  COMPOSE="docker-compose"
fi
# $COMPOSE is deliberately unquoted: it is one or two words.
compose() { $COMPOSE -f "$COMPOSE_FILE" "$@"; }

env_value() { sed -n "s/^$1=//p" .env | tail -n 1; }

preflight() {
  step "Preflight"
  docker info >/dev/null 2>&1 || fail "Docker isn't reachable (run as root or a member of the docker group)"
  [ -f .env ] || fail ".env is missing: cp .env.example .env, fill it in, then chmod 600 .env"
  case "$(ls -l .env)" in
    -??????r*) fail ".env is readable by other users: chmod 600 .env" ;;
  esac
  [ -n "$(env_value SYNC_DOMAIN)" ] || fail "SYNC_DOMAIN is empty in .env"
  [ "$(env_value SYNC_DOMAIN)" != "sync.example.com" ] || fail "SYNC_DOMAIN in .env is still the example"
  [ -n "$(env_value SYNC_ACCESS_KEY)" ] || log "Warning: SYNC_ACCESS_KEY is empty, so anyone who finds the server can store data on it"
  docker network inspect web-proxy >/dev/null 2>&1 || fail "the external Docker network web-proxy doesn't exist (docker network create web-proxy)"
  compose config --quiet || fail "$COMPOSE_FILE doesn't validate"
  log "Preflight passed"
}

health_url() { echo "http://127.0.0.1:$(env_value SYNC_HOST_PORT | grep . || echo 18090)/v1/health"; }

# Waits for the container to report healthy and the health endpoint to answer through the host port.
verify() {
  step "Verify"
  url="$(health_url)"
  waited=0
  while [ "$waited" -lt "$HEALTH_TIMEOUT" ]; do
    state="$(docker inspect -f '{{.State.Health.Status}}' cairn_sync 2>/dev/null || echo missing)"
    if [ "$state" = healthy ] && curl -fsS --noproxy '*' --max-time 5 "$url" 2>/dev/null | grep -q '"ok":true'; then
      log "Healthy: $url"
      return 0
    fi
    sleep 3
    waited=$((waited + 3))
  done
  log "Not healthy after ${HEALTH_TIMEOUT}s (container: $state)"
  compose logs --tail 40 sync || true
  return 1
}

release() {
  compose up -d --no-build
}

case "$MODE" in
  check)
    preflight
    log "Nothing was changed"
    exit 0
    ;;
  rollback)
    preflight
    docker image inspect "$IMAGE:previous-good" >/dev/null 2>&1 || fail "there is no previous verified release to go back to"
    step "Roll back"
    docker tag "$IMAGE:previous-good" "$IMAGE:production"
    release
    verify || fail "the previous release isn't healthy either; see the logs above"
    docker tag "$IMAGE:production" "$IMAGE:last-good"
    log "Rolled back"
    exit 0
    ;;
esac

preflight

if [ "$PULL" -eq 1 ]; then
  step "Pull"
  git pull --ff-only
fi

step "Build"
# The running container keeps serving while the new image builds.
compose build

step "Release"
if docker image inspect "$IMAGE:last-good" >/dev/null 2>&1; then
  docker tag "$IMAGE:last-good" "$IMAGE:previous-good"
fi
release

if verify; then
  docker tag "$IMAGE:production" "$IMAGE:last-good"
  docker image prune -f >/dev/null 2>&1 || true
  step "Done"
  log "Deployed $(git rev-parse --short HEAD 2>/dev/null || echo 'this checkout') to https://$(env_value SYNC_DOMAIN)"
  exit 0
fi

if docker image inspect "$IMAGE:previous-good" >/dev/null 2>&1; then
  step "Roll back"
  docker tag "$IMAGE:previous-good" "$IMAGE:production"
  release
  verify && fail "the new release failed verification and the previous one is back" || true
  fail "the new release failed verification, and so did the previous one"
fi
fail "the first release failed verification; nothing to roll back to (docker compose -f $COMPOSE_FILE logs sync)"
