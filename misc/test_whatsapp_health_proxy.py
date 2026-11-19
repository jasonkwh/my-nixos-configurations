import hashlib
import hmac
import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


SCRIPT = Path(__file__).with_name("whatsapp-health-proxy.py")


class HealthProxyTest(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SCRIPT.exists(), "authenticated health collector is missing")
        spec = importlib.util.spec_from_file_location("health_proxy", SCRIPT)
        assert spec is not None and spec.loader is not None
        self.proxy = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.proxy)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.token_path = Path(self.temp.name) / "token"
        self.token_path.write_text("test-only-token")
        self.state = {"token": "test-only-token", "status": "connected"}
        self.requests = []
        state, requests = self.state, self.requests

        class Bridge(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def do_GET(self):
                requests.append((self.path, self.headers.get("Authorization")))
                code = 200
                if self.path == "/auth-proof":
                    challenge = self.headers["X-Hermes-Bridge-Challenge"]
                    proof = hmac.new(state["token"].encode(), challenge.encode(), hashlib.sha256).hexdigest()
                    body = {"authProof": state.get("proof", proof)}
                elif self.path == "/health" and self.headers.get("Authorization") == "Bearer " + state["token"]:
                    body = {"status": state["status"], "queueLength": 2, "uptime": 12.5,
                            "session": "/private/session", "extra": "not-public"}
                else:
                    code, body = 401, {"error": "Unauthorized"}
                data = json.dumps(body).encode()
                self.send_response(code)
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def log_message(self, format, *args):
                pass

        self.bridge = ThreadingHTTPServer(("127.0.0.1", 0), Bridge)
        thread = threading.Thread(target=self.bridge.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(self.bridge.server_close)
        self.addCleanup(self.bridge.shutdown)

    def health(self):
        return self.proxy.fetch_health(self.token_path, self.bridge.server_port)

    def test_authenticated_health_is_sanitized(self):
        self.assertEqual(self.health(), {"status": "connected", "queueLength": 2, "uptime": 12.5})
        self.assertEqual(self.requests, [("/auth-proof", None), ("/health", "Bearer test-only-token")])

    def test_rotated_token_is_read_on_next_request(self):
        self.health()
        self.state["token"] = "rotated-test-token"
        self.token_path.write_text(self.state["token"])
        self.assertEqual(self.health()["status"], "connected")

    def test_wrong_proof_never_receives_bearer(self):
        self.state["proof"] = "invalid-proof"
        with self.assertRaises(ValueError):
            self.health()
        self.assertEqual(self.requests, [("/auth-proof", None)])

    def test_non_ascii_proof_is_rejected(self):
        self.state["proof"] = "伪造"
        with self.assertRaises(ValueError):
            self.health()
        self.assertEqual(self.requests, [("/auth-proof", None)])

    def test_missing_token_fails_without_contacting_bridge(self):
        self.token_path.unlink()
        with self.assertRaises(OSError):
            self.health()
        self.assertEqual(self.requests, [])

    def test_disconnected_is_not_rewritten_to_connected(self):
        self.state["status"] = "disconnected"
        self.assertEqual(self.health()["status"], "disconnected")

    def test_http_interface_is_health_only_and_fails_closed(self):
        import http.client

        fetch_health = self.proxy.fetch_health
        setattr(self.proxy, "fetch_health", lambda: fetch_health(self.token_path, self.bridge.server_port))
        server = ThreadingHTTPServer(("127.0.0.1", 0), self.proxy.HealthHandler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=3)
        self.addCleanup(connection.close)
        for path in ("/messages", "/send", "/auth-proof", "/health?url=http://example.com"):
            connection.request("GET", path)
            response = connection.getresponse()
            self.assertEqual(response.status, 404)
            response.read()
        connection.request("GET", "/health")
        response = connection.getresponse()
        self.assertEqual(response.status, 200)
        self.assertEqual(set(json.loads(response.read())), {"status", "queueLength", "uptime"})
        self.token_path.unlink()
        connection.request("GET", "/health")
        response = connection.getresponse()
        self.assertEqual(response.status, 503)
        self.assertEqual(json.loads(response.read()), {"status": "unavailable"})


if __name__ == "__main__":
    unittest.main()
