# Android managed-device mode

This fork supports two Android deployment modes:

1. Standard application mode. The Traccar SDK runs location tracking as a foreground location service and restores tracking after reboot or app update when tracking was previously enabled.
2. Managed-device mode. Provision the app as Device Owner on a dedicated device to get the Android-supported management privileges intended for company-owned or purpose-built devices.

Managed-device mode does not hide the process from Android system management. The application can be excluded from the Recent Apps screen, while Android may still show an active foreground service and its notification.

## Provisioning

Device Owner provisioning is intended for a freshly provisioned device without existing accounts or another Device Owner/Profile Owner.

For development devices, install the APK first and then provision the receiver:

```bash
adb shell dpm set-device-owner org.traccar.client/.ManagedDeviceAdminReceiver
```

Verify:

```bash
adb shell dpm list-owners
adb shell dumpsys device_policy
```

Remove Device Owner only on development/test devices using Android-supported device-policy tooling or by factory resetting the device when required by the platform/OEM.

## Background tracking

The app uses `traccar_client_sdk`, whose Android manifest provides background location, foreground-service location, boot-completed, notification, and wake-lock permissions/components. The SDK's boot receiver handles `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED`, and its tracker service uses `START_STICKY`.

For reliable tracking, grant Always/Background location access, allow notifications, keep location services enabled, and avoid placing the app in the OEM battery "Restricted" state.

## Recent Apps

`MainActivity` is marked `android:excludeFromRecents="true"`. This removes the UI task from the Recent Apps overview; it does not attempt to conceal the Android process or foreground service from system administration surfaces.

## System/privileged app builds

A true `/system/priv-app` installation requires control of the Android system image, platform/privileged permission allowlists, and appropriate signing. Do not add platform signing keys or `sharedUserId=android.uid.system` to this public repository. Keep any OEM/system-image integration in a private build/release pipeline.
