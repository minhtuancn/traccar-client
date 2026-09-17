import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:traccar_client_sdk/traccar_client_sdk.dart';

import 'enhanced_tracking_service.dart';
import 'geolocation_service.dart';
import 'l10n/app_localizations.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  static final _displayFormat = DateFormat('HH:mm:ss');
  static final _fullFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  List<LogEntry> _logs = const [];
  EnhancedTrackingStatus? _enhancedStatus;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final logs = await GeolocationService.tracker.getLogs();
    final status = await EnhancedTrackingService.getStatus();
    if (!mounted) return;
    setState(() {
      _logs = logs.reversed.toList(growable: false);
      _enhancedStatus = status;
    });
  }

  Future<void> _shareLogs() async {
    if (_logs.isEmpty) return;
    final text = _logs.reversed.map((entry) {
      final t = DateTime.fromMillisecondsSinceEpoch(entry.time);
      return '${_fullFormat.format(t)} ${entry.message}';
    }).join('\n');
    final box = context.findRenderObject() as RenderBox;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(utf8.encode(text), mimeType: 'text/plain')],
        fileNameOverrides: const ['logs.txt'],
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _clearLogs() async {
    await GeolocationService.tracker.clearLogs();
    if (!mounted) return;
    setState(() => _logs = const []);
  }

  String _formatLastSuccessfulSync(EnhancedTrackingStatus status) {
    final timestamp = status.lastSuccessfulSyncMillis;
    if (timestamp == null) return 'Never';
    return _fullFormat.format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  Widget _buildEnhancedStatus() {
    final status = _enhancedStatus;
    if (status == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.route),
              title: const Text('Tracking profile'),
              trailing: Text(status.profile.toUpperCase()),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.sync),
              title: const Text('Smart sync'),
              subtitle: Text(
                status.adaptiveEnabled
                    ? 'Adaptive profiles enabled'
                    : 'Adaptive profiles disabled',
              ),
              trailing: Text(status.syncMode.toUpperCase()),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.pending_actions),
              title: const Text('Queued positions'),
              trailing: Text(status.pendingPositionCount.toString()),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.cloud_done),
              title: const Text('Last successful sync'),
              subtitle: Text(_formatLastSuccessfulSync(status)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.statusTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildEnhancedStatus(),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _logs.length,
              itemBuilder: (_, index) {
                final entry = _logs[index];
                final t = DateTime.fromMillisecondsSinceEpoch(entry.time);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '${_displayFormat.format(t)} ${entry.message}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
