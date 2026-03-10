"""
Google Search Console metrics collector.
Fetches daily GSC data and pushes to VictoriaMetrics via import API.
Runs on a schedule (default: every 6 hours).
"""
import json
import os
import time
import urllib.request
from datetime import datetime, timedelta

from google.oauth2 import service_account
from googleapiclient.discovery import build

CREDENTIALS_FILE = os.environ.get("GSC_CREDENTIALS", "/app/secrets/gsc-credentials.json")
SITE_URL = os.environ.get("GSC_SITE_URL", "sc-domain:musick.com.au")
VM_URL = os.environ.get("VM_IMPORT_URL", "http://victoria-metrics:8428/api/v1/import/prometheus")
INTERVAL = int(os.environ.get("GSC_INTERVAL_SECONDS", "21600"))  # 6 hours

SCOPES = ["https://www.googleapis.com/auth/webmasters.readonly"]


def get_service():
    creds = service_account.Credentials.from_service_account_file(
        CREDENTIALS_FILE, scopes=SCOPES
    )
    return build("searchconsole", "v1", credentials=creds)


def fetch_site_metrics(service, date_str):
    """Fetch aggregate site-level metrics for a given date."""
    body = {
        "startDate": date_str,
        "endDate": date_str,
        "dimensions": [],
        "rowLimit": 1,
    }
    response = service.searchanalytics().query(siteUrl=SITE_URL, body=body).execute()
    rows = response.get("rows", [])
    if rows:
        return rows[0]
    return None


def fetch_top_queries(service, date_str, limit=20):
    """Fetch top queries for a given date."""
    body = {
        "startDate": date_str,
        "endDate": date_str,
        "dimensions": ["query"],
        "rowLimit": limit,
    }
    response = service.searchanalytics().query(siteUrl=SITE_URL, body=body).execute()
    return response.get("rows", [])


def fetch_top_pages(service, date_str, limit=20):
    """Fetch top pages for a given date."""
    body = {
        "startDate": date_str,
        "endDate": date_str,
        "dimensions": ["page"],
        "rowLimit": limit,
    }
    response = service.searchanalytics().query(siteUrl=SITE_URL, body=body).execute()
    return response.get("rows", [])


def push_metrics(metrics_lines):
    """Push Prometheus-format metrics to VictoriaMetrics."""
    data = "\n".join(metrics_lines) + "\n"
    req = urllib.request.Request(
        VM_URL,
        data=data.encode(),
        headers={"Content-Type": "text/plain"},
        method="POST",
    )
    try:
        urllib.request.urlopen(req)
        print(f"Pushed {len(metrics_lines)} metrics")
    except Exception as e:
        print(f"Failed to push metrics: {e}")


def sanitize_label(value):
    """Escape label values for Prometheus format."""
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def collect_and_push():
    service = get_service()

    # GSC data has a 2-3 day lag, fetch last 5 days to catch updates
    metrics = []
    for days_ago in range(2, 7):
        date = datetime.utcnow() - timedelta(days=days_ago)
        date_str = date.strftime("%Y-%m-%d")
        ts_ms = int(date.timestamp()) * 1000

        # Site-level aggregate
        row = fetch_site_metrics(service, date_str)
        if row:
            clicks = row.get("clicks", 0)
            impressions = row.get("impressions", 0)
            ctr = row.get("ctr", 0)
            position = row.get("position", 0)

            metrics.append(f'gsc_clicks{{site="musick.com.au"}} {clicks} {ts_ms}')
            metrics.append(f'gsc_impressions{{site="musick.com.au"}} {impressions} {ts_ms}')
            metrics.append(f'gsc_ctr{{site="musick.com.au"}} {ctr} {ts_ms}')
            metrics.append(f'gsc_position{{site="musick.com.au"}} {position} {ts_ms}')

        # Top queries
        queries = fetch_top_queries(service, date_str, limit=10)
        for q in queries:
            query = sanitize_label(q["keys"][0])
            metrics.append(f'gsc_query_clicks{{site="musick.com.au",query="{query}"}} {q.get("clicks", 0)} {ts_ms}')
            metrics.append(f'gsc_query_impressions{{site="musick.com.au",query="{query}"}} {q.get("impressions", 0)} {ts_ms}')
            metrics.append(f'gsc_query_position{{site="musick.com.au",query="{query}"}} {q.get("position", 0)} {ts_ms}')

        # Top pages
        pages = fetch_top_pages(service, date_str, limit=10)
        for p in pages:
            page = sanitize_label(p["keys"][0])
            metrics.append(f'gsc_page_clicks{{site="musick.com.au",page="{page}"}} {p.get("clicks", 0)} {ts_ms}')
            metrics.append(f'gsc_page_impressions{{site="musick.com.au",page="{page}"}} {p.get("impressions", 0)} {ts_ms}')

        print(f"Collected {date_str}: {len(queries)} queries, {len(pages)} pages")

    if metrics:
        push_metrics(metrics)


def main():
    print(f"GSC Collector starting — site: {SITE_URL}, interval: {INTERVAL}s")
    while True:
        try:
            collect_and_push()
        except Exception as e:
            print(f"Collection error: {e}")
        print(f"Sleeping {INTERVAL}s until next collection...")
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
