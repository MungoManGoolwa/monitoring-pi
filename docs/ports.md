# Port Allocations

| Port | Service           | Protocol | Access              |
|------|-------------------|----------|---------------------|
| 22   | SSH               | TCP      | LAN + Tailscale     |
| 3000 | Grafana           | TCP      | LAN + Tailscale     |
| 3100 | Loki              | TCP      | Internal (Docker)   |
| 8080 | Healthchecks      | TCP      | Internal (Docker)   |
| 8428 | VictoriaMetrics   | TCP      | LAN + Tailscale     |
| 8429 | vmagent           | TCP      | Internal (Docker)   |
| 9093 | Alertmanager      | TCP      | Internal (Docker)   |
| 9115 | Blackbox Exporter | TCP      | Internal (Docker)   |

## UFW Rules

Ports 3000 and 8428 are exposed to:
- 192.168.1.0/24 (local network)
- 100.64.0.0/10 (Tailscale CGNAT)
- tailscale0 interface (all traffic)

All other service ports are internal to the Docker network only.
