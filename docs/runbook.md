# Runbook

## Common Operations

### Start the stack
```bash
cd /opt/monitoring
docker compose up -d
```

### Stop the stack
```bash
cd /opt/monitoring
docker compose down
```

### View logs for a service
```bash
docker compose logs -f <service-name>
```

### Check service health
```bash
./scripts/healthcheck.sh
```

### Run a backup
```bash
./scripts/backup.sh
```

## Troubleshooting

### Service won't start
1. Check logs: `docker compose logs <service>`
2. Check disk space: `df -h`
3. Check memory: `free -h`
4. Check Docker: `systemctl status docker`

### High memory usage
1. Check per-container: `docker stats --no-stream`
2. VictoriaMetrics is the most memory-hungry — check retention settings
3. Restart individual service: `docker compose restart <service>`

### Can't access Grafana
1. Check UFW: `sudo ufw status`
2. Check container: `docker ps | grep grafana`
3. Check port binding: `ss -tlnp | grep 3000`

### VictoriaMetrics disk usage
```bash
du -sh /var/lib/docker/volumes/monitoring_vm-data/
```
