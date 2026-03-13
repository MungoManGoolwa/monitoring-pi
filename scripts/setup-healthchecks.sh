#!/usr/bin/env bash
# setup-healthchecks.sh - Create all musick.com.au cron job checks in Healthchecks
#
# Usage: ./setup-healthchecks.sh [API_KEY] [HC_URL]
# Defaults: HC_URL=http://192.168.1.62:8080

set -euo pipefail

API_KEY="${1:?Usage: $0 <API_KEY> [HC_URL]}"
HC_URL="${2:-http://192.168.1.62:8080}"
API="${HC_URL}/api/v3/checks/"

created=0
failed=0

create_check() {
    local name="$1"
    local schedule="$2"
    local grace="$3"
    local tags="$4"
    local tz="${5:-Australia/Brisbane}"

    local payload
    payload=$(cat <<ENDJSON
{
    "name": "${name}",
    "tags": "${tags}",
    "schedule": "${schedule}",
    "tz": "${tz}",
    "grace": ${grace},
    "channels": "*",
    "unique": ["name"]
}
ENDJSON
)

    local response
    response=$(curl -sf -X POST "${API}" \
        -H "X-Api-Key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "${payload}" 2>&1) || {
        echo "  FAILED: ${name}"
        ((failed++)) || true
        return
    }

    local uuid
    uuid=$(echo "${response}" | python3 -c "import sys,json; print(json.load(sys.stdin)['ping_url'].split('/')[-1])" 2>/dev/null || echo "???")
    echo "  OK: ${name} -> ${uuid}"
    ((created++)) || true
}

echo "=== Creating Healthchecks checks at ${HC_URL} ==="
echo ""

# ── Every minute ──────────────────────────────────────────────
echo "--- Every minute ---"
create_check "seo-audit-runner"          "* * * * *"       300   "seo"

# ── Every 5 minutes ──────────────────────────────────────────
echo "--- Every 5 minutes ---"
create_check "process-notifications"     "*/5 * * * *"     600   "notifications"
create_check "social-autoposter"         "*/5 * * * *"     600   "content"

# ── Every 15 minutes ─────────────────────────────────────────
echo "--- Every 15 minutes ---"
create_check "google-index-queue"        "*/15 * * * *"    900   "seo"
create_check "process-discovery-queue"   "*/15 * * * *"    900   "discovery"

# ── Every 30 minutes ─────────────────────────────────────────
echo "--- Every 30 minutes ---"
create_check "growth-execute"            "*/30 * * * *"    1800  "growth"

# ── Hourly ────────────────────────────────────────────────────
echo "--- Hourly ---"
create_check "aggregate-trending"        "0 * * * *"       1800  "content"

# ── Every 4-6 hours ──────────────────────────────────────────
echo "--- Every 4-6 hours ---"
create_check "discover-news-feeds"       "0 */6 * * *"     3600  "discovery"
create_check "site-operations-monitor"   "0 */6 * * *"     3600  "seo"
create_check "growth-gsc-fetch"          "0 */6 * * *"     3600  "growth"
create_check "growth-report"             "0 2,6,10,14,18,22 * * *" 3600 "growth"

# ── Daily ─────────────────────────────────────────────────────
echo "--- Daily ---"
create_check "discover-ticketmaster"     "0 2 * * *"       1800  "discovery"
create_check "import-eventbrite"         "30 2 * * *"      1800  "discovery"
create_check "discover-ai-research"      "0 3 * * *"       1800  "discovery"
create_check "discover-eventfinda"       "30 3 * * *"      1800  "discovery"
create_check "import-oztix"             "0 4 * * *"       1800  "discovery"
create_check "discover-venue-events"     "30 4 * * *"      1800  "discovery"
create_check "localise-gig-images"       "30 4,12 * * *"   1800  "content"
create_check "discover-brisbane-events"  "45 4 * * *"      1800  "discovery"
create_check "fetch-artwork"             "0 5 * * *"       1800  "content"
create_check "fetch-artist-images"       "0 5,13 * * *"    1800  "content"
create_check "discover-themusic-gigs"    "0 5 * * *"       1800  "discovery"
create_check "discover-beat-gigs"        "15 5 * * *"      1800  "discovery"
create_check "fix-affiliate-urls"        "30 5 * * *"      1800  "content"
create_check "import-moshtix"           "0 6 * * *"       1800  "discovery"
create_check "auto-blog"                "0 6 * * *"       3600  "content"
create_check "estimate-set-times"        "15 6 * * *"      1800  "content"
create_check "daily-gig-picks"          "30 6 * * *"      1800  "content"
create_check "presale-alerts"            "0 7 * * *"       1800  "notifications"
create_check "daily-video-population"    "0 7,19 * * *"    1800  "content"
create_check "daily-health-report"       "30 7 * * *"      1800  "seo"
create_check "daily_digest"             "45 7 * * *"      1800  "notifications"
create_check "daily-pending-approvals"   "0 8 * * *"       1800  "notifications"
create_check "growth-analyse"            "0 8 * * *"       3600  "growth"
create_check "notify-artist-followers"   "30 8 * * *"      1800  "notifications"
create_check "push-new-gigs"            "0 9 * * *"       1800  "notifications"
create_check "growth-experiments"        "0 9 * * *"       3600  "growth"
create_check "setlist-updater"           "0 11 * * *"      3600  "content"
create_check "backup-database"           "0 17 * * *"      3600  "backup"
create_check "backup-content"            "30 17 * * *"     3600  "backup"

# ── Weekly ────────────────────────────────────────────────────
echo "--- Weekly ---"
create_check "seo-audit"                "30 3 * * 0"      7200  "seo"
create_check "growth-broken-links"       "0 4 * * 0"       7200  "growth"
create_check "weekly-newsletter"         "0 18 * * 0"      3600  "notifications"
create_check "weekly_email"             "45 6 * * 1"      3600  "notifications"
create_check "export-weekly-stats"       "0 9 * * 1"       3600  "growth"
create_check "weekly-quiz-email"         "0 10 * * 1"      3600  "notifications"
create_check "discover-festivals"        "30 3 * * 1"      3600  "discovery"
create_check "discover-festival-lineups" "0 3 * * 3"       3600  "discovery"

echo ""
echo "=== Done: ${created} created, ${failed} failed ==="
echo ""

# Now dump all checks as a mapping for crontab integration
echo "=== Check UUID mapping (for crontab pings) ==="
curl -sf -H "X-Api-Key: ${API_KEY}" "${API}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
checks = sorted(data['checks'], key=lambda c: c['name'])
for c in checks:
    uuid = c['ping_url'].split('/')[-1]
    print(f\"{c['name']:40s} {uuid}\")
"
