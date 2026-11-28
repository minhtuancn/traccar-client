"""Read-only verification of a downloaded ZalGps release and GitHub metadata."""
import argparse
import hashlib
import json
import re
from pathlib import Path

CERTIFICATE = "1779fcc58da759bb71b1b65995039fa1cab6205361d53095005565e8dc52367f"


def sha256(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def verify(release, directory, version, commit, run_id):
    if not re.fullmatch(r"\d+\.\d+\.\d+-beta\.\d+", version):
        raise ValueError("Invalid beta version")
    if not re.fullmatch(r"[a-f0-9]{40}", commit) or not re.fullmatch(r"\d+", run_id):
        raise ValueError("Invalid expected commit/run")
    name = f"zalgps-{version}.apk"
    if release.get("tag_name") != f"v{version}" or release.get("target_commitish") != commit:
        raise ValueError("Release tag or target commit mismatch")
    if release.get("prerelease") is not True:
        raise ValueError("Not a beta pre-release")
    assets = release.get("assets", [])
    def asset(filename):
        matches = [item for item in assets if item.get("name") == filename]
        if len(matches) != 1:
            raise ValueError(f"Expected exactly one asset: {filename}")
        item = matches[0]
        file = directory / filename
        digest = sha256(file)
        if item.get("digest") != "sha256:" + digest or item.get("size") != file.stat().st_size:
            raise ValueError(f"Asset digest or size mismatch: {filename}")
        return digest, file.stat().st_size

    digest, size = asset(name)
    asset(name + ".sha256")
    checksum = (directory / (name + ".sha256")).read_text(encoding="ascii").strip()
    if checksum != f"{digest}  {name}":
        raise ValueError("Checksum file does not identify the exact APK")
    expected = {
        "Run ID": run_id, "Commit": commit, "APK": name,
        "APK size": str(size), "APK SHA-256": digest,
        "Signing certificate SHA-256": CERTIFICATE,
    }
    body = release.get("body") or ""
    for label, value in expected.items():
        matches = re.findall(r"^- " + re.escape(label) + r": `([^`\r\n]+)`(?: bytes)?\r?$", body, re.M)
        if matches != [value]:
            raise ValueError(f"Release notes metadata mismatch: {label}")
    return {"version": version, "commit": commit, "run": run_id, "sha256": digest,
            "size": size, "draft": release.get("draft")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("metadata", type=Path)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()
    try:
        result = verify(json.loads(args.metadata.read_text()), args.directory,
                        args.version, args.commit, args.run_id)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, f"Release verification failed: {error}\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
