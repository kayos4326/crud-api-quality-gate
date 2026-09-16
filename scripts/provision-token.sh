#!/usr/bin/env bash
# Mints a SonarQube analysis token and prints it on stdout (nothing else goes
# to stdout, so this is safe to capture with $(...)).
#
# A fresh SonarQube refuses API calls until the default admin password is
# changed, so that is done first and is safe to re-run.
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

# Revoking first makes the script idempotent: SonarQube will not re-issue a
# token under a name that already exists.
curl -fsS -u "admin:${ADMIN_PASSWORD}" -X POST "${HOST_URL}/api/user_tokens/revoke" \
     --data-urlencode "name=${TOKEN_NAME}" >/dev/null 2>&1 || true

log "Generating analysis token '${TOKEN_NAME}'..."
curl -fsS -u "admin:${ADMIN_PASSWORD}" -X POST "${HOST_URL}/api/user_tokens/generate" \
     --data-urlencode "name=${TOKEN_NAME}" \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p'
