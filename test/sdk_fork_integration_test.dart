import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android build substitutes the official native SDK with the vendored fork', () {
    final settings = File('android/settings.gradle.kts').readAsStringSync();

    expect(settings, contains('includeBuild("../vendor/traccar-client-sdk")'));
    expect(
      settings,
      contains('substitute(module("org.traccar:traccar-client-sdk"))'),
    );
    expect(settings, contains('using(project(":core"))'));
  });

  test('forked SDK is pinned as a git submodule', () {
    final modules = File('.gitmodules').readAsStringSync();

    expect(modules, contains('[submodule "vendor/traccar-client-sdk"]'));
    expect(modules, contains('https://github.com/minhtuancn/traccar-client-sdk.git'));
  });

  test('GitHub CI checks out submodules before Flutter and Android builds', () {
    final workflow = File('.github/workflows/analyze.yml').readAsStringSync();

    expect(workflow, contains('submodules: recursive'));
  });
}
