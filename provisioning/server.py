"""Small, opt-in ZalGps enrollment service. No tracking or admin credentials in APKs."""
import argparse
import hashlib
import hmac
import json
import os
import re
import secrets
import sqlite3
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import deque
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

GPS_URL = "https://gps.go7s.net/"
DB_PATH = os.getenv("ZALGPS_DB", "/var/lib/zalgps-provisioning/enrollment.sqlite3")
CODE_RE = re.compile(r"[A-Za-z0-9_-]{43}")
INSTALL_RE = re.compile(r"[a-f0-9]{32}")
DEFAULTS = {
    "accuracy": "high", "interval": 30, "distance": 25, "heartbeat": 300,
    "buffer": True, "stop_detection": True, "wakelock": False,
    "adaptive_tracking": True, "sync_mode": "instant", "sync_batch_size": 25,
    "sync_batch_interval": 60, "heartbeat_max_age": 300,
}


class EnrollmentError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


def digest(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def connect(path):
    db = sqlite3.connect(path, timeout=10)
    db.row_factory = sqlite3.Row
    db.execute("""CREATE TABLE IF NOT EXISTS enrollment (
        code_hash TEXT PRIMARY KEY, expires INTEGER NOT NULL,
        unique_id TEXT NOT NULL UNIQUE, installation_hash TEXT,
        device_id INTEGER, device_name TEXT
    )""")
    db.commit()
    return db


def issue(path, ttl_seconds):
    if not 60 <= ttl_seconds <= 86400:
        raise ValueError("TTL must be between 60 and 86400 seconds")
    code = secrets.token_urlsafe(32)
    with closing(connect(path)) as db, db:
        db.execute(
            "INSERT INTO enrollment(code_hash,expires,unique_id) VALUES(?,?,?)",
            (digest(code), int(time.time()) + ttl_seconds, "zg-" + secrets.token_hex(16)),
        )
    return code


class Traccar:
    def __init__(self, token):
        self.token = token
        self._verified_at = 0.0

    def request(self, method, path, payload=None):
        if not self.token:
            raise EnrollmentError(503, "enrollment_not_configured")
        req = urllib.request.Request(
            "http://127.0.0.1:8082/api/" + path,
            data=None if payload is None else json.dumps(payload).encode(),
            headers={"Authorization": "Bearer " + self.token, "Content-Type": "application/json",
                     "Accept": "application/json"},
            method=method,
        )
        try:
            with urllib.request.urlopen(req, timeout=6) as response:
                return json.load(response)
        except (urllib.error.URLError, TimeoutError, ValueError):
            raise EnrollmentError(503, "traccar_unavailable") from None

    def verify_scope(self):
        if not self.token:
            raise EnrollmentError(503, "enrollment_not_configured")
        if self._verified_at and time.monotonic() - self._verified_at < 60:
            return
        user = self.request("GET", "session")
        if (not isinstance(user, dict) or user.get("administrator") is not False
                or user.get("userLimit") != 0 or user.get("readonly")
                or user.get("deviceReadonly") or user.get("disabled")
                or not isinstance(user.get("deviceLimit"), int)
                or not 1 <= user["deviceLimit"] <= 1000):
            raise EnrollmentError(503, "invalid_service_account_scope")
        self._verified_at = time.monotonic()

    def ensure_device(self, unique_id, name):
        self.verify_scope()
        existing = self.request("GET", "devices?" + urllib.parse.urlencode({"uniqueId": unique_id}))
        if not isinstance(existing, list):
            raise EnrollmentError(503, "invalid_traccar_response")
        matches = [d for d in existing if d.get("uniqueId") == unique_id]
        if len(matches) > 1:
            raise EnrollmentError(503, "device_conflict")
        result = matches[0] if matches else self.request(
            "POST", "devices", {"name": name, "uniqueId": unique_id, "disabled": False}
        )
        if not isinstance(result, dict) or result.get("uniqueId") != unique_id or not isinstance(result.get("id"), int):
            raise EnrollmentError(503, "invalid_traccar_response")
        return result["id"]


class Enrollment:
    def __init__(self, path, upstream):
        self.path, self.upstream = path, upstream
        self.lock = threading.Lock()

    def enroll(self, body):
        code = body.get("activationCode")
        installation = body.get("installationId")
        model = body.get("model", "Android")
        if not isinstance(code, str) or not CODE_RE.fullmatch(code):
            raise EnrollmentError(400, "invalid_activation_code")
        if not isinstance(installation, str) or not INSTALL_RE.fullmatch(installation):
            raise EnrollmentError(400, "invalid_installation_id")
        if not isinstance(model, str) or len(model) > 120:
            raise EnrollmentError(400, "invalid_model")
        model = " ".join(re.sub(r"[^\w .-]", "", model).split())[:60] or "Android"
        installation_hash = digest(installation)
        code_hash = digest(code)
        # One worker at a time. Commit the claim before contacting Traccar so
        # a retry after an upstream timeout uses the same unique ID.
        with self.lock, closing(connect(self.path)) as db:
            with db:
                db.execute("BEGIN IMMEDIATE")
                row = db.execute("SELECT * FROM enrollment WHERE code_hash=?", (code_hash,)).fetchone()
                if not row or row["expires"] < int(time.time()):
                    raise EnrollmentError(403, "activation_invalid_or_expired")
                if row["installation_hash"] and not hmac.compare_digest(row["installation_hash"], installation_hash):
                    raise EnrollmentError(409, "activation_already_used")
                unique_id = row["unique_id"]
                name = row["device_name"] or f"{model}-{unique_id[-6:].upper()}"
                db.execute(
                    "UPDATE enrollment SET installation_hash=?,device_name=? WHERE code_hash=?",
                    (installation_hash, name, code_hash),
                )
            device_id = row["device_id"]
            if device_id is None:
                device_id = self.upstream.ensure_device(unique_id, name)
                with db:
                    db.execute("UPDATE enrollment SET device_id=? WHERE code_hash=?", (device_id, code_hash))
            return {"deviceId": unique_id, "name": name, "serverUrl": GPS_URL, "config": DEFAULTS}


class Handler(BaseHTTPRequestHandler):
    server_version = "ZalGps"
    protocol_version = "HTTP/1.0"

    def setup(self):
        super().setup()
        self.connection.settimeout(8)

    def log_message(self, *_):
        # Do not log activation codes, identifiers, tokens, or request bodies.
        pass

    def reply(self, status, body):
        raw = json.dumps(body, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if self.path == "/healthz":
            self.reply(200, {"status": "ok", "service": "zalgps-provisioning"})
        elif self.path == "/readyz":
            try:
                self.server.enrollment.upstream.verify_scope()
                self.reply(200, {"ready": True})
            except EnrollmentError:
                self.reply(503, {"ready": False})
        else:
            self.reply(404, {"error": "not_found"})

    def do_POST(self):
        if self.path != "/v1/enroll":
            self.reply(404, {"error": "not_found"})
            return
        if not self.server.enrollment.upstream.token:
            self.reply(503, {"error": "enrollment_not_configured"})
            return
        if not self.server.allow_attempt():
            self.reply(429, {"error": "try_again_later"})
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 4096 or self.headers.get_content_type() != "application/json":
                raise EnrollmentError(400, "invalid_request")
            body = json.loads(self.rfile.read(size))
            if not isinstance(body, dict):
                raise EnrollmentError(400, "invalid_request")
            result = self.server.enrollment.enroll(body)
            self.reply(200, result)
        except EnrollmentError as exc:
            self.reply(exc.status, {"error": exc.message})
        except (ValueError, UnicodeError):
            self.reply(400, {"error": "invalid_request"})
        except (sqlite3.Error, OSError):
            self.reply(503, {"error": "temporarily_unavailable"})


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, enrollment):
        self.enrollment = enrollment
        self.attempts = deque()
        self.rate_lock = threading.Lock()
        self.slots = threading.BoundedSemaphore(8)
        self.allowed_peers = {ip.strip() for ip in os.getenv("ZALGPS_ALLOWED_PEERS", "").split(",") if ip.strip()}
        super().__init__(address, Handler)

    def allow_attempt(self):
        now = time.monotonic()
        with self.rate_lock:
            while self.attempts and self.attempts[0] <= now - 60:
                self.attempts.popleft()
            if len(self.attempts) >= 60:
                return False
            self.attempts.append(now)
            return True

    def verify_request(self, request, address):
        return not self.allowed_peers or address[0] in self.allowed_peers

    def process_request(self, request, address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, address)
        except Exception:
            self.slots.release()
            raise

    def process_request_thread(self, request, address):
        try:
            super().process_request_thread(request, address)
        finally:
            self.slots.release()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["serve", "issue"])
    parser.add_argument("--ttl", type=int, default=900)
    args = parser.parse_args()
    if args.action == "issue":
        print(issue(DB_PATH, args.ttl))
        return
    token_file = Path(os.getenv("CREDENTIALS_DIRECTORY", "/nonexistent")) / "traccar-token"
    token = token_file.read_text().strip() if token_file.is_file() else ""
    with closing(connect(DB_PATH)):
        pass
    Server((os.getenv("ZALGPS_BIND", "127.0.0.1"), int(os.getenv("ZALGPS_PORT", "8094"))),
           Enrollment(DB_PATH, Traccar(token))).serve_forever()


if __name__ == "__main__":
    main()
