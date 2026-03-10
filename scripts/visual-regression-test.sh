#!/usr/bin/env bash
# Run visual regression tests
set -euo pipefail
cd /opt/monitoring
docker compose --profile testing run --rm visual-regression 2>&1
