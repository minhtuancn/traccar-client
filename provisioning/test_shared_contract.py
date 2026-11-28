import json
import unittest
from pathlib import Path

from config_policy import validate_patch


class SharedContractTests(unittest.TestCase):
    def test_server_fixtures(self):
        path = Path(__file__).resolve().parents[1] / "test/fixtures/client-control/v1/config-cases.json"
        cases = json.loads(path.read_text())
        for case in cases:
            with self.subTest(case=case["name"]):
                if case["accepted"]:
                    revision, settings = validate_patch(case["payload"], case["currentRevision"])
                    self.assertEqual(revision, case["payload"]["revision"])
                    self.assertEqual(settings, case["payload"]["settings"])
                else:
                    with self.assertRaises(ValueError):
                        validate_patch(case["payload"], case["currentRevision"])
