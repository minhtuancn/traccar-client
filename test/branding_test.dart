import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ZalGps branding is wired into app surfaces', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final strings = File('android/app/src/main/res/values/strings.xml').readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final mainScreen = File('lib/main_screen.dart').readAsStringSync();
    expect(manifest, contains('android:label="@string/app_name"'));
    expect(strings, contains('<string name="app_name">ZalGps</string>'));
    expect(infoPlist, contains('<string>ZalGps</string>'));
    expect(mainScreen, contains("title: const Text('ZalGps')"));
  });

  test('ZalGps launcher icon source and generator are committed', () {
    expect(File('assets/branding/zalgps_icon.svg').existsSync(), isTrue);
    expect(File('assets/branding/zalgps_foreground.svg').existsSync(), isTrue);
    final generator = File('tool/generate_branding.sh').readAsStringSync();
    expect(generator, contains('flutter_launcher_icons'));
    expect(generator, contains('zalgps_icon.svg'));
  });
}
