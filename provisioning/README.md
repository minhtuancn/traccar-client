# ZalGps enrollment service

The API is independent of Traccar and uses its documented REST API. It never modifies the Traccar database directly. No registration occurs until an operator creates an expiring one-use activation code and a client explicitly submits it. For a new device, the server selects a cryptographically random identifier and derives the display name from the submitted Android model. Existing-device linking uses the current identifier without creating a device. The identifier is reserved durably before the upstream call, so retries reuse the same identifier.

## Deploy and configure

1. Run `install-lxc112.sh` as root on prod-traccar (10.20.10.112). This adds a separate service on private port 8094 and does not restart Traccar or MySQL.
2. In Traccar, create a dedicated regular account for provisioning, with device limit 100 (adjust based on actual need), user limit 0, no administrator privileges, device editing enabled and limited commands. Generate a token in that account's Preferences. Never use an administrator token.
3. On LXC112, run `python3 /opt/zalgps-provisioning/configure-token.py` as root and paste the scoped token into the hidden prompt. The helper checks its scope before writing the credential (mode 0600), restarts only the enrollment service, and restores the prior credential if readiness fails. Verify `GET http://10.20.10.112:8094/readyz` returns 200. A tokenless or invalid service stays unavailable for registration.
4. In Nginx Proxy Manager, create `gps-api.go7s.net` -> HTTP `10.20.10.112:8094`, with Let's Encrypt certificate, Force SSL, no cache, no WebSockets. Test `/healthz`, `/readyz`, and an invalid enrollment request. Do not forward port 8094 directly on the WAN.
5. Issue one activation code, locally on the server:

   ```sh
   runuser -u zalgps-prov -- python3 /opt/zalgps-provisioning/server.py issue --ttl 900
   ```

   Deliver the code only to the authorized device operator. It expires in 15 minutes. A code can retry on the same installation but cannot enroll a second installation.

### Link a manually registered device (beta.5+)

First assign the existing Traccar device to the scoped ZalGPS service account in the Traccar administrator dashboard. Do not create another device or change the existing identifier. On LXC112, issue an activation code explicitly bound to its identifier:

```sh
runuser -u zalgps-prov -- python3 /opt/zalgps-provisioning/server.py issue --ttl 900 --existing-id DEVICE_ID
```

In ZalGps, stop tracking and choose **Link existing device**. The code is valid only for that exact ID and one installation. The server performs a scoped read-only lookup; it never creates or renames the existing device. The client preserves its server, ID, tracking settings and queued positions. If the device is missing, disabled or not visible to the service account, linking fails closed. Never send an activation code in chat or logs.

## API

- GET /healthz: liveness.
- GET /readyz: checks the Traccar account scope (non-admin, finite device limit, no user-management permissions). The upstream session identity request uses the documented token query parameter over loopback only; do not enable upstream access logging of full query strings. All upstream requests reject redirects and ignore environment HTTP proxies.
- POST /v1/enroll: JSON activationCode, installationId (32 lowercase hex characters), model, optional existingDeviceId for an operator-issued link code.
- Response: deviceId, name, serverUrl, config. The current client deliberately uses reviewed local tracking defaults, not arbitrary remote config. Enrollment does not start tracking.

No activation code, installation identifier, upstream token or request body is written to HTTP logs by the service. The database stores hashes of activation codes and installation identifiers. Back up the SQLite state securely. Keep unused activation codes private.

## Operational acceptance

Verify the public HTTPS readiness endpoint, then test new-device registration and existing-device linking on authorized phones. The presence of a manually added device in the dashboard is not evidence of API enrollment. Record only aggregate counts and pass/fail results; do not record activation codes, coordinates, installation secrets, tokens, or personal device IDs in the public repository.

Before deploying an update, back up the service code and SQLite using SQLite's backup API, validate the backup, run backend regression tests, and restart only the provisioning service. Verify readiness and SQLite integrity after deployment. For additive schema changes, roll back code without restoring a stale database over new enrollment records. Do not modify the Traccar database directly.

## Migration and rollback

Existing app installations are not automatically migrated. New-ID enrollment is offered only before manual tracking/configuration; existing installations may explicitly link their current ID with a bound code. Never replace an existing tracked device's ID or pending queue. A reinstall needs a new activation code and an administrator must retire any old device intentionally. A lost response can be retried on the same installation until the code expires; operators should inspect the Traccar device list before issuing replacements.

Disable enrollment by stopping `zalgps-provisioning.service` and removing its dedicated proxy host; do not delete Traccar devices or the enrollment database. Retain the original GPS and web domains.

## Tests

```sh
cd provisioning
python3 -m unittest -v
```

Physical Android device and real Traccar enrollment tests are required before public release.
