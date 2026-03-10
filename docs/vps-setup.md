# BinaryLane VPS (musick-vps) Setup

## Host
- IP: 103.249.238.229
- Tailscale IP: 100.122.197.106
- Hostname: rexe
- OS: Ubuntu 24.04.4 LTS (amd64)

## Installed Services

### node_exporter (systemd)
- Listens on 127.0.0.1:9100
- Exports ~620 system metrics (CPU, memory, disk, network, etc.)

### vmagent (Docker container)
- Scrapes node_exporter every 30s
- Remote writes to monitoring-pi VictoriaMetrics at 100.121.227.39:8428
- Labels: host=musick-vps, environment=production

### Tailscale
- Provides encrypted tunnel for metrics shipping
- No public ports exposed for monitoring

## Config Files
- `/etc/vmagent/config.yml` — scrape configuration
- `/etc/systemd/system/node_exporter.service` — node_exporter systemd unit

## Useful Commands
```bash
# Check node_exporter
systemctl status node_exporter
curl http://127.0.0.1:9100/metrics | head

# Check vmagent
docker ps | grep vmagent
docker logs vmagent
curl http://127.0.0.1:8429/targets

# Restart vmagent
docker restart vmagent
```
