import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'EPL and rente-capital completion payloads never expose scenario outputs',
    () {
      const callers = <String, String>{
        'EPL': 'lib/screens/lpp_deep/epl_screen.dart',
        'rente-capital': 'lib/screens/arbitrage/rente_vs_capital_screen.dart',
      };

      for (final caller in callers.entries) {
        final source = File(caller.value).readAsStringSync();
        expect(
          source,
          isNot(contains('stepOutputs: {')),
          reason: '${caller.key} persists raw scenario outputs instead of an '
              'opaque scenario ID and status',
        );
      }
    },
  );
}
