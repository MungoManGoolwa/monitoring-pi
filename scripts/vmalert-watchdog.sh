#!/usr/bin/env bash
# vmalert-watchdog.sh — keep the Pi alert evaluator alive.
#
# vmalert evaluates ALL alert rules. If it dies, alerting goes silent while
# VictoriaMetrics keeps collecting — the exact failure that hid a VPS swap
# spike for ~25h on 2026-06-07 (vmalert had Exited 255, no auto-restart).
#
# This runs every 5 min (cron). It auto-restarts vmalert if down, and drives a
# Healthchecks dead-man switch: success ping when healthy, /fail on any restart
# event or unrecoverable failure. If the watchdog or the whole Pi stops, the
# missing pings make Healthchecks alert anyway — coverage independent of vmalert.
set -uo pipefail

NAME=vmalert
HC="http://localhost:8080/ping/9e7b88e3-a801-4db3-8467-d2857c4e320f"
LOG=/opt/monitoring/scripts/vmalert-watchdog.log

ts(){ date '+%Y-%m-%d %H:%M:%S'; }
log(){ echo "$(ts) $*" >> "$LOG" 2>/dev/null; }

healthy(){
  [ "$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null)" = "true" ] || return 1
  curl -sf -m8 http://localhost:8880/api/v1/rules 2>/dev/null | grep -q '"groups"' || return 1
  return 0
}

if healthy; then
  curl -fsS -m10 "$HC" >/dev/null 2>&1
  exit 0
fi

log "vmalert UNHEALTHY — attempting recovery"
docker start "$NAME" >/dev/null 2>&1 || docker restart "$NAME" >/dev/null 2>&1
sleep 8

if healthy; then
  log "vmalert recovered via watchdog restart"
  # Alert on the restart event so a silent/looping death is visible; next
  # healthy cycle pings success and Healthchecks auto-resolves to UP.
  curl -fsS -m10 --data "vmalert was down; watchdog restarted it $(ts)" "$HC/fail" >/dev/null 2>&1
  exit 0
else
  log "vmalert STILL DOWN after restart attempt — manual intervention needed"
  curl -fsS -m10 --data "vmalert DOWN and restart FAILED $(ts)" "$HC/fail" >/dev/null 2>&1
  exit 1
fi
