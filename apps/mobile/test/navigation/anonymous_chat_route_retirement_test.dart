import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('anonymous chat route retirement', () {
    test('/anonymous/chat no longer renders AnonymousChatScreen', () {
      final appSource = File('lib/app.dart').readAsStringSync();
      final routeMatch = RegExp(
        r"ScopedGoRoute\(\s*path:\s*'/anonymous/chat',[\s\S]*?\n    \),",
      ).firstMatch(appSource);

      expect(routeMatch, isNotNull);
      final routeBlock = routeMatch!.group(0)!;

      expect(routeBlock, contains('redirect:'));
      expect(routeBlock, isNot(contains('AnonymousChatScreen')));
    });
  });
}
