#!/usr/bin/env bash
# Runs the whole gate: start SonarQube if needed, scan, and exit non-zero when
# the quality gate fails. deploy.sh calls this before it transfers anything.
set -euo pipefail

cd "$(dirname "$0")/.."

export SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"

if ! curl -fsS "${SONAR_HOST_URL}/api/system/status" >/dev/null 2>&1; then
  echo "==> Starting SonarQube"
  docker compose -f docker-compose.sonarqube.yml up -d
fi

./scripts/wait-for-sonarqube.sh

SONAR_TOKEN="$(./scripts/provision-token.sh)"
export SONAR_TOKEN

./scripts/setup-quality-gate.sh

echo "==> Scanning"
npx sonar-scanner \
  -Dsonar.host.url="${SONAR_HOST_URL}" \
  -Dsonar.token="${SONAR_TOKEN}" \
  -Dsonar.qualitygate.wait=true
