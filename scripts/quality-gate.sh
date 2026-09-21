#!/usr/bin/env bash
# Start SonarQube if needed, then scan the project.
set -euo pipefail

cd "$(dirname "$0")/.."

export SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"

# macOS may need help finding Java installed by Homebrew.
if ! java -version >/dev/null 2>&1; then
  for java_root in /opt/homebrew/opt/openjdk /usr/local/opt/openjdk; do
    if [ -x "${java_root}/bin/java" ]; then
      export JAVA_HOME="${java_root}"
      export PATH="${JAVA_HOME}/bin:${PATH}"
      break
    fi
  done
fi

if ! java -version >/dev/null 2>&1; then
  echo "ERROR: Java is required by the SonarQube scanner." >&2
  echo "Install a JDK, then run this script again." >&2
  exit 1
fi

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
