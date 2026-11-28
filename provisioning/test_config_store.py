import sqlite3
import tempfile
import unittest
from pathlib import Path

from config_store import ConfigStore


class ConfigStoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = str(Path(self.tmp.name) / "isolated.sqlite")
        self.store = ConfigStore(self.path)
        self.a = self.store.register_for_test("installation-a", consent=True)
        self.b = self.store.register_for_test("installation-b", consent=True)

    def publish(self, installation, revision, settings):
        self.store.publish_for_test(installation, {"schema": 1, "revision": revision, "settings": settings})

    def test_isolation_and_ordered_partial_patches(self):
        self.publish("installation-a", 1, {"interval": 30})
        self.publish("installation-a", 3, {"distance": 25})
        self.publish("installation-b", 1, {"interval": 300})
        self.assertEqual(self.store.read(self.a, 0)["settings"], {"interval": 30})
        self.assertEqual(self.store.read(self.a, 1)["settings"], {"distance": 25})
        self.assertEqual(self.store.read(self.b, 0)["settings"], {"interval": 300})
        self.assertIsNone(self.store.read(self.a, 3))

    def test_requires_consent_and_rejects_unknown_credentials(self):
        with self.assertRaises(PermissionError):
            self.store.register_for_test("no-consent", consent=False)
        with self.assertRaises(PermissionError):
            self.store.read("x" * 43, 0)

    def test_revocation_and_stale_revision(self):
        self.publish("installation-a", 1, {"interval": 30})
        with self.assertRaises(ValueError):
            self.publish("installation-a", 1, {"interval": 60})
        self.store.revoke_for_test("installation-a")
        with self.assertRaises(PermissionError):
            self.store.read(self.a, 0)
        with self.assertRaises(PermissionError):
            self.publish("installation-a", 2, {"interval": 60})
        self.assertIsNone(self.store.read(self.b, 0))

    def test_restart_and_no_plaintext_credential(self):
        self.publish("installation-a", 1, {"interval": 30})
        self.store = ConfigStore(self.path)
        self.assertEqual(self.store.read(self.a, 0)["revision"], 1)
        with sqlite3.connect(self.path) as db:
            row = db.execute("SELECT token_hash FROM config_installations WHERE installation='installation-a'").fetchone()
        self.assertNotEqual(row[0], self.a)
        self.assertEqual(len(row[0]), 64)
