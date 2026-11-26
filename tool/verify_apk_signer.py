"""Check the public apksigner report against the intended certificate."""
import re
import sys
from pathlib import Path

SIGNER_COUNT = re.compile(r"^\s*Number of signers:\s*(\d+)\s*$", re.M)
CERTIFICATE = re.compile(
    r"^\s*(?:Signer #\d+:?|V[1-4](?:\.\d+)? Signer(?: #\d+)?:)\s*"
    r"certificate SHA-256 digest:\s*([0-9a-fA-F:\s]+?)\s*$",
    re.M | re.I,
)


def verify(report, expected):
    counts = SIGNER_COUNT.findall(report)
    if counts != ["1"]:
        raise ValueError("Expected exactly one APK signer")
    fingerprints = {
        re.sub(r"[:\s]", "", value).lower()
        for value in CERTIFICATE.findall(report)
    }
    expected = re.sub(r"[:\s]", "", expected).lower()
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise ValueError("Invalid expected certificate SHA-256")
    if fingerprints != {expected}:
        raise ValueError("APK signer certificate SHA-256 mismatch or missing digest")
    return expected


if __name__ == "__main__":
    try:
        print(verify(Path(sys.argv[1]).read_text(), sys.argv[2]))
    except ValueError as error:
        sys.exit(str(error))
