#!/usr/bin/env python3
"""
Generate musick crontab with Healthchecks ping integration.
Wraps each cron job with start/success/fail pings.

Usage: python3 generate-crontab.py > /tmp/new-crontab.txt
"""

HC_BASE = "http://100.121.227.39:8080/ping"

# UUID mapping from Healthchecks API
CHECKS = {
    "process-notifications": "a1b4bd8f-44a9-4d88-8072-096c7214286b",
    "social-autoposter": "b0c55904-cbf8-4cf1-9d07-e2ab719bcf08",
    "google-index-queue": "f2a433db-c128-4d3f-86ac-7abec2645625",
    "process-discovery-queue": "f4d17276-2832-4803-833a-bfb829900b93",
    "aggregate-trending": "eb2c25bc-d6bc-4ee5-90f2-33ad24649357",
    "discover-news-feeds": "a8ab2be9-e52d-4e39-86a2-d3fb77908ac1",
    "discover-ticketmaster": "492e397f-df61-44bf-91d9-6f26f4fdba12",
    "import-eventbrite": "c5afd695-11f2-4702-b04c-2b8690cc8568",
    "discover-ai-research": "19325c6d-db92-4139-be87-5ab28de33f8f",
    "import-oztix": "9f57ba2c-ad60-43f8-b109-6fc10021d7ac",
    "fetch-artwork": "10a160f6-709b-491e-af22-1466a3ff724c",
    "fix-affiliate-urls": "95f5741e-c342-462f-b82d-53dbd00fc93e",
    "import-moshtix": "0b562c5c-527b-4036-aa1a-7c3e51f02010",
    "estimate-set-times": "673c2257-896c-4d97-917a-57c17458ec7e",
    "daily-gig-picks": "147edf30-1e9e-47d3-a271-2224d5aa4632",
    "daily-video-population": "7a8e57e9-b540-4cfe-bee6-72cfeb4a1e53",
    "daily-health-report": "b33da428-8bae-4bcd-aa77-341ba2c5833f",
    "generate-sitemap": "e296f72a-e528-47c8-a218-761a0819d201",  # mapped to seo-audit check? No, separate
    "weekly-newsletter": "7e3d6f16-74e1-48ef-a936-b562a1e423c0",
    "export-weekly-stats": "9d27d7e6-3df6-4878-b429-24d4fc82ce09",
    "seo-audit": "e296f72a-e528-47c8-a218-761a0819d201",
    "weekly-quiz-email": "d8f558e3-fab5-4638-8692-b1c826a56362",
    "backup-database": "b96d2479-80a7-4f34-9062-993b005b1d67",
    "daily-pending-approvals": "393ad226-0918-4c27-92ff-949e7435f347",
    "setlist-updater": "08948892-8dff-45b7-8bd4-2a85fde67d74",
    "localise-gig-images": "06e0adcf-9840-4e37-a739-c1905c6367aa",
    "fetch-artist-images": "0b1afe4d-79a6-45cc-9f01-6c8375a4535b",
    "site-operations-monitor": "d8949c16-ef66-4910-80bf-1c374e0dc455",
    "discover-venue-events": "c1fc19c6-67a2-4d4c-adb3-9c793afd2a04",
    "discover-festivals": "3e2bcab2-8777-44fe-abf6-5d2187b195c1",
    "discover-brisbane-events": "d2cca113-4082-4b94-8ec6-204712eb64a2",
    "discover-themusic-gigs": "fbe5d7b0-2f44-4899-b2fe-d3841a6f5003",
    "discover-beat-gigs": "890fd3ce-81fe-4d4f-ae7e-1de3037b2912",
    "discover-eventfinda": "c3686dd1-6e25-4cd8-bc18-45ed77ef92e3",
    "presale-alerts": "9e787442-4d38-47a9-b516-e3c6cc2bc986",
    "seo-audit-runner": "7120550a-6aa9-494a-8725-0771a1255702",
    "auto-blog": "9d651ce5-684b-4288-aa62-e216452b37a9",
    "daily_digest": "8030050c-fe55-42a7-a10e-def9ae060af6",
    "weekly_email": "568ac503-b7fd-4ecb-b4c0-f9aa0c6631d9",
    "backup-content": "0e2fff1b-d9ed-4a32-96c9-4cb95bb6bbf3",
    "growth-gsc-fetch": "59cdac76-42d6-40e6-873c-36cc4e1852ba",
    "growth-analyse": "60ad4cfc-256a-4459-bbef-979f0fcfc104",
    "growth-execute": "bb611690-373b-488b-bd85-3192ce669114",
    "growth-report": "9702e3c2-108d-4db9-867a-69ab8396ec74",
    "growth-experiments": "038b6473-ab38-4428-84f0-c29a68ca74ec",
    "growth-broken-links": "c0eba049-67b5-4490-85c4-1587576acc02",
    "notify-artist-followers": "42c64c1c-643b-41d7-958d-7e6316ae1dc6",
    "push-new-gigs": "27d1918b-16ec-4e4b-921c-a11b24db3543",
    "discover-festival-lineups": "9e827ca6-7d11-41ac-8eb6-86fb20a83f95",
}


def hc_wrap(name, cmd, log):
    """Wrap a command with healthchecks start/success/fail pings."""
    uuid = CHECKS.get(name)
    if not uuid:
        return f"{cmd} >> {log} 2>&1"
    return (
        f"curl -fsS -m 10 --retry 3 -o /dev/null {HC_BASE}/{uuid}/start ; "
        f"{cmd} >> {log} 2>&1 "
        f"&& curl -fsS -m 10 --retry 3 -o /dev/null {HC_BASE}/{uuid} "
        f"|| curl -fsS -m 10 --retry 3 -o /dev/null {HC_BASE}/{uuid}/fail"
    )


# Keep UptimeRobot pings too — append after the healthchecks success ping
def hc_wrap_with_utr(name, cmd, log, utr_url=None):
    """Wrap with healthchecks + optional UptimeRobot heartbeat."""
    uuid = CHECKS.get(name)
    if not uuid:
        base = f"{cmd} >> {log} 2>&1"
    else:
        base = (
            f"curl -fsS -m 10 --retry 3 -o /dev/null {HC_BASE}/{uuid}/start ; "
            f"{cmd} >> {log} 2>&1 "
            f"&& curl -fsS -m 10 --retry 3 -o /dev/null {HC_BASE}/{uuid} "
            f"|| curl -fsS -m 10 --retry 3 -o /dev/null {HC_BASE}/{uuid}/fail"
        )
    if utr_url:
        base += f' ; curl -fsS -m 10 --retry 3 -o /dev/null "{utr_url}"'
    return base


# Crontab entries: (schedule, name, command, log, uptimerobot_url)
CRONS = [
    # Every 5 minutes
    ("*/5 * * * *", "process-notifications", "cd $MUSICK && $PHP cron/process-notifications.php", "$LOGS/process-notifications.log", "https://heartbeat.uptimerobot.com/m802399199-58b919572beb9bca41d082a37b7e88a3692b0325"),
    ("*/5 * * * *", "social-autoposter", "cd $MUSICK && $PHP cron/social-autoposter.php", "$LOGS/social-autoposter.log", "https://heartbeat.uptimerobot.com/m802399198-97cf50fec1ae3843ead631ee51be342c8c678fee"),
    # Every 15 minutes
    ("*/15 * * * *", "google-index-queue", "cd $MUSICK && $PHP cron/google-index-queue.php", "$LOGS/google-index-queue.log", "https://heartbeat.uptimerobot.com/m802399200-2c179a8bad8227b0e25910efaeb3a9da2c36aa03"),
    ("*/15 * * * *", "process-discovery-queue", "cd $MUSICK && $PHP cron/process-discovery-queue.php", "$LOGS/process-discovery-queue.log", "https://heartbeat.uptimerobot.com/m802399201-81ddd251d192ac6e7f65fa3f4b688f983c1e5663"),
    # Every 30 minutes
    ("0,30 * * * *", "growth-execute", "cd $MUSICK && $PHP growth-engine/cron/growth-execute.php", "$LOGS/growth-execute.log", None),
    # Hourly
    ("5 * * * *", "aggregate-trending", "cd $MUSICK && $PHP cron/aggregate-trending.php", "$LOGS/aggregate-trending.log", "https://heartbeat.uptimerobot.com/m802399202-1d1a3d0e36e60feb1e781a0a3d81d240caf8fa12"),
    # Every 6 hours
    ("0 */6 * * *", "discover-news-feeds", "cd $MUSICK && $PHP cron/discover-news-feeds.php", "$LOGS/discover-news-feeds.log", "https://heartbeat.uptimerobot.com/m802399203-1e679d71001f8d77d99475e22402c231499e9fa9"),
    ("0 */6 * * *", "site-operations-monitor", "cd $MUSICK && $PHP cron/site-operations-monitor.php", "$LOGS/site-operations-monitor.log", None),
    ("0 0,6,12,18 * * *", "growth-gsc-fetch", "cd $MUSICK && $PHP growth-engine/cron/growth-gsc-fetch.php", "$LOGS/growth-gsc-fetch.log", None),
    ("0 2,6,10,14,18,22 * * *", "growth-report", "cd $MUSICK && $PHP growth-engine/cron/growth-report.php", "$LOGS/growth-report.log", None),
    # Daily
    ("0 1 * * *", "generate-sitemap", "cd $MUSICK && $PHP cron/generate-sitemap.php", "$LOGS/generate-sitemap.log", "https://heartbeat.uptimerobot.com/m802399204-c490e4a4bca9187c5caa47985aabe74b9d530983"),
    ("0 2 * * *", "discover-ticketmaster", "cd $MUSICK && $PHP cron/discover-ticketmaster.php", "$LOGS/discover-ticketmaster.log", "https://heartbeat.uptimerobot.com/m802399206-1fee1af7ccdee668b6a3cd880da69aa5b36d9515"),
    ("30 2 * * *", "import-eventbrite", "cd $MUSICK && $PHP cron/import-eventbrite-events.php", "$LOGS/import-eventbrite-events.log", "https://heartbeat.uptimerobot.com/m802399208-f4bcabb5b77327ce91a46ba5fd5c6204f12a55d4"),
    ("0 3 * * *", "discover-ai-research", "cd $MUSICK && $PHP cron/discover-ai-research.php", "$LOGS/discover-ai-research.log", "https://heartbeat.uptimerobot.com/m802399209-11cc087a32473ab053f3102522f28c56b75c4faa"),
    ("30 3 * * *", "discover-eventfinda", "cd $MUSICK && $PHP cron/discover-eventfinda.php", "$LOGS/discover-eventfinda.log", None),
    ("0 4 * * *", "import-oztix", "cd $MUSICK && $PHP cron/import-oztix.php", "$LOGS/import-oztix.log", "https://heartbeat.uptimerobot.com/m802399855-c775e92d0cecbd67c145beda4da0761240da739d"),
    ("30 4 * * *", "discover-venue-events", "cd $MUSICK && $PHP cron/discover-venue-events.php", "$LOGS/discover-venue-events.log", None),
    ("30 4 * * *", "localise-gig-images", "cd $MUSICK && $PHP cron/localise-gig-images.php", "$LOGS/localise-gig-images.log", "https://heartbeat.uptimerobot.com/m802400830-4844cd2356fb58567ec9adc43fefa0c95e59f40f"),
    ("45 4 * * *", "discover-brisbane-events", "cd $MUSICK && $PHP cron/discover-brisbane-events.php", "$LOGS/discover-brisbane-events.log", None),
    ("0 5 * * *", "fetch-artwork", "cd $MUSICK && $PHP cron/fetch-artwork.php", "$LOGS/fetch-artwork.log", "https://heartbeat.uptimerobot.com/m802399212-9bf4aefb576b5990ecbf0edc5bb90dca6a049adb"),
    ("0 5 * * *", "fetch-artist-images", "cd $MUSICK && $PHP cron/fetch-artist-images.php 200", "$LOGS/fetch-artist-images.log", None),
    ("0 5 * * *", "discover-themusic-gigs", "cd $MUSICK && $PHP cron/discover-themusic-gigs.php", "$LOGS/discover-themusic-gigs.log", None),
    ("15 5 * * *", "discover-beat-gigs", "cd $MUSICK && $PHP cron/discover-beat-gigs.php", "$LOGS/discover-beat-gigs.log", None),
    ("30 5 * * *", "fix-affiliate-urls", "cd $MUSICK && $PHP cron/fix-affiliate-urls.php", "$LOGS/fix-affiliate-urls.log", "https://heartbeat.uptimerobot.com/m802399213-74b594e0493c7c49f23ef0f53094c985f3162cc8"),
    ("0 6 * * *", "import-moshtix", "cd $MUSICK && $PHP cron/import-moshtix.php", "$LOGS/import-moshtix.log", "https://heartbeat.uptimerobot.com/m802399211-1dc91e54629c8d8cf5c662aaecbe793f5cebd9ec"),
    ("0 6 * * *", "auto-blog", "cd $MUSICK && $PHP cron/auto-blog.php", "$LOGS/auto-blog.log", None),
    ("15 6 * * *", "estimate-set-times", "cd $MUSICK && $PHP cron/estimate-set-times.php", "$LOGS/estimate-set-times.log", "https://heartbeat.uptimerobot.com/m802399215-4cf19997bc4c2ea65c7b504fd028f82614c52776"),
    ("30 6 * * *", "daily-gig-picks", "cd $MUSICK && $PHP cron/daily-gig-picks.php", "$LOGS/daily-gig-picks.log", "https://heartbeat.uptimerobot.com/m802399214-a3f3ab4d7df5308b40703961fcaf5e7eda763ce1"),
    ("0 7 * * *", "daily-video-population", "cd $MUSICK && $PHP cron/daily-video-population.php", "$LOGS/daily-video-population.log", "https://heartbeat.uptimerobot.com/m802399216-9d0e12a9c55a9dfcc006984d925fb23aca6169b5"),
    ("0 7 * * *", "presale-alerts", "cd /home/musick/public_html && php cron/presale-alerts.php", "/home/musick/logs/presale-alerts.log", None),
    ("30 7 * * *", "daily-health-report", "cd $MUSICK && $PHP cron/daily-health-report.php", "$LOGS/daily-health-report.log", "https://heartbeat.uptimerobot.com/m802399217-7f9889200118ec0c79c71664a7943ae437b80cd4"),
    ("45 7 * * *", "daily_digest", "cd $MUSICK && $PHP cron/daily_digest.php", "$LOGS/daily_digest.log", None),
    ("0 8 * * *", "daily-pending-approvals", "cd $MUSICK && $PHP cron/daily-pending-approvals.php", "$LOGS/daily-pending-approvals.log", "https://heartbeat.uptimerobot.com/m802399857-f829a109d990ec4301c89bb34ddfd310dd60c3d5"),
    ("0 8 * * *", "growth-analyse", "cd $MUSICK && $PHP growth-engine/cron/growth-analyse.php", "$LOGS/growth-analyse.log", None),
    ("30 8 * * *", "notify-artist-followers", "cd $MUSICK && $PHP cron/notify-artist-followers.php", "$LOGS/artist-notifications.log", None),
    ("0 9 * * *", "push-new-gigs", "cd $MUSICK && $PHP cron/push-new-gigs.php", "$LOGS/push-new-gigs.log", None),
    ("0 9 * * *", "growth-experiments", "cd $MUSICK && $PHP growth-engine/cron/growth-experiments.php", "$LOGS/growth-experiments.log", None),
    ("0 11 * * *", "setlist-updater", "cd $MUSICK && $PHP cron/setlist-updater.php", "$LOGS/setlist-updater.log", "https://heartbeat.uptimerobot.com/m802400751-a5339ce9824e300acc24fbba5c6542d65fd17e74"),
    ("30 12 * * *", "localise-gig-images", "cd $MUSICK && $PHP cron/localise-gig-images.php", "$LOGS/localise-gig-images.log", "https://heartbeat.uptimerobot.com/m802400830-4844cd2356fb58567ec9adc43fefa0c95e59f40f"),
    ("0 13 * * *", "fetch-artist-images", "cd $MUSICK && $PHP cron/fetch-artist-images.php 200", "$LOGS/fetch-artist-images.log", None),
    ("0 17 * * *", "backup-database", "/home/musick/public_html/cron/backup-database.sh", "/home/musick/logs/backup.log", "https://heartbeat.uptimerobot.com/m802399856-653e8852439381ff7d40e7e4fb804144feef14b6"),
    ("30 17 * * *", "backup-content", "/home/musick/public_html/cron/backup-content.sh", "/home/musick/logs/backup-content.log", None),
    ("0 19 * * *", "daily-video-population", "cd $MUSICK && $PHP cron/daily-video-population.php", "$LOGS/daily-video-population.log", "https://heartbeat.uptimerobot.com/m802399216-9d0e12a9c55a9dfcc006984d925fb23aca6169b5"),
    # Weekly
    ("30 3 * * 0", "seo-audit", "cd $MUSICK && $PHP cron/seo-audit.php", "$LOGS/seo-audit.log", None),
    ("0 4 * * 0", "growth-broken-links", "cd $MUSICK && $PHP growth-engine/cron/growth-broken-links.php", "$LOGS/growth-broken-links.log", None),
    ("0 18 * * 0", "weekly-newsletter", "cd $MUSICK && $PHP cron/weekly-newsletter.php", "$LOGS/weekly-newsletter.log", "https://heartbeat.uptimerobot.com/m802399218-37cbc0dd6c28a63fab8c305f5af01d0220c2d3ab"),
    ("45 6 * * 1", "weekly_email", "cd $MUSICK && $PHP cron/weekly_email.php", "$LOGS/weekly_email.log", None),
    ("0 9 * * 1", "export-weekly-stats", "cd $MUSICK && $PHP cron/export-weekly-stats.php", "$LOGS/export-weekly-stats.log", "https://heartbeat.uptimerobot.com/m802399219-a72352e8d55d42b606618dcd9f30b64190e844d7"),
    ("0 10 * * 1", "weekly-quiz-email", "cd $MUSICK && $PHP cron/weekly-quiz-email.php", "$LOGS/weekly-quiz-email.log", "https://heartbeat.uptimerobot.com/m802399220-7330d65c1ae6b169bbf41fe59ae2a88126d01a64"),
    ("30 3 * * 1", "discover-festivals", "cd $MUSICK && $PHP cron/discover-festivals.php", "$LOGS/discover-festivals.log", None),
    ("0 3 * * 3", "discover-festival-lineups", "cd $MUSICK && $PHP cron/discover-festival-lineups.php", "$LOGS/festival-lineups.log", None),
    # Every minute
    ("* * * * *", "seo-audit-runner", "/home/musick/public_html/cron/seo-audit-runner.sh", None, None),
]

print('MAILTO=""')
print("MUSICK=/home/musick/public_html")
print("PHP=/usr/local/lsws/lsphp81/bin/php")
print("LOGS=/home/musick/logs")
print()

for schedule, name, cmd, log, utr_url in CRONS:
    if log is None:
        # seo-audit-runner: no log, just ping
        uuid = CHECKS.get(name)
        if uuid:
            line = f"{cmd} && curl -fsS -m 10 --retry 3 -o /dev/null {HC_BASE}/{uuid} || curl -fsS -m 10 --retry 3 -o /dev/null {HC_BASE}/{uuid}/fail"
        else:
            line = cmd
    else:
        line = hc_wrap_with_utr(name, cmd, log, utr_url)
    print(f"{schedule} {line}")
