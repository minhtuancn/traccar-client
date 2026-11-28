import copy
import tempfile
import unittest
from pathlib import Path

from verify_release_metadata import CERTIFICATE, sha256, verify


class ReleaseMetadataTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)
        self.version, self.commit, self.run = "10.2.0-beta.5", "a" * 40, "123"
        self.name = "zalgps-" + self.version + ".apk"
        self.apk = self.directory / self.name
        self.apk.write_bytes(b"test-only APK")
        self.checksum = self.directory / (self.name + ".sha256")
        self.checksum.write_text(f"{sha256(self.apk)}  {self.name}\n")
        self.release = {
            "tag_name": "v" + self.version,
            "target_commitish": self.commit, "prerelease": True, "draft": True,
            "assets": [{"name": p.name, "size": p.stat().st_size, "digest": "sha256:" + sha256(p)}
                       for p in (self.apk, self.checksum)],
            "body": (f"- Run ID: `{self.run}`\n- Commit: `{self.commit}`\n"
                     f"- APK: `{self.name}`\n- APK size: `{self.apk.stat().st_size}` bytes\n"
                     f"- APK SHA-256: `{sha256(self.apk)}`\n"
                     f"- Signing certificate SHA-256: `{CERTIFICATE}`\n"),
        }

    def verify(self, release=None):
        return verify(self.release if release is None else release, self.directory,
                      self.version, self.commit, self.run)

    def test_valid(self):
        self.assertEqual(self.verify()["sha256"], sha256(self.apk))

    def test_stale_release_notes(self):
        for old, new in [(self.commit, "b" * 40), (self.run, "999"), (sha256(self.apk), "c" * 64), (CERTIFICATE, "d" * 64)]:
            with self.subTest(old=old):
                release = copy.deepcopy(self.release)
                release["body"] = release["body"].replace(old, new)
                with self.assertRaises(ValueError):
                    self.verify(release)

    def test_corrupted_apk(self):
        self.apk.write_bytes(b"corrupted APK")
        with self.assertRaises(ValueError):
            self.verify()

    def test_checksum_wrong_filename_even_with_matching_asset_digest(self):
        self.checksum.write_text(f"{sha256(self.apk)}  wrong.apk\n")
        self.release["assets"][1]["digest"] = "sha256:" + sha256(self.checksum)
        self.release["assets"][1]["size"] = self.checksum.stat().st_size
        with self.assertRaises(ValueError):
            self.verify()

    def test_duplicate_asset(self):
        self.release["assets"].append(self.release["assets"][0])
        with self.assertRaises(ValueError):
            self.verify()


if __name__ == "__main__":
    unittest.main()
