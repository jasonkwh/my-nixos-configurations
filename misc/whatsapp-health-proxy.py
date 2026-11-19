import hashlib
import hmac
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
from pathlib import Path
import secrets


TOKEN_PATH = Path("/var/lib/hermes/.hermes/whatsapp/session/.bridge-token")


def fetch_health(token_path=TOKEN_PATH, bridge_port=3000):
    token = token_path.read_text(encoding="utf-8-sig").strip()
    if not token:
        raise ValueError("Bridge token unavailable")
    challenge = secrets.token_urlsafe(24)
    connection = http.client.HTTPConnection("127.0.0.1", bridge_port, timeout=1.5)
    try:
        connection.request("GET", "/auth-proof", headers={"X-Hermes-Bridge-Challenge": challenge})
        response = connection.getresponse()
        if response.status != 200:
            raise ValueError("Bridge identity unavailable")
        proof = json.loads(response.read(65537)).get("authProof")
        expected = hmac.new(token.encode(), challenge.encode(), hashlib.sha256).hexdigest()
        if not isinstance(proof, str) or not hmac.compare_digest(proof.encode(), expected.encode()):
            raise ValueError("Bridge identity mismatch")
        connection.request("GET", "/health", headers={"Authorization": "Bearer " + token})
        response = connection.getresponse()
        if response.status != 200:
            raise ValueError("Bridge health unavailable")
        health = json.loads(response.read(65537))
        if not isinstance(health.get("status"), str):
            raise ValueError("Invalid bridge status")
        result = {"status": health["status"]}
        for field in ("queueLength", "uptime"):
            value = health[field]
            if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
                raise ValueError("Invalid bridge metric")
            result[field] = value
        return result
    finally:
        connection.close()


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/health":
            self.send_error(404)
            return
        try:
            health = fetch_health()
            status = 200
        except (OSError, ValueError, KeyError, TypeError, AttributeError, http.client.HTTPException):
            health, status = {"status": "unavailable"}, 503
        body = json.dumps(health).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 3002), HealthHandler).serve_forever()
