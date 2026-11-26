import unittest
from verify_apk_signer import verify

FINGERPRINT = "1779fcc58da759bb71b1b65995039fa1cab6205361d53095005565e8dc52367f"


class VerifySignerTests(unittest.TestCase):
    def test_actual_ci_format(self):
        report = ("Verifies\nNumber of signers: 1\n"
                  "V2 Signer: certificate DN: CN=ZalGps\n"
                  f"V2 Signer: certificate SHA-256 digest: {FINGERPRINT}\n"
                  f"V2 Signer: public key SHA-256 digest: {'a' * 64}\n")
        self.assertEqual(verify(report, FINGERPRINT), FINGERPRINT)

    def test_legacy_format(self):
        self.assertEqual(verify(f"Number of signers: 1\nSigner #1 certificate DN: CN=ZalGps\nSigner #1 certificate SHA-256 digest: {FINGERPRINT}\n", FINGERPRINT), FINGERPRINT)

    def test_multi_scheme_same_certificate(self):
        report = (f"Number of signers: 1\nV2 Signer: certificate SHA-256 digest: {FINGERPRINT}\n"
                  f"V3 Signer: certificate SHA-256 digest: {FINGERPRINT}\n")
        self.assertEqual(verify(report, FINGERPRINT), FINGERPRINT)

    def test_reject_wrong_missing_or_multiple_signers(self):
        for report in (
            f"Number of signers: 1\nV2 Signer: certificate SHA-256 digest: {'a' * 64}\n",
            f"Number of signers: 1\nV2 Signer: public key SHA-256 digest: {FINGERPRINT}\n",
            f"Number of signers: 2\nV2 Signer: certificate SHA-256 digest: {FINGERPRINT}\n",
            f"Number of signers: 1\nV2 Signer: certificate SHA-256 digest: {FINGERPRINT}\nV3 Signer: certificate SHA-256 digest: {'a' * 64}\n",
        ):
            with self.subTest(report=report):
                with self.assertRaises(ValueError):
                    verify(report, FINGERPRINT)


if __name__ == "__main__":
    unittest.main()
