# Architecture

## Overview

The monitoring stack runs on a Raspberry Pi CM4 (monitoring-pi) and provides
observability for musick.com.au and associated infrastructure.

## Components

```
┌─────────────────────────────────────────────────────┐
│  monitoring-pi (192.168.1.62 / Tailscale)           │
│                                                      │
│  ┌──────────┐  ┌────────────────┐  ┌──────┐         │
│  │ Grafana  │←─│ VictoriaMetrics│←─│vmagent│         │
│  │  :3000   │  │    :8428       │  │ :8429 │         │
│  └────┬─────┘  └────────────────┘  └───┬───┘         │
│       │                                │             │
│  ┌────┴─────┐  ┌──────────────┐  ┌─────┴────┐       │
│  │  Loki    │  │ Alertmanager │  │ Blackbox  │       │
│  │  :3100   │  │   :9093      │  │  :9115    │       │
│  └──────────┘  └──────────────┘  └─────┬────┘       │
│                                        │             │
│  ┌──────────────┐                      │             │
│  │ Healthchecks │                      │             │
│  │   :8080      │                      │             │
│  └──────────────┘                      │             │
└────────────────────────────────────────┼─────────────┘
                                         │
                              ┌──────────┴──────────┐
                              │  musick.com.au VPS   │
                              │  (BinaryLane)        │
                              └─────────────────────┘
```

## Data Flow

1. **vmagent** scrapes metrics from blackbox-exporter and remote targets
2. **VictoriaMetrics** stores time-series data (12-month retention)
3. **Grafana** queries VictoriaMetrics and Loki for visualisation
4. **Blackbox Exporter** probes musick.com.au for uptime/latency
5. **Alertmanager** sends notifications on alert conditions
6. **Loki** aggregates logs from all containers
7. **Healthchecks** monitors cron jobs and periodic tasks

## Access

- Local network: 192.168.1.62
- Remote (Tailscale): 100.121.227.39
- All services accessible via both addresses
