#!/usr/bin/env bash
# Create a Grafana annotation (e.g., on deploy or git push)
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_API_KEY="${GRAFANA_API_KEY:-}"

TEXT="${1:-Deployment}"
TAGS="${2:-deploy}"

if [ -z "$GRAFANA_API_KEY" ]; then
  echo "Error: GRAFANA_API_KEY not set"
  exit 1
fi

curl -s -X POST "${GRAFANA_URL}/api/annotations" \
  -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"text\": \"${TEXT}\",
    \"tags\": [\"${TAGS}\"]
  }"

echo ""
echo "Annotation created: ${TEXT}"
