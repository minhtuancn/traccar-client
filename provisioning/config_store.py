"""Staging-only config store. No production API or tracking controls.

Enrollment/consent is not wired yet. Use only in isolated tests until a reviewed
device-authentication and authorization workflow exists.
"""
import hashlib
import json
import secrets
import sqlite3
from contextlib import closing

from config_policy import validate_patch


class ConfigStore:
    def __init__(self, path):
        self.path = path
        with closing(self._connect()) as db, db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS config_installations (
                    installation TEXT PRIMARY KEY,
                    token_hash TEXT NOT NULL UNIQUE,
                    consent INTEGER NOT NULL CHECK(consent IN (0,1)),
                    revoked INTEGER NOT NULL DEFAULT 0,
                    revision INTEGER NOT NULL DEFAULT 0
                );
                CREATE TABLE IF NOT EXISTS config_revisions (
                    installation TEXT NOT NULL REFERENCES config_installations(installation),
                    revision INTEGER NOT NULL,
                    settings TEXT NOT NULL,
                    PRIMARY KEY(installation, revision)
                );
            """)

    def _connect(self):
        db = sqlite3.connect(self.path, timeout=5)
        db.execute("PRAGMA foreign_keys=ON")
        return db

    @staticmethod
    def _hash(token):
        if type(token) is not str or len(token) != 43:
            raise PermissionError("invalid credential")
        return hashlib.sha256(token.encode()).hexdigest()

    def register_for_test(self, installation, *, consent):
        """Explicit staging setup only. Never derive a credential from device ID."""
        if consent is not True or type(installation) is not str or not installation or len(installation) > 128:
            raise PermissionError("explicit consent required")
        token = secrets.token_urlsafe(32)
        with closing(self._connect()) as db, db:
            db.execute("INSERT INTO config_installations(installation,token_hash,consent) VALUES(?,?,1)",
                       (installation, self._hash(token)))
        return token

    def publish_for_test(self, installation, payload):
        """Mock trusted administrator path, not exposed over HTTP."""
        with closing(self._connect()) as db, db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT revision FROM config_installations WHERE installation=? AND consent=1 AND revoked=0",
                             (installation,)).fetchone()
            if row is None:
                raise PermissionError("installation unavailable")
            revision, settings = validate_patch(payload, row[0])
            db.execute("INSERT INTO config_revisions VALUES(?,?,?)", (installation, revision, json.dumps(settings)))
            db.execute("UPDATE config_installations SET revision=? WHERE installation=?", (revision, installation))

    def read(self, token, after_revision):
        """Bind lookup solely to the credential's installation; no caller-supplied device ID."""
        if type(after_revision) is not int or after_revision < 0:
            raise ValueError("invalid revision")
        digest = self._hash(token)
        with closing(self._connect()) as db:
            row = db.execute("SELECT installation,revision FROM config_installations WHERE token_hash=? AND consent=1 AND revoked=0",
                             (digest,)).fetchone()
            if row is None:
                raise PermissionError("invalid credential")
            # Deliver next revision in order, not a later partial patch.
            item = db.execute("SELECT revision,settings FROM config_revisions WHERE installation=? AND revision>? ORDER BY revision LIMIT 1",
                              (row[0], after_revision)).fetchone()
            return None if item is None else {"schema": 1, "revision": item[0], "settings": json.loads(item[1])}

    def revoke_for_test(self, installation):
        with closing(self._connect()) as db, db:
            db.execute("UPDATE config_installations SET revoked=1 WHERE installation=?", (installation,))
