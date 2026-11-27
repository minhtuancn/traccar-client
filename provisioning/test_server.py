import tempfile
import unittest
from pathlib import Path

from server import Enrollment, EnrollmentError, Traccar, issue, connect
from unittest.mock import Mock, patch
from urllib.error import HTTPError


class FakeTraccar:
    def __init__(self):
        self.calls = []
        self.fail = False
        self.devices = {}

    def ensure_device(self, unique_id, name):
        self.calls.append(unique_id)
        self.devices.setdefault(unique_id, 1)
        if self.fail:
            self.fail = False
            raise EnrollmentError(503, "traccar_unavailable")
        return self.devices[unique_id]


class EnrollmentTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.db = str(Path(self.tmp.name) / "db")
        self.upstream = FakeTraccar()
        self.service = Enrollment(self.db, self.upstream)
        self.code = issue(self.db, 900)
        self.body = {"activationCode": self.code, "installationId": "a" * 32, "model": "Samsung A54"}

    def test_enrollment_and_retry(self):
        one = self.service.enroll(self.body)
        two = self.service.enroll(self.body)
        self.assertEqual(one, two)
        self.assertEqual(len(self.upstream.calls), 1)
        self.assertEqual(one["serverUrl"], "https://gps.go7s.net/")
        self.assertEqual(one["config"]["heartbeat"], 300)
        self.assertTrue(one["name"].startswith("Samsung A54-"))

    def test_code_not_reusable_by_other_installation(self):
        self.service.enroll(self.body)
        with self.assertRaises(EnrollmentError) as err:
            self.service.enroll({**self.body, "installationId": "b" * 32})
        self.assertEqual(err.exception.status, 409)

    def test_no_duplicate_after_upstream_timeout(self):
        self.upstream.fail = True
        with self.assertRaises(EnrollmentError):
            self.service.enroll(self.body)
        self.service.enroll(self.body)
        self.assertEqual(len(set(self.upstream.calls)), 1)
        self.assertEqual(len(self.upstream.devices), 1)

    def test_invalid_code(self):
        with self.assertRaises(EnrollmentError):
            self.service.enroll({**self.body, "activationCode": "invalid"})
        self.assertEqual(self.upstream.calls, [])

    def test_unknown_code(self):
        with self.assertRaises(EnrollmentError) as err:
            self.service.enroll({**self.body, "activationCode": "x" * 43})
        self.assertEqual(err.exception.status, 403)

    def test_expired_code(self):
        db = connect(self.db)
        with db:
            db.execute("UPDATE enrollment SET expires=0")
        db.close()
        with self.assertRaises(EnrollmentError) as err:
            self.service.enroll(self.body)
        self.assertEqual(err.exception.status, 403)


class ScopeTests(unittest.TestCase):
    def setUp(self):
        self.upstream = Traccar("test-only-placeholder")
        self.account = {"administrator": False, "userLimit": 0, "readonly": False,
                        "deviceReadonly": False, "disabled": False, "deviceLimit": 100}
        self.upstream.request = Mock(return_value=self.account)

    def test_scoped_account(self):
        self.upstream.verify_scope()
        self.upstream.request.assert_called_once_with("GET", "session?token=test-only-placeholder")

    def test_reject_overprivileged_or_readonly_accounts(self):
        for changes in ({"administrator": True}, {"userLimit": -1}, {"deviceLimit": -1},
                        {"deviceLimit": True}, {"readonly": True}, {"deviceReadonly": True},
                        {"disabled": True}):
            with self.subTest(changes=changes):
                self.upstream.request.return_value = {**self.account, **changes}
                with self.assertRaises(EnrollmentError):
                    self.upstream.verify_scope()

    def test_missing_scope_fields_fail_closed(self):
        self.upstream.request.return_value = {"administrator": False, "userLimit": 0, "deviceLimit": 100}
        with self.assertRaises(EnrollmentError):
            self.upstream.verify_scope()

    def test_invalid_token_http_status_is_sanitized(self):
        upstream = Traccar("test-only-placeholder")
        with patch("server.urllib.request.build_opener") as factory:
            factory.return_value.open.side_effect = HTTPError(
                "http://127.0.0.1:8082/api/session?token=test-only-placeholder", 400,
                "Bad Request", None, None)
            with self.assertRaises(EnrollmentError) as err:
                upstream.verify_scope()
            self.assertEqual(err.exception.message, "traccar_token_rejected_http_400")
            req = factory.return_value.open.call_args.args[0]
            self.assertNotIn("Authorization", req.headers)
            self.assertNotIn("Content-type", req.headers)

    def test_unconfigured_account(self):
        with self.assertRaises(EnrollmentError):
            Traccar("").verify_scope()


if __name__ == "__main__":
    unittest.main()
