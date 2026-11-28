import unittest

from config_policy import validate_patch


class ConfigPolicyTests(unittest.TestCase):
    def patch(self, settings, revision=2, current=1):
        return validate_patch({"schema": 1, "revision": revision, "settings": settings}, current)

    def test_valid(self):
        settings = {"interval": 30, "distance": 25, "adaptive_tracking": True, "sync_mode": "batch"}
        self.assertEqual(self.patch(settings), (2, settings))

    def test_forbidden_fields(self):
        for key in ("id", "url", "tracking", "enabled", "location_commands_allowed", "permissions",
                    "wakelock", "buffer", "password", "notification", "installationId"):
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.patch({key: True})

    def test_ranges_and_exact_types(self):
        for settings in ({"interval": True}, {"interval": 0}, {"distance": 1001},
                         {"heartbeat": "300"}, {"sync_mode": []}, {"accuracy": "highest"},
                         {"adaptive_tracking": 1}, {"heartbeat_max_age": 0}, {}):
            with self.subTest(settings=settings), self.assertRaises(ValueError):
                self.patch(settings)

    def test_replay_and_invalid_revision(self):
        for revision in (0, 1, True, "2", 2**53):
            with self.subTest(revision=revision), self.assertRaises(ValueError):
                self.patch({"interval": 30}, revision=revision)

    def test_schema_and_unknown_envelope_fields(self):
        for envelope in ({"schema": True, "revision": 2, "settings": {"interval": 30}},
                         {"schema": 1, "revision": 2, "settings": {"interval": 30}, "deviceId": "test"}):
            with self.assertRaises(ValueError):
                validate_patch(envelope, 1)


if __name__ == "__main__":
    unittest.main()
