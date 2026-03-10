# Port Allocations

| Port | Service           | Protocol | Access              |
|------|-------------------|----------|---------------------|
| 22   | SSH               | TCP      | LAN + Tailscale     |
| 2222 | Forgejo SSH       | TCP      | LAN + Tailscale     |
| 3000 | Grafana           | TCP      | LAN + Tailscale     |
| 3001 | Forgejo Web       | TCP      | LAN + Tailscale     |
| 3100 | Loki              | TCP      | Internal (Docker)   |
| 8080 | Healthchecks      | TCP      | Internal (Docker)   |
| 8428 | VictoriaMetrics   | TCP      | LAN + Tailscale     |
| 8429 | vmagent           | TCP      | Internal (Docker)   |
| 8880 | vmalert           | TCP      | Internal (Docker)   |
| 9093 | Alertmanager      | TCP      | Internal (Docker)   |
| 9115 | Blackbox Exporter | TCP      | Internal (Docker)   |
| 9999 | Webhook Receiver  | TCP      | Internal (Docker)   |
