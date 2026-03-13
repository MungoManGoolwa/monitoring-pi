#!/usr/bin/env bash
# update-musick-crontab.sh - Update musick.com.au VPS crontab with Healthchecks pings
#
# Run this ON the VPS (103.100.38.234) as the user whose crontab manages the cron jobs.
#
# Usage: bash update-musick-crontab.sh [--dry-run]
#
# This script:
# 1. Backs up the current crontab
# 2. Adds Healthchecks ping calls to each cron job
# 3. Installs the updated crontab
#
# Ping pattern: command && curl -fsS -m 10 --retry 5 PING_URL >/dev/null
# On failure:   command || curl -fsS -m 10 --retry 5 PING_URL/fail >/dev/null

set -euo pipefail

HC_URL="http://192.168.1.62:8080/ping"
DRY_RUN="${1:-}"

# UUID mapping - check name to UUID
declare -A CHECKS=(
    ["aggregate-trending"]="eb2c25bc-d6bc-4ee5-90f2-33ad24649357"
    ["auto-blog"]="9d651ce5-684b-4288-aa62-e216452b37a9"
    ["backup-content"]="0e2fff1b-d9ed-4a32-96c9-4cb95bb6bbf3"
    ["backup-database"]="b96d2479-80a7-4f34-9062-993b005b1d67"
    ["daily-gig-picks"]="147edf30-1e9e-47d3-a271-2224d5aa4632"
    ["daily-health-report"]="b33da428-8bae-4bcd-aa77-341ba2c5833f"
    ["daily-pending-approvals"]="393ad226-0918-4c27-92ff-949e7435f347"
    ["daily-video-population"]="7a8e57e9-b540-4cfe-bee6-72cfeb4a1e53"
    ["daily_digest"]="8030050c-fe55-42a7-a10e-def9ae060af6"
    ["discover-ai-research"]="19325c6d-db92-4139-be87-5ab28de33f8f"
    ["discover-beat-gigs"]="890fd3ce-81fe-4d4f-ae7e-1de3037b2912"
    ["discover-brisbane-events"]="d2cca113-4082-4b94-8ec6-204712eb64a2"
    ["discover-eventfinda"]="c3686dd1-6e25-4cd8-bc18-45ed77ef92e3"
    ["discover-festival-lineups"]="9e827ca6-7d11-41ac-8eb6-86fb20a83f95"
    ["discover-festivals"]="3e2bcab2-8777-44fe-abf6-5d2187b195c1"
    ["discover-news-feeds"]="a8ab2be9-e52d-4e39-86a2-d3fb77908ac1"
    ["discover-themusic-gigs"]="fbe5d7b0-2f44-4899-b2fe-d3841a6f5003"
    ["discover-ticketmaster"]="492e397f-df61-44bf-91d9-6f26f4fdba12"
    ["discover-venue-events"]="c1fc19c6-67a2-4d4c-adb3-9c793afd2a04"
    ["estimate-set-times"]="673c2257-896c-4d97-917a-57c17458ec7e"
    ["export-weekly-stats"]="9d27d7e6-3df6-4878-b429-24d4fc82ce09"
    ["fetch-artist-images"]="0b1afe4d-79a6-45cc-9f01-6c8375a4535b"
    ["fetch-artwork"]="10a160f6-709b-491e-af22-1466a3ff724c"
    ["fix-affiliate-urls"]="95f5741e-c342-462f-b82d-53dbd00fc93e"
    ["google-index-queue"]="f2a433db-c128-4d3f-86ac-7abec2645625"
    ["growth-analyse"]="60ad4cfc-256a-4459-bbef-979f0fcfc104"
    ["growth-broken-links"]="c0eba049-67b5-4490-85c4-1587576acc02"
    ["growth-execute"]="bb611690-373b-488b-bd85-3192ce669114"
    ["growth-experiments"]="038b6473-ab38-4428-84f0-c29a68ca74ec"
    ["growth-gsc-fetch"]="59cdac76-42d6-40e6-873c-36cc4e1852ba"
    ["growth-report"]="9702e3c2-108d-4db9-867a-69ab8396ec74"
    ["import-eventbrite"]="c5afd695-11f2-4702-b04c-2b8690cc8568"
    ["import-moshtix"]="0b562c5c-527b-4036-aa1a-7c3e51f02010"
    ["import-oztix"]="9f57ba2c-ad60-43f8-b109-6fc10021d7ac"
    ["localise-gig-images"]="06e0adcf-9840-4e37-a739-c1905c6367aa"
    ["notify-artist-followers"]="42c64c1c-643b-41d7-958d-7e6316ae1dc6"
    ["presale-alerts"]="9e787442-4d38-47a9-b516-e3c6cc2bc986"
    ["process-discovery-queue"]="f4d17276-2832-4803-833a-bfb829900b93"
    ["process-notifications"]="a1b4bd8f-44a9-4d88-8072-096c7214286b"
    ["push-new-gigs"]="27d1918b-16ec-4e4b-921c-a11b24db3543"
    ["seo-audit"]="e296f72a-e528-47c8-a218-761a0819d201"
    ["seo-audit-runner"]="7120550a-6aa9-494a-8725-0771a1255702"
    ["setlist-updater"]="08948892-8dff-45b7-8bd4-2a85fde67d74"
    ["site-operations-monitor"]="d8949c16-ef66-4910-80bf-1c374e0dc455"
    ["social-autoposter"]="b0c55904-cbf8-4cf1-9d07-e2ab719bcf08"
    ["weekly-newsletter"]="7e3d6f16-74e1-48ef-a936-b562a1e423c0"
    ["weekly-quiz-email"]="d8f558e3-fab5-4638-8692-b1c826a56362"
    ["weekly_email"]="568ac503-b7fd-4ecb-b4c0-f9aa0c6631d9"
)

ping_cmd() {
    local uuid="$1"
    echo "curl -fsS -m 10 --retry 5 -o /dev/null ${HC_URL}/${uuid}"
}

fail_cmd() {
    local uuid="$1"
    echo "curl -fsS -m 10 --retry 5 -o /dev/null ${HC_URL}/${uuid}/fail"
}

start_cmd() {
    local uuid="$1"
    echo "curl -fsS -m 10 --retry 5 -o /dev/null ${HC_URL}/${uuid}/start"
}

# Wrap a command with healthchecks start/success/fail pings
# Usage: wrap_with_ping <check-name> <original-command>
wrap_with_ping() {
    local name="$1"
    local cmd="$2"
    local uuid="${CHECKS[$name]:-}"

    if [[ -z "$uuid" ]]; then
        echo "WARNING: No UUID found for check '${name}'" >&2
        echo "$cmd"
        return
    fi

    # Pattern: signal start, run command, ping success or fail
    echo "$(start_cmd "$uuid") && { ${cmd} && $(ping_cmd "$uuid") || $(fail_cmd "$uuid"); }"
}

echo "=== musick.com.au Crontab Updater ==="
echo ""

# Backup current crontab
BACKUP="/tmp/crontab-backup-$(date +%Y%m%d-%H%M%S).txt"
crontab -l > "$BACKUP" 2>/dev/null || true
echo "Backed up current crontab to: $BACKUP"

# Generate new crontab
NEWCRON="/tmp/crontab-new.txt"
cat > "$NEWCRON" << 'HEADER'
# musick.com.au cron jobs
# Updated with Healthchecks monitoring (http://192.168.1.62:8080)
# Each job pings /start before running, /success on completion, /fail on error
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

HC=http://192.168.1.62:8080/ping
HEADER

echo "" >> "$NEWCRON"

# Helper to add a cron line
add_cron() {
    local schedule="$1"
    local name="$2"
    local cmd="$3"
    local uuid="${CHECKS[$name]}"

    # Write the cron entry with start ping, command, then success/fail ping
    cat >> "$NEWCRON" << EOF
# ${name}
${schedule} curl -fsS -m 10 --retry 5 -o /dev/null \$HC/${uuid}/start && { ${cmd} && curl -fsS -m 10 --retry 5 -o /dev/null \$HC/${uuid} || curl -fsS -m 10 --retry 5 -o /dev/null \$HC/${uuid}/fail; }

EOF
}

echo "Generating crontab entries..."

# NOTE: You MUST replace the placeholder commands below with the actual commands
# from your current crontab. The format is:
#   add_cron "SCHEDULE" "CHECK-NAME" "ACTUAL_COMMAND_HERE"
#
# The script wraps each command with:
#   curl .../start && { COMMAND && curl .../success || curl .../fail; }

# ── Every minute ──
add_cron "* * * * *"         "seo-audit-runner"          "cd /var/www/musick && php artisan seo:audit-runner 2>&1 | logger -t seo-audit-runner"

# ── Every 5 minutes ──
add_cron "*/5 * * * *"       "process-notifications"     "cd /var/www/musick && php artisan notifications:process 2>&1 | logger -t process-notifications"
add_cron "*/5 * * * *"       "social-autoposter"         "cd /var/www/musick && php artisan social:autopost 2>&1 | logger -t social-autoposter"

# ── Every 15 minutes ──
add_cron "*/15 * * * *"      "google-index-queue"        "cd /var/www/musick && php artisan google:index-queue 2>&1 | logger -t google-index-queue"
add_cron "*/15 * * * *"      "process-discovery-queue"   "cd /var/www/musick && php artisan discovery:process-queue 2>&1 | logger -t process-discovery-queue"

# ── Every 30 minutes ──
add_cron "*/30 * * * *"      "growth-execute"            "cd /var/www/musick && php artisan growth:execute 2>&1 | logger -t growth-execute"

# ── Hourly ──
add_cron "0 * * * *"         "aggregate-trending"        "cd /var/www/musick && php artisan trending:aggregate 2>&1 | logger -t aggregate-trending"

# ── Every 4-6 hours ──
add_cron "0 */6 * * *"       "discover-news-feeds"       "cd /var/www/musick && php artisan discover:news-feeds 2>&1 | logger -t discover-news-feeds"
add_cron "0 */6 * * *"       "site-operations-monitor"   "cd /var/www/musick && php artisan site:operations-monitor 2>&1 | logger -t site-operations-monitor"
add_cron "0 */6 * * *"       "growth-gsc-fetch"          "cd /var/www/musick && php artisan growth:gsc-fetch 2>&1 | logger -t growth-gsc-fetch"
add_cron "0 2,6,10,14,18,22 * * *" "growth-report"      "cd /var/www/musick && php artisan growth:report 2>&1 | logger -t growth-report"

# ── Daily ──
add_cron "0 2 * * *"         "discover-ticketmaster"     "cd /var/www/musick && php artisan discover:ticketmaster 2>&1 | logger -t discover-ticketmaster"
add_cron "30 2 * * *"        "import-eventbrite"         "cd /var/www/musick && php artisan import:eventbrite 2>&1 | logger -t import-eventbrite"
add_cron "0 3 * * *"         "discover-ai-research"      "cd /var/www/musick && php artisan discover:ai-research 2>&1 | logger -t discover-ai-research"
add_cron "30 3 * * *"        "discover-eventfinda"       "cd /var/www/musick && php artisan discover:eventfinda 2>&1 | logger -t discover-eventfinda"
add_cron "0 4 * * *"         "import-oztix"              "cd /var/www/musick && php artisan import:oztix 2>&1 | logger -t import-oztix"
add_cron "30 4 * * *"        "discover-venue-events"     "cd /var/www/musick && php artisan discover:venue-events 2>&1 | logger -t discover-venue-events"
add_cron "30 4,12 * * *"     "localise-gig-images"       "cd /var/www/musick && php artisan gigs:localise-images 2>&1 | logger -t localise-gig-images"
add_cron "45 4 * * *"        "discover-brisbane-events"  "cd /var/www/musick && php artisan discover:brisbane-events 2>&1 | logger -t discover-brisbane-events"
add_cron "0 5 * * *"         "fetch-artwork"             "cd /var/www/musick && php artisan artwork:fetch 2>&1 | logger -t fetch-artwork"
add_cron "0 5,13 * * *"      "fetch-artist-images"       "cd /var/www/musick && php artisan artists:fetch-images 2>&1 | logger -t fetch-artist-images"
add_cron "0 5 * * *"         "discover-themusic-gigs"    "cd /var/www/musick && php artisan discover:themusic-gigs 2>&1 | logger -t discover-themusic-gigs"
add_cron "15 5 * * *"        "discover-beat-gigs"        "cd /var/www/musick && php artisan discover:beat-gigs 2>&1 | logger -t discover-beat-gigs"
add_cron "30 5 * * *"        "fix-affiliate-urls"        "cd /var/www/musick && php artisan affiliates:fix-urls 2>&1 | logger -t fix-affiliate-urls"
add_cron "0 6 * * *"         "import-moshtix"            "cd /var/www/musick && php artisan import:moshtix 2>&1 | logger -t import-moshtix"
add_cron "0 6 * * *"         "auto-blog"                 "cd /var/www/musick && php artisan blog:auto 2>&1 | logger -t auto-blog"
add_cron "15 6 * * *"        "estimate-set-times"        "cd /var/www/musick && php artisan gigs:estimate-set-times 2>&1 | logger -t estimate-set-times"
add_cron "30 6 * * *"        "daily-gig-picks"           "cd /var/www/musick && php artisan gigs:daily-picks 2>&1 | logger -t daily-gig-picks"
add_cron "0 7 * * *"         "presale-alerts"            "cd /var/www/musick && php artisan presale:alerts 2>&1 | logger -t presale-alerts"
add_cron "0 7,19 * * *"      "daily-video-population"    "cd /var/www/musick && php artisan videos:daily-population 2>&1 | logger -t daily-video-population"
add_cron "30 7 * * *"        "daily-health-report"       "cd /var/www/musick && php artisan health:daily-report 2>&1 | logger -t daily-health-report"
add_cron "45 7 * * *"        "daily_digest"              "cd /var/www/musick && php artisan digest:daily 2>&1 | logger -t daily_digest"
add_cron "0 8 * * *"         "daily-pending-approvals"   "cd /var/www/musick && php artisan approvals:daily-pending 2>&1 | logger -t daily-pending-approvals"
add_cron "0 8 * * *"         "growth-analyse"            "cd /var/www/musick && php artisan growth:analyse 2>&1 | logger -t growth-analyse"
add_cron "30 8 * * *"        "notify-artist-followers"   "cd /var/www/musick && php artisan artists:notify-followers 2>&1 | logger -t notify-artist-followers"
add_cron "0 9 * * *"         "push-new-gigs"             "cd /var/www/musick && php artisan gigs:push-new 2>&1 | logger -t push-new-gigs"
add_cron "0 9 * * *"         "growth-experiments"        "cd /var/www/musick && php artisan growth:experiments 2>&1 | logger -t growth-experiments"
add_cron "0 11 * * *"        "setlist-updater"           "cd /var/www/musick && php artisan setlists:update 2>&1 | logger -t setlist-updater"
add_cron "0 17 * * *"        "backup-database"           "cd /var/www/musick && php artisan backup:database 2>&1 | logger -t backup-database"
add_cron "30 17 * * *"       "backup-content"            "cd /var/www/musick && php artisan backup:content 2>&1 | logger -t backup-content"

# ── Weekly ──
add_cron "30 3 * * 0"        "seo-audit"                 "cd /var/www/musick && php artisan seo:audit 2>&1 | logger -t seo-audit"
add_cron "0 4 * * 0"         "growth-broken-links"       "cd /var/www/musick && php artisan growth:broken-links 2>&1 | logger -t growth-broken-links"
add_cron "0 18 * * 0"        "weekly-newsletter"         "cd /var/www/musick && php artisan newsletter:weekly 2>&1 | logger -t weekly-newsletter"
add_cron "45 6 * * 1"        "weekly_email"              "cd /var/www/musick && php artisan email:weekly 2>&1 | logger -t weekly_email"
add_cron "0 9 * * 1"         "export-weekly-stats"       "cd /var/www/musick && php artisan stats:export-weekly 2>&1 | logger -t export-weekly-stats"
add_cron "0 10 * * 1"        "weekly-quiz-email"         "cd /var/www/musick && php artisan quiz:weekly-email 2>&1 | logger -t weekly-quiz-email"
add_cron "30 3 * * 1"        "discover-festivals"        "cd /var/www/musick && php artisan discover:festivals 2>&1 | logger -t discover-festivals"
add_cron "0 3 * * 3"         "discover-festival-lineups" "cd /var/www/musick && php artisan discover:festival-lineups 2>&1 | logger -t discover-festival-lineups"

echo ""
echo "Generated new crontab at: $NEWCRON"
echo "Total entries: $(grep -c '^[^#]' "$NEWCRON" | head -1)"
echo ""

if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo "=== DRY RUN - showing generated crontab ==="
    echo ""
    cat "$NEWCRON"
    echo ""
    echo "To install: crontab $NEWCRON"
else
    echo "IMPORTANT: Before installing, you must:"
    echo "  1. Review $NEWCRON"
    echo "  2. Replace the placeholder artisan commands with your ACTUAL commands"
    echo "     (check the backup at $BACKUP for the real commands)"
    echo ""
    echo "To install after reviewing: crontab $NEWCRON"
    echo "To restore backup: crontab $BACKUP"
fi
