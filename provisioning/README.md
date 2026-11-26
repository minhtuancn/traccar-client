# ZalGps enrollment service

The API is independent of Traccar and uses its documented REST API. It never modifies the Traccar database directly. No registration occurs until an operator creates an expiring one-use activation code and a client explicitly submits it. The server selects a cryptographically random device identifier and derives the display name from the submitted Android model. The identifier is reserved durably before the upstream call, so retries reuse the same identifier.

## Deploy and configure

1. Run `install-lxc112.sh` as root on prod-traccar (10.20.10.112). This adds a separate service on private port 8094 and does not restart Traccar or MySQL.
2. In Traccar, create a dedicated regular account for provisioning, with device limit 100 (adjust based on actual need), user limit 0, no administrator privileges, device editing enabled and limited commands. Generate a token in that account's Preferences. Never use an administrator token.
3. On LXC112, as root, store the token in `/etc/zalgps-provisioning/traccar-token` using a secure interactive prompt (not a command-line argument). Keep mode 0600, then restart only `zalgps-provisioning.service`. Verify `GET http://10.20.10.112:8094/readyz` returns 200. A tokenless or invalid service stays unavailable for registration.
4. In Nginx Proxy Manager, create `gps-api.go7s.net` -> HTTP `10.20.10.112:8094`, with Let's Encrypt certificate, Force SSL, no cache, no WebSockets. Test `/healthz`, `/readyz`, and an invalid enrollment request. Do not forward port 8094 directly on the WAN.
5. Issue one activation code, locally on the server:

   ```sh
   runuser -u zalgps-prov -- python3 /opt/zalgps-provisioning/server.py issue --ttl 900
   ```

   Deliver the code only to the authorized device operator. It expires in 15 minutes. A code can retry on the same installation but cannot enroll a second installation.

## API

- GET /healthz: liveness.
- GET /readyz: checks the Traccar account scope (non-admin, finite device limit, no user-management permissions).
- POST /v1/enroll: JSON activationCode, installationId (32 lowercase hex characters), model.
- Response: deviceId, name, serverUrl, config. The current client deliberately uses reviewed local tracking defaults, not arbitrary remote config. Enrollment does not start tracking.

No activation code, installation identifier, upstream token or request body is written to HTTP logs by the service. The database stores hashes of activation codes and installation identifiers. Back up the SQLite state securely. Keep unused activation codes private.

## Migration and rollback

Existing app installations are not automatically migrated. New installation enrollment is offered only before manual tracking/configuration. Never replace an existing tracked device's ID or pending queue. A reinstall needs a new activation code and an administrator must retire any old device intentionally. A lost response can be retried on the same installation until the code expires; operators should inspect the Traccar device list before issuing replacements.

Disable enrollment by stopping `zalgps-provisioning.service` and removing its dedicated proxy host; do not delete Traccar devices or the enrollment database. Retain the original GPS and web domains.

## Tests

```sh
cd provisioning
python3 -m unittest -v
```

Physical Android device and real Traccar enrollment tests are required before public release.
