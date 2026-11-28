import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traccar_client/main.dart';
import 'package:traccar_client/password_service.dart';
import 'package:traccar_client/preferences.dart';

import 'geolocation_service.dart';
import 'l10n/app_localizations.dart';
import 'settings_screen.dart';
import 'provisioning_service.dart';
import 'status_screen.dart';
import 'update_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  bool trackingEnabled = false;
  bool enrolling = false;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshState();
    }
  }

  Future<void> _refreshState() async {
    final tracking = await GeolocationService.tracker.isTracking();
    if (!mounted) return;
    setState(() {
      trackingEnabled = tracking;
    });
  }

  void refresh() {
    if (mounted) _refreshState();
  }

  Future<void> _enrollDevice({bool linkExisting = false}) async {
    if (enrolling || trackingEnabled || (!linkExisting && !Preferences.canEnroll)) return;
    if (!await PasswordService.authenticate(context) || !mounted) return;
    final localizations = AppLocalizations.of(context)!;
    var enteredCode = "";
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(linkExisting ? localizations.enrollLinkExisting : localizations.enrollTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(linkExisting ? localizations.enrollLinkDescription : localizations.enrollNewDescription),
            TextField(
              onChanged: (value) => enteredCode = value,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: localizations.activationCodeLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(localizations.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, enteredCode.trim()),
            child: Text(localizations.enrollButton),
          ),
        ],
      ),
    );
    if (!mounted || code == null || code.isEmpty) return;
    setState(() => enrolling = true);
    try {
      await ProvisioningService.enroll(code, linkExisting: linkExisting);
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(localizations.enrollSuccess)),
      );
    } catch (_) {
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(localizations.enrollError)),
      );
    } finally {
      if (mounted) setState(() => enrolling = false);
    }
  }

  Widget _buildEnrollmentCard() {
    final strings = AppLocalizations.of(context)!;
    final registeredName = Preferences.instance.getString(Preferences.provisionedName);
    final deviceId = Preferences.instance.getString(Preferences.id) ?? '';
    final canLink = Preferences.instance.getString(Preferences.url) == ProvisioningService.gpsUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.enrollTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(registeredName != null
                ? strings.enrollConfirmed
                : (Preferences.canEnroll ? strings.enrollPendingLabel : strings.enrollManualLabel)),
            if (registeredName != null) Text(registeredName),
            SelectableText(deviceId),
            if (trackingEnabled && registeredName == null)
              Text(strings.enrollStopTracking),
            if (!canLink && registeredName == null)
              Text(strings.enrollServerMismatch),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (registeredName == null)
                  FilledButton.tonal(
                    onPressed: enrolling || trackingEnabled || !canLink
                        ? null : () => _enrollDevice(linkExisting: true),
                    child: Text(strings.enrollLinkExisting),
                  ),
                if (registeredName == null && Preferences.canEnroll)
                  FilledButton.tonal(
                    onPressed: enrolling || trackingEnabled
                        ? null : () => _enrollDevice(),
                    child: Text(enrolling ? strings.enrollingLabel : strings.enrollButton),
                  ),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: deviceId)),
                  icon: const Icon(Icons.copy),
                  label: Text(strings.enrollCopyId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.trackingTitle),
              titleTextStyle: Theme.of(context).textTheme.headlineMedium,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.idLabel),
              subtitle: Text(Preferences.instance.getString(Preferences.id) ?? ''),
            ),
            if (Platform.isAndroid) ...[
              Text(
                AppLocalizations.of(context)!.disclosureMessage,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.trackingLabel),
              value: trackingEnabled,
              onChanged: enrolling ? null : (bool value) async {
                if (await PasswordService.authenticate(context) && mounted) {
                  if (value) {
                    FirebaseCrashlytics.instance.log('tracking_toggle_start');
                    var started = false;
                    try {
                      await GeolocationService.start();
                      started = true;
                    } on PlatformException {
                      // permission denied or startup error
                    }
                    if (!mounted) return;
                    if (!started) {
                      messengerKey.currentState?.showSnackBar(
                        const SnackBar(
                          content: Text('Failed to start tracking. Check location permissions.'),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                    setState(() => trackingEnabled = started);
                  } else {
                    FirebaseCrashlytics.instance.log('tracking_toggle_stop');
                    await GeolocationService.stop();
                    if (mounted) setState(() => trackingEnabled = false);
                  }
                }
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: enrolling ? null : () async {
                    try {
                      await GeolocationService.requestPosition();
                    } on PlatformException {
                      // permission denied or location error
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.locationButton),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  onPressed: enrolling ? null : () async {
                    try {
                      await GeolocationService.requestPosition(alarm: 'sos');
                    } on PlatformException {
                      // permission denied or location error
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.sosAction),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const StatusScreen()));
                  },
                  child: Text(AppLocalizations.of(context)!.statusButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    final strings = AppLocalizations.of(context)!;
    setState(() => _checkingUpdate = true);
    try {
      final build = await UpdateService.currentBuild();
      final manifest = await UpdateService.check(build);
      if (!mounted) return;
      final message = manifest == null
          ? strings.updateNone
          : '${strings.updateAvailable}: ${manifest.version} (+${manifest.build})';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.updateCheck),
          content: Text('$message\n\n${strings.updateManualNotice}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK')),
          ],
        ),
      );
    } catch (_) {
      if (mounted) messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(strings.updateFailed)),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.settingsTitle),
              titleTextStyle: Theme.of(context).textTheme.headlineMedium,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.urlLabel),
              subtitle: Text(Preferences.instance.getString(Preferences.url) ?? ''),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: enrolling ? null : () async {
                    if (await PasswordService.authenticate(context) && mounted) {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                      setState(() {});
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.settingsButton),
                ),
                if (Platform.isAndroid)
                  TextButton.icon(
                    onPressed: _checkingUpdate ? null : _checkUpdate,
                    icon: const Icon(Icons.system_update),
                    label: Text(_checkingUpdate
                        ? AppLocalizations.of(context)!.updateChecking
                        : AppLocalizations.of(context)!.updateCheck),
                  ),
              ],
            ),
          ]
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZalGps'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (Platform.isAndroid) ...[
              _buildEnrollmentCard(),
              const SizedBox(height: 16),
            ],
            _buildTrackingCard(),
            const SizedBox(height: 16),
            _buildSettingsCard(),
          ],
        ),
      ),
    );
  }
}
