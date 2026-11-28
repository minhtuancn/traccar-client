"""Build metadata from the exact signed APK; never include signing secrets."""
import argparse
import json
import re
from pathlib import Path

from verify_release_metadata import CERTIFICATE, sha256


def generate(apk, full_version, certificate):
    match = re.fullmatch(r"(\d+\.\d+\.\d+-beta\.\d+)\+([1-9]\d*)", full_version)
    if not match or certificate != CERTIFICATE:
        raise ValueError("invalid version or signing certificate")
    version, build = match.group(1), int(match.group(2))
    size = apk.stat().st_size
    if apk.name != f"zalgps-{version}.apk" or not 0 < size <= 200 * 1024 * 1024 or build > 2100000000:
        raise ValueError("invalid APK name, size or build")
    return {
        "schema": 1, "applicationId": "org.traccar.client",
        "certificateSha256": certificate, "version": version, "versionCode": build,
        "apkUrl": f"https://github.com/minhtuancn/traccar-client/releases/download/v{version}/{apk.name}",
        "sha256": sha256(apk), "size": size,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("full_version")
    parser.add_argument("certificate")
    args = parser.parse_args()
    manifest = generate(args.apk, args.full_version, args.certificate)
    args.apk.with_suffix(".update.json").write_text(json.dumps(manifest, indent=2) + "\n")
