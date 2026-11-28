/// Strict manifest for the official, opt-in ZalGps beta update channel.
/// This is metadata only; it does not authorize installation.
class UpdateManifest {
  const UpdateManifest._(this.version, this.build, this.apk, this.sha256, this.size);

  static const repository = 'minhtuancn/traccar-client';
  static const certificate = '1779fcc58da759bb71b1b65995039fa1cab6205361d53095005565e8dc52367f';
  final String version;
  final int build;
  final Uri apk;
  final String sha256;
  final int size;

  static UpdateManifest parse(Object? value) {
    if (value is! Map<String, dynamic>) throw const FormatException('Invalid update metadata');
    final version = value['version'];
    final build = value['versionCode'];
    final hash = value['sha256'];
    final size = value['size'];
    if (value['schema'] != 1 ||
        value['applicationId'] != 'org.traccar.client' ||
        value['certificateSha256'] != certificate ||
        version is! String || !RegExp(r'^\d+\.\d+\.\d+-beta\.\d+$').hasMatch(version) ||
        build is! int || build <= 0 || build > 2100000000 ||
        hash is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        size is! int || size <= 0 || size > 200 * 1024 * 1024) {
      throw const FormatException('Invalid update metadata');
    }
    final expected = 'https://github.com/$repository/releases/download/v$version/zalgps-$version.apk';
    if (value['apkUrl'] != expected) throw const FormatException('Untrusted APK URL');
    return UpdateManifest._(version, build, Uri.parse(expected), hash, size);
  }

  bool isNewerThan(int currentBuild) => build > currentBuild;
}
