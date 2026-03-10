#!/usr/bin/env bash
# Check health of all monitoring services
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

check_service() {
  local name=$1
  local url=$2
  if curl -sf --max-time 5 "$url" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} ${name} is healthy"
  else
    echo -e "${RED}✗${NC} ${name} is down"
  fi
}

echo "=== Monitoring Stack Health Check ==="
echo ""
check_service "VictoriaMetrics" "http://localhost:8428/health"
check_service "Grafana"         "http://localhost:3000/api/health"
check_service "Loki"            "http://localhost:3100/ready"
check_service "Alertmanager"    "http://localhost:9093/-/healthy"
check_service "Blackbox"        "http://localhost:9115/metrics"
check_service "Healthchecks"    "http://localhost:8080"
echo ""
echo "=== Docker Containers ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
