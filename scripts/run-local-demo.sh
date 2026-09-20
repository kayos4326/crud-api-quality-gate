#!/usr/bin/env bash
# Run the demo gate. Zero means pass; any other code means fail.
set -uo pipefail

cd "$(dirname "$0")/.."

./scripts/quality-gate.sh
gate_status=$?

echo
if [ "$gate_status" -eq 0 ]; then
  echo "QUALITY GATE PASSED - deploy.sh would proceed."
else
  echo "QUALITY GATE FAILED - deploy.sh would refuse to ship this."
fi
echo "Report: ${SONAR_HOST_URL:-http://localhost:9000}/dashboard?id=crud-api"
exit "$gate_status"
