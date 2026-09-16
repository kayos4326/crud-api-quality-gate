#!/usr/bin/env bash
# Blocks until the SonarQube server reports status UP, or gives up.
set -euo pipefail

HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"
TIMEOUT_SECONDS="${SONAR_STARTUP_TIMEOUT:-600}"

echo "Waiting for SonarQube at ${HOST_URL} (up to ${TIMEOUT_SECONDS}s)..."
deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))

while [ "$(date +%s)" -lt "$deadline" ]; do
  status=$(curl -fsS "${HOST_URL}/api/system/status" 2>/dev/null \
            | sed -n 's/.*"status":"\([A-Z]*\)".*/\1/p' || true)
  case "$status" in
    UP)
      echo "SonarQube is UP."
      exit 0
      ;;
    "")
      printf '.' ;;
    *)
      printf '[%s]' "$status" ;;
  esac
  sleep 5
done

echo
echo "ERROR: SonarQube did not come up within ${TIMEOUT_SECONDS}s." >&2
exit 1
