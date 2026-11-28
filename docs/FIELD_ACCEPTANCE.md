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
