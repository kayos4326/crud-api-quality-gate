#!/usr/bin/env bash
# Creates the project's quality gate and attaches it to the project.
# Safe to re-run: the gate is dropped and rebuilt each time.
#
# The conditions below are deliberately set on OVERALL code rather than on
# new code. See docs/DEMO_SCRIPT.md for why that matters.
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

# A gate can only be attached to a project that already exists, and on a fresh
# server the project is not created until the first analysis. Create it up front
# so the ordering does not matter. Harmless if it is already there.
curl -fsS -u "${TOKEN}:" -X POST "${HOST_URL}/api/projects/create" \
     --data-urlencode "project=${PROJECT_KEY}" \
     --data-urlencode "name=${PROJECT_NAME}" >/dev/null 2>&1 \
  && echo "Created project '${PROJECT_KEY}'." \
  || echo "Project '${PROJECT_KEY}' already exists."

# Start from a known state.
api destroy --data-urlencode "name=${GATE_NAME}" >/dev/null 2>&1 || true

echo "Creating quality gate '${GATE_NAME}'..."
api create --data-urlencode "name=${GATE_NAME}" >/dev/null

# metric | operator | threshold  (GT = fail above, LT = fail below)
add_condition() {
  echo "  condition: $1 $2 $3"
  api create_condition \
    --data-urlencode "gateName=${GATE_NAME}" \
    --data-urlencode "metric=$1" \
    --data-urlencode "op=$2" \
    --data-urlencode "error=$3" >/dev/null
}

# 1 = A, 2 = B ... so "worse than A" is GT 1.
add_condition security_rating          GT 1
add_condition reliability_rating       GT 1
add_condition blocker_violations       GT 0
add_condition duplicated_lines_density GT 3

# No coverage condition. The API was written across Weeks 3-5 with no unit
# tests, so gating on coverage would fail the clean baseline too. Adding tests
# is the honest next step; see "What we did not do" in the README.

echo "Attaching '${GATE_NAME}' to project '${PROJECT_KEY}'..."
api select \
  --data-urlencode "gateName=${GATE_NAME}" \
  --data-urlencode "projectKey=${PROJECT_KEY}" >/dev/null

echo "Quality gate ready."
