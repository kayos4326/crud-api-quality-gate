#!/usr/bin/env bash
# Create the rules used by this demo.
set -euo pipefail

HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"
TOKEN="${SONAR_TOKEN:?SONAR_TOKEN must be set}"
GATE_NAME="${SONAR_GATE_NAME:-Campus CRUD API}"
PROJECT_KEY="${SONAR_PROJECT_KEY:-crud-api}"
PROJECT_NAME="${SONAR_PROJECT_NAME:-Campus CRUD API}"

api() {
  local action="$1"; shift
  curl -fsS -u "${TOKEN}:" -X POST "${HOST_URL}/api/qualitygates/${action}" "$@"
}

# SonarQube needs the project before we can attach a gate.
curl -fsS -u "${TOKEN}:" -X POST "${HOST_URL}/api/projects/create" \
     --data-urlencode "project=${PROJECT_KEY}" \
     --data-urlencode "name=${PROJECT_NAME}" >/dev/null 2>&1 \
  && echo "Created project '${PROJECT_KEY}'." \
  || echo "Project '${PROJECT_KEY}' already exists."

# Recreate the gate so every run starts the same way.
api destroy --data-urlencode "name=${GATE_NAME}" >/dev/null 2>&1 || true

echo "Creating quality gate '${GATE_NAME}'..."
api create --data-urlencode "name=${GATE_NAME}" >/dev/null

# Helper for adding one gate rule
add_condition() {
  echo "  condition: $1 $2 $3"
  api create_condition \
    --data-urlencode "gateName=${GATE_NAME}" \
    --data-urlencode "metric=$1" \
    --data-urlencode "op=$2" \
    --data-urlencode "error=$3" >/dev/null
}

# SonarQube stores A as 1, B as 2, and so on.
add_condition security_rating          GT 1
add_condition reliability_rating       GT 1
add_condition blocker_violations       GT 0
add_condition duplicated_lines_density GT 3

# This project does not produce coverage or hotspot-review data.
drop_condition() {
  local metric="$1"
  local id
  id=$(curl -fsS -u "${TOKEN}:" "${HOST_URL}/api/qualitygates/show?name=$(printf %s "${GATE_NAME}" | sed 's/ /%20/g')" \
        | /usr/bin/python3 -c "
import sys, json
conds = json.load(sys.stdin).get('conditions', [])
print(next((c['id'] for c in conds if c['metric'] == '${metric}'), ''))
" 2>/dev/null)
  if [ -n "$id" ]; then
    echo "  removing seeded condition: ${metric}"
    curl -fsS -u "${TOKEN}:" -X POST "${HOST_URL}/api/qualitygates/delete_condition" \
         --data-urlencode "id=${id}" >/dev/null
  fi
}

drop_condition new_coverage
drop_condition new_security_hotspots_reviewed

echo "Attaching '${GATE_NAME}' to project '${PROJECT_KEY}'..."
api select \
  --data-urlencode "gateName=${GATE_NAME}" \
  --data-urlencode "projectKey=${PROJECT_KEY}" >/dev/null

echo "Quality gate ready."
