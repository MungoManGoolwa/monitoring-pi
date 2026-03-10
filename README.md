# Monitoring Stack — monitoring-pi

Centralised monitoring and observability stack running on a Raspberry Pi CM4,
providing metrics, logging, alerting, and uptime monitoring for musick.com.au
and associated infrastructure.

## Services

| Service           | Port | Role                                          |
|-------------------|------|-----------------------------------------------|
| Grafana           | 3000 | Dashboards and visualisation                  |
| VictoriaMetrics   | 8428 | Time-series database (Prometheus-compatible)  |
| Loki              | 3100 | Log aggregation                               |
| Alertmanager      | 9093 | Alert routing and notifications               |
| Blackbox Exporter | 9115 | HTTP/TCP/ICMP endpoint probing                |
| Healthchecks      | 8080 | Cron job and periodic task monitoring          |
| vmagent           | 8429 | Metrics scraping and remote write             |

## Prerequisites

- Docker Engine 29+ with Compose plugin
- `.env` file (copy from `.env.example` and fill in values)

## Quick Start

```bash
# Copy and configure environment
cp .env.example .env
vi .env

# Start all services
docker compose up -d

# Check health
./scripts/healthcheck.sh
```

## Stop

```bash
docker compose down
```

## Adding a New Monitored Service

1. Add a scrape target to `vmagent/config/vmagent.yml`
2. If HTTP probing, add a target to the blackbox scrape config
3. Create or update a Grafana dashboard in `grafana/dashboards/`
4. Restart vmagent: `docker compose restart vmagent`

## Backup

```bash
./scripts/backup.sh
```

Backs up all configuration files (not data volumes). Backups older than 30
days are automatically pruned. Data volumes should be backed up separately
if persistence beyond the retention period is needed.

## Git Commits → Grafana Annotations

Use `scripts/annotate-grafana.sh` to create Grafana annotations on deploy:

```bash
GRAFANA_API_KEY=<key> ./scripts/annotate-grafana.sh "Deployed v1.2.3" "deploy"
```

This can be triggered by a Forgejo webhook on push to correlate code changes
with metric shifts.

## Documentation

- [Architecture](docs/architecture.md) — system diagram and data flow
- [Runbook](docs/runbook.md) — common operations and troubleshooting
- [Port Allocations](docs/ports.md) — full port map and firewall rules

## Access

| Method    | Address         |
|-----------|-----------------|
| Local LAN | 192.168.1.62    |
| Tailscale | 100.121.227.39  |
