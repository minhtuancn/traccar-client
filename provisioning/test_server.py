import tempfile
import unittest
from pathlib import Path

from server import Enrollment, EnrollmentError, issue, connect


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


if __name__ == "__main__":
    unittest.main()
