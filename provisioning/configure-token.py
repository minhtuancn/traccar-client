"""Activate enrollment using a scoped token entered locally, never on the CLI."""
import getpass
import os
from pathlib import Path
import subprocess
import tempfile
import urllib.request

from server import EnrollmentError, Traccar

TARGET = Path("/etc/zalgps-provisioning/traccar-token")
UNIT = "zalgps-provisioning.service"


def atomic_write(value):
    fd, name = tempfile.mkstemp(prefix=".token-", dir=TARGET.parent)
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(value)
            out.flush()
            os.fsync(out.fileno())
        os.chmod(name, 0o600)
        os.replace(name, TARGET)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def main():
    if os.geteuid() != 0 or not os.isatty(0):
        raise SystemExit("Run interactively as root on LXC112.")
    if not TARGET.is_file():
        raise SystemExit("Install zalgps-provisioning first.")
    token = getpass.getpass("Scoped Traccar API token (hidden): ").strip()
    if not token:
        raise SystemExit("No token entered; no change made.")
    try:
        Traccar(token).verify_scope()
    except EnrollmentError as error:
        raise SystemExit(f"Token rejected: {error.message}; no change made.") from None
    old = TARGET.read_bytes()
    try:
        atomic_write((token + "\n").encode())
        subprocess.run(["systemctl", "restart", UNIT], check=True)
        import time
        for _ in range(8):
            try:
                with urllib.request.urlopen("http://10.20.10.112:8094/readyz", timeout=3) as response:
                    if response.status == 200:
                        print("Enrollment API ready: HTTP 200.")
                        return
            except OSError:
                time.sleep(1)
        raise RuntimeError("Readiness check failed")
    except Exception:
        atomic_write(old)
        subprocess.run(["systemctl", "restart", UNIT], check=True)
        raise SystemExit("Activation failed; previous credential restored.") from None


if __name__ == "__main__":
    main()
