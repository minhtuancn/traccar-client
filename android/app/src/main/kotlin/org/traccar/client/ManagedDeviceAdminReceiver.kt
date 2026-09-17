package org.traccar.client

import android.app.admin.DeviceAdminReceiver

/**
 * Device admin entry point used when this APK is provisioned as Device Owner
 * on a dedicated/managed Android device.
 *
 * Provisioning is intentionally external to the app. Declaring this receiver
 * does not grant Device Owner privileges by itself.
 */
class ManagedDeviceAdminReceiver : DeviceAdminReceiver()
