# Physical Android acceptance (P0/P3)

Use an explicitly authorized test device with the operator's knowledge and normal Android notifications. Do not interrupt deployed phones just to obtain evidence. Record only version, Android version, model, aggregate timing and pass/fail; exclude device IDs, coordinates and tokens.

| Test | Evidence required | Status |
| --- | --- | --- |
| Beta.4 to beta.5 upgrade | App works after upgrade | Operator confirmed |
| Identity/config/queue preservation | Compare before/after, no clear data | Pending |
| Existing-ID linking | Same identifier, no duplicate in dashboard | Pending |
| New-device enrollment | API count and on-device registration | One completed API enrollment; separate device evidence pending |
| GPS/history | Genuine history visible | Operator confirmed |
| Explicit Stop | Stop; verify no resumed tracking after reboot or watchdog | Pending |
| Ordinary reboot recovery | With tracking enabled, reboot with consent; inspect visible notification and sync | Pending |
| Offline queue | Record counts before/after short controlled outage and recovery | Pending |
| Stationary heartbeat | Confirm stale fix is not represented as fresh | Pending |
| Battery baseline | Measure battery drop, duration and profile on test device | Pending |

For battery comparisons use similar screen-on time, network and motion conditions; record starting/ending charge, hours, queue depth, profile, last successful sync and device power-saving setting. Compare battery percentage points/hour, not a projected runtime from a single reading. Keep the same app build when comparing settings. Do not disable Android protections or hide tracking indicators.

Diagnostics should never report stale values as fresh. Periodic refresh and manual refresh must not overlap; failed refresh should preserve last data and visibly mark it stale. No automatic changes to tracking settings or permissions during this diagnostic work.

## Candidate update installer acceptance (P1/P3)

On a separate authorized Android test phone, install the signed candidate with the normal installer. Check the official published-beta update source; confirm download is explicit and the second confirmation opens the Android installer only. Exercise missing install permission, network failure, low free space, mismatched SHA-256, wrong certificate/package, stale version, cancellation, and actual same-key upgrade. Verify tracking ID/settings/queue and visible notification are preserved after upgrade. Source-wiring tests and successful compilation alone do not establish installer behavior. The update feature adds REQUEST_INSTALL_PACKAGES for sideload use; any future Play-distributed variant needs a separate policy review and distribution-specific update path.
