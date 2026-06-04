import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _primaryScreenFiles = [
  'lib/screens/budget/budget_container_screen.dart',
  'lib/screens/budget/budget_screen.dart',
  'lib/screens/budget/budget_setup_screen.dart',
  'lib/screens/coach/coach_chat_screen.dart',
  'lib/screens/profile/financial_summary_screen.dart',
  'lib/screens/advisor/financial_report_screen_v2.dart',
  'lib/screens/document_scan/document_scan_screen.dart',
  'lib/screens/explore/explorer_screen.dart',
  'lib/screens/mon_argent/mon_argent_screen.dart',
];

void main() {
  group('Row 23 primary-screen design contract', () {
    test('primary screens do not use negative letter spacing', () {
      final failures = <String>[];
      final pattern = RegExp(r'letterSpacing:\s*-\d');

      for (final path in _primaryScreenFiles) {
        final file = File(path);
        if (!file.existsSync()) {
          failures.add('$path missing');
          continue;
        }
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) {
            failures.add('$path:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        failures,
        isEmpty,
        reason: 'Primary screens must keep letter spacing non-negative:\n'
            '${failures.join('\n')}',
      );
    });
  });
}
