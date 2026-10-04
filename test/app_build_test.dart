import 'dart:io';

import 'package:astra/app_build.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kAppBuild matches the build number in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*\S+\+(\d+)', multiLine: true)
        .firstMatch(pubspec);
    expect(match, isNotNull);
    expect(int.parse(match!.group(1)!), kAppBuild);
  });
}
