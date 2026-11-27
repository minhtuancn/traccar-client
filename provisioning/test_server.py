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

    def find_existing_device(self, unique_id):
        if unique_id not in self.devices:
            raise EnrollmentError(403, "existing_device_unavailable")
        return self.devices[unique_id], "Existing vehicle"

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

    def test_link_existing_does_not_create_or_change_id(self):
        self.upstream.devices["12345678"] = 42
        code = issue(self.db, 900, "12345678")
        body = {**self.body, "activationCode": code, "existingDeviceId": "12345678"}
        one = self.service.enroll(body)
        self.assertEqual(one, self.service.enroll(body))
        self.assertEqual(one["deviceId"], "12345678")
        self.assertEqual(one["name"], "Existing vehicle")
        self.assertEqual(self.upstream.calls, [])
        self.assertEqual(self.upstream.devices, {"12345678": 42})
        with self.assertRaises(EnrollmentError) as err:
            self.service.enroll({**body, "installationId": "b" * 32})
        self.assertEqual(err.exception.status, 409)

    def test_link_code_bound_to_exact_id_and_mode(self):
        code = issue(self.db, 900, "12345678")
        for body in ({**self.body, "activationCode": code},
                     {**self.body, "activationCode": code, "existingDeviceId": "87654321"},
                     {**self.body, "existingDeviceId": "12345678"}):
            with self.assertRaises(EnrollmentError) as err:
                self.service.enroll(body)
            self.assertEqual(err.exception.status, 403)
        self.assertEqual(self.upstream.calls, [])

    def test_link_missing_device_never_creates_it(self):
        code = issue(self.db, 900, "12345678")
        with self.assertRaises(EnrollmentError):
            self.service.enroll({**self.body, "activationCode": code, "existingDeviceId": "12345678"})
        self.assertEqual(self.upstream.devices, {})

    def test_reissue_invalidates_unused_link_code(self):
        old = issue(self.db, 900, "12345678")
        new = issue(self.db, 900, "12345678")
        self.upstream.devices["12345678"] = 42
        body = {**self.body, "existingDeviceId": "12345678"}
        with self.assertRaises(EnrollmentError):
            self.service.enroll({**body, "activationCode": old})
        self.assertEqual(self.service.enroll({**body, "activationCode": new})["deviceId"], "12345678")

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

    def test_scope_diagnostic_identifies_fields(self):
        self.upstream.request.return_value = {**self.account, "deviceLimit": -1, "userLimit": 5}
        with self.assertRaises(EnrollmentError) as err:
            self.upstream.verify_scope()
        self.assertIn("deviceLimit=-1 (required 1..1000)", err.exception.message)
        self.assertIn("userLimit=5 (required 0)", err.exception.message)

    def test_existing_device_lookup_only_uses_scoped_get(self):
        self.upstream.request.side_effect = [self.account, [{"id": 42, "uniqueId": "12345678", "name": "Vehicle", "disabled": False}]]
        self.assertEqual(self.upstream.find_existing_device("12345678"), (42, "Vehicle"))
        self.assertEqual(self.upstream.request.call_args.args, ("GET", "devices?uniqueId=12345678"))

    def test_unconfigured_account(self):
        with self.assertRaises(EnrollmentError):
            Traccar("").verify_scope()


if __name__ == "__main__":
    unittest.main()
