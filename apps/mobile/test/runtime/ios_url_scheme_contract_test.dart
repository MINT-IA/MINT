import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS registers the mint custom URL scheme for Maestro openLink', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('<key>CFBundleURLTypes</key>'));
    expect(plist, contains('<key>CFBundleURLSchemes</key>'));
    expect(plist, contains('<string>mint</string>'));
  });
}
