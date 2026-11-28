"""Exercise the real HTTP handler and SQLite lifecycle with a fake Traccar.
No production network, credentials, devices or location records are used.
"""
import http.client
import json
import os
import tempfile
import threading
import unittest
from contextlib import closing
from pathlib import Path
from unittest.mock import patch

from server import Enrollment, EnrollmentError, Server, connect, issue
from test_server import FakeTraccar


class HttpFakeTraccar(FakeTraccar):
    token = "test-only"

    def __init__(self):
        super().__init__()
        self.ready = True

    def verify_scope(self):
        if not self.ready:
            raise EnrollmentError(503, "invalid_service_account_scope: test detail")


class HttpAcceptanceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.db = str(Path(self.tmp.name) / "test.sqlite3")
        self.upstream = HttpFakeTraccar()
        self.server = None
        self.addCleanup(self.stop_server)
        self.start_server()
        self.body = {"installationId": "a" * 32, "model": "Test Android"}

    def start_server(self):
        with patch.dict(os.environ, {"ZALGPS_ALLOWED_PEERS": "127.0.0.1"}):
            self.server = Server(("127.0.0.1", 0), Enrollment(self.db, self.upstream))
        self.thread = threading.Thread(target=self.server.serve_forever, kwargs={"poll_interval": 0.01})
        self.thread.start()

    def stop_server(self):
        if self.server is not None:
            self.server.shutdown()
            self.server.server_close()
            self.thread.join(timeout=3)
            self.server = None

    def request(self, method, path, body=None, content_type="application/json"):
        conn = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)
        try:
            payload = json.dumps(body).encode() if body is not None else None
            conn.request(method, path, body=payload, headers={"Content-Type": content_type})
            response = conn.getresponse()
            data = json.loads(response.read())
            self.assertEqual(response.getheader("Cache-Control"), "no-store")
            return response.status, data
        finally:
            conn.close()

    def enroll(self, code, **fields):
        return self.request("POST", "/v1/enroll", {**self.body, "activationCode": code, **fields})

    def test_health_and_readiness_fail_closed(self):
        self.assertEqual(self.request("GET", "/healthz"), (200, {"status": "ok", "service": "zalgps-provisioning"}))
        self.assertEqual(self.request("GET", "/readyz"), (200, {"ready": True}))
        self.upstream.ready = False
        self.assertEqual(self.request("GET", "/readyz"), (503, {"ready": False}))
        self.assertEqual(self.request("GET", "/unknown"), (404, {"error": "not_found"}))

    def test_new_enrollment_retry_survives_restart(self):
        code = issue(self.db, 900)
        status, result = self.enroll(code)
        self.assertEqual(status, 200)
        self.assertRegex(result["deviceId"], r"^zg-[a-f0-9]{32}$")
        self.assertEqual(result["serverUrl"], "https://gps.go7s.net/")
        self.stop_server()
        self.start_server()
        self.assertEqual(self.enroll(code), (200, result))
        self.assertEqual(len(self.upstream.calls), 1)
        self.assertEqual(len(self.upstream.devices), 1)
        self.assertEqual(self.enroll(code, installationId="b" * 32),
                         (409, {"error": "activation_already_used"}))

    def test_existing_id_link_never_creates_duplicate(self):
        self.upstream.devices["12345678"] = 42
        code = issue(self.db, 900, "12345678")
        self.assertEqual(self.enroll(code, existingDeviceId="87654321"),
                         (403, {"error": "activation_invalid_or_expired"}))
        self.assertEqual(self.enroll(code), (403, {"error": "activation_invalid_or_expired"}))
        status, result = self.enroll(code, existingDeviceId="12345678")
        self.assertEqual(status, 200)
        self.assertEqual(result["deviceId"], "12345678")
        self.stop_server()
        self.start_server()
        self.assertEqual(self.enroll(code, existingDeviceId="12345678"), (200, result))
        self.assertEqual(self.enroll(code, existingDeviceId="12345678", installationId="b" * 32),
                         (409, {"error": "activation_already_used"}))
        self.assertEqual(self.upstream.devices, {"12345678": 42})
        self.assertEqual(self.upstream.calls, [])

    def test_missing_and_expired_device_codes_fail_without_creation(self):
        code = issue(self.db, 900, "12345678")
        self.assertEqual(self.enroll(code, existingDeviceId="12345678"),
                         (403, {"error": "existing_device_unavailable"}))
        with closing(connect(self.db)) as db, db:
            db.execute("UPDATE enrollment_links SET expires=0")
        self.assertEqual(self.enroll(code, existingDeviceId="12345678"),
                         (403, {"error": "activation_invalid_or_expired"}))
        self.assertEqual(self.upstream.devices, {})

    def test_invalid_payload_and_unconfigured_service(self):
        self.assertEqual(self.enroll("invalid"), (400, {"error": "invalid_activation_code"}))
        self.assertEqual(self.request("POST", "/v1/enroll", ["invalid"]), (400, {"error": "invalid_request"}))
        self.assertEqual(self.request("POST", "/v1/enroll", self.body, "text/plain"),
                         (400, {"error": "invalid_request"}))
        self.upstream.token = ""
        self.assertEqual(self.enroll("invalid"), (503, {"error": "enrollment_not_configured"}))
        self.assertEqual(self.upstream.calls, [])

    def test_upstream_timeout_retry_uses_reserved_identity(self):
        code = issue(self.db, 900)
        self.upstream.fail = True
        self.assertEqual(self.enroll(code), (503, {"error": "traccar_unavailable"}))
        self.stop_server()
        self.start_server()
        status, result = self.enroll(code)
        self.assertEqual(status, 200)
        self.assertEqual(len(set(self.upstream.calls)), 1)
        self.assertEqual(set(self.upstream.devices), {result["deviceId"]})


if __name__ == "__main__":
    unittest.main()
