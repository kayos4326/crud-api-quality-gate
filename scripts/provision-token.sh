#!/usr/bin/env bash
# Prepare the local admin account and return a scan token.
set -euo pipefail

HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"
ADMIN_PASSWORD="${SONAR_ADMIN_PASSWORD:-Demo-Sonar-2026}"
TOKEN_NAME="${SONAR_TOKEN_NAME:-crud-api-ci}"

log() { echo "$@" >&2; }

if curl -fsS -u "admin:${ADMIN_PASSWORD}" "${HOST_URL}/api/authentication/validate" \
     | grep -q '"valid":true'; then
  log "Admin password already set."
else
  log "Changing the default admin password..."
  curl -fsS -u "admin:admin" -X POST "${HOST_URL}/api/users/change_password" \
       --data-urlencode "login=admin" \
       --data-urlencode "previousPassword=admin" \
       --data-urlencode "password=${ADMIN_PASSWORD}" >/dev/null
fi

# Reuse the token name on every run.
curl -fsS -u "admin:${ADMIN_PASSWORD}" -X POST "${HOST_URL}/api/user_tokens/revoke" \
     --data-urlencode "name=${TOKEN_NAME}" >/dev/null 2>&1 || true

log "Generating analysis token '${TOKEN_NAME}'..."
curl -fsS -u "admin:${ADMIN_PASSWORD}" -X POST "${HOST_URL}/api/user_tokens/generate" \
     --data-urlencode "name=${TOKEN_NAME}" \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p'
