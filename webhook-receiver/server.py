"""Lightweight webhook receiver that creates Grafana annotations from Forgejo push events."""
import json
import os
import urllib.request
from http.server import HTTPServer, BaseHTTPRequestHandler

GRAFANA_URL = os.environ.get("GRAFANA_URL", "http://grafana:3000")
GRAFANA_API_KEY = os.environ.get("GRAFANA_API_KEY", "")
LISTEN_PORT = int(os.environ.get("WEBHOOK_PORT", "9999"))


class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            return

        # Forgejo push event
        repo = payload.get("repository", {}).get("full_name", "unknown")
        pusher = payload.get("pusher", {}).get("login", "unknown")
        ref = payload.get("ref", "").replace("refs/heads/", "")
        commits = payload.get("commits", [])
        commit_msgs = [c.get("message", "").split("\n")[0] for c in commits[:5]]
        text = f"Push to {repo}/{ref} by {pusher}: {'; '.join(commit_msgs)}"

        annotation = {
            "text": text,
            "tags": ["deploy", "git-push", repo],
        }

        if GRAFANA_API_KEY:
            req = urllib.request.Request(
                f"{GRAFANA_URL}/api/annotations",
                data=json.dumps(annotation).encode(),
                headers={
                    "Authorization": f"Bearer {GRAFANA_API_KEY}",
                    "Content-Type": "application/json",
                },
                method="POST",
            )
            try:
                urllib.request.urlopen(req)
            except Exception as e:
                print(f"Failed to create annotation: {e}")

        print(f"Annotation: {text}")

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{"status": "ok"}')

    def log_message(self, format, *args):
        print(f"[webhook] {args[0]}")


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", LISTEN_PORT), WebhookHandler)
    print(f"Webhook receiver listening on port {LISTEN_PORT}")
    server.serve_forever()
