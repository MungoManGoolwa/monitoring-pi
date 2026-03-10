#!/usr/bin/env bash
# Backup monitoring data and configuration
set -euo pipefail

BACKUP_DIR="/opt/monitoring/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="monitoring-backup-${TIMESTAMP}"

mkdir -p "${BACKUP_DIR}"

echo "Starting backup: ${BACKUP_NAME}"

# Backup configs (not data volumes)
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" \
  -C /opt/monitoring \
  --exclude='*/data/*' \
  --exclude='backups' \
  --exclude='.git' \
  docker-compose.yml \
  .env \
  victoria-metrics/config \
  grafana/provisioning \
  grafana/dashboards \
  loki/config \
  alertmanager/config \
  blackbox-exporter/config \
  vmagent/config

# Prune backups older than 30 days
find "${BACKUP_DIR}" -name "monitoring-backup-*.tar.gz" -mtime +30 -delete

echo "Backup complete: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
