import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'update_manifest.dart';

/// Explicit user-initiated check only. No installation or tracking changes.
class UpdateService {
  static const _channel = MethodChannel('zalgps/update_info');
  static final _releases = Uri.https('api.github.com',
      '/repos/${UpdateManifest.repository}/releases', {'per_page': '20'});

  static Future<int> currentBuild() async {
    final build = await _channel.invokeMethod<int>('versionCode');
    if (build == null || build <= 0) throw StateError('Unknown installed build');
    return build;
  }

  static bool trustedAssetRedirect(Uri uri) =>
      uri.scheme == 'https' && uri.userInfo.isEmpty && !uri.hasPort &&
      const {'release-assets.githubusercontent.com', 'objects.githubusercontent.com'}
          .contains(uri.host);

  static Future<Object?> _readJson(HttpClient client, Uri url, int limit,
      {bool asset = false}) async {
    for (var hop = 0; hop < 3; hop++) {
      final request = await client.getUrl(url).timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (asset && const {301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) throw const FormatException('Missing asset redirect');
        final next = url.resolve(location);
        if (!trustedAssetRedirect(next)) throw const FormatException('Untrusted asset redirect');
        // Cancel rather than read an unbounded redirect response.
        final subscription = response.listen((_) {});
        await subscription.cancel();
        url = next;
        continue;
      }
      if (response.statusCode != 200) {
        throw HttpException('Update check failed (${response.statusCode})');
      }
      if (response.contentLength > limit) throw const FormatException('Metadata too large');
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        if (bytes.length + chunk.length > limit) throw const FormatException('Metadata too large');
        bytes.addAll(chunk);
      }
      return jsonDecode(utf8.decode(bytes));
    }
    throw const FormatException('Too many asset redirects');
  }

  /// Match the manifest to the actual published release assets before offering it.
  static Map<String, dynamic>? candidate(Object? release) {
    if (release is! Map<String, dynamic> ||
        release['draft'] != false || release['prerelease'] != true ||
        release['published_at'] is! String) return null;
    final tag = release['tag_name'];
    if (tag is! String || !RegExp(r'^v\d+\.\d+\.\d+-beta\.\d+$').hasMatch(tag)) return null;
    final version = tag.substring(1);
    final assets = release['assets'];
    if (assets is! List) return null;
    final prefix = 'https://github.com/${UpdateManifest.repository}/releases/download/$tag/';
    final manifestName = 'zalgps-$version.update.json';
    final apkName = 'zalgps-$version.apk';
    final manifests = assets.whereType<Map<String, dynamic>>().where((a) => a['name'] == manifestName).toList();
    final apks = assets.whereType<Map<String, dynamic>>().where((a) => a['name'] == apkName).toList();
    if (manifests.length != 1 || apks.length != 1) return null;
    final metadata = manifests.single;
    final apk = apks.single;
    if (metadata['browser_download_url'] != '$prefix$manifestName' ||
        apk['browser_download_url'] != '$prefix$apkName' ||
        metadata['size'] is! int || (metadata['size'] as int) <= 0 ||
        (metadata['size'] as int) > 8192 ||
        apk['size'] is! int || (apk['size'] as int) <= 0 ||
        (apk['size'] as int) > 200 * 1024 * 1024 ||
        apk['digest'] is! String ||
        !RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(apk['digest'] as String)) return null;
    return {'version': version, 'manifest': '$prefix$manifestName',
      'apkSize': apk['size'], 'apkDigest': apk['digest']};
  }

  static Future<UpdateManifest?> check(int installedBuild) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      return await _check(client, installedBuild).timeout(const Duration(seconds: 35));
    } finally {
      client.close(force: true);
    }
  }

  static Future<UpdateManifest?> _check(HttpClient client, int installedBuild) async {
    final releases = await _readJson(client, _releases, 1024 * 1024);
    if (releases is! List) throw const FormatException('Invalid release list');
    UpdateManifest? best;
    // Bound the number of manifests fetched per check.
    var checked = 0;
    for (final release in releases) {
      final item = candidate(release);
      if (item == null) continue;
      if (++checked > 5) break;
      final manifest = UpdateManifest.parse(await _readJson(client,
          Uri.parse(item['manifest'] as String), 8192, asset: true));
      if (manifest.version != item['version'] || manifest.size != item['apkSize'] ||
          'sha256:${manifest.sha256}' != item['apkDigest']) {
        throw const FormatException('Release metadata mismatch');
      }
      if (manifest.isNewerThan(installedBuild) &&
          (best == null || manifest.build > best.build)) best = manifest;
    }
    return best;
  }
}
