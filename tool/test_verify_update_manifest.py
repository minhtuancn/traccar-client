import tempfile
import unittest
from pathlib import Path
from generate_update_manifest import generate
from verify_release_metadata import CERTIFICATE, sha256


class UpdateManifestTests(unittest.TestCase):
    def test_exact_artifact_binding(self):
        with tempfile.TemporaryDirectory() as tmp:
            apk = Path(tmp) / "zalgps-10.2.0-beta.6.apk"
            apk.write_bytes(b"test fixture")
            result = generate(apk, "10.2.0-beta.6+164", CERTIFICATE)
            self.assertEqual(result["sha256"], sha256(apk))
            self.assertEqual(result["versionCode"], 164)
            self.assertEqual(result["size"], apk.stat().st_size)
            for version, cert in [("10.2.0-beta.5+163", CERTIFICATE), ("10.2.0-beta.6+0", CERTIFICATE), ("10.2.0-beta.6+164", "wrong")]:
                with self.assertRaises(ValueError):
                    generate(apk, version, cert)
