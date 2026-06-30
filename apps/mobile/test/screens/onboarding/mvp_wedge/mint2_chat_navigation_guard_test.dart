import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coach surfaces route/explain RvC without invoking calculators', () {
    final roots = <Directory>[
      Directory('lib/screens/coach'),
      Directory('lib/widgets/coach'),
      Directory('lib/services/coach'),
    ];
    final forbiddenCalculatorHits = <String>[];
    final forbiddenNumberHits = <String>[];
    final routeReferences = <String>[];

    for (final root in roots) {
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final ref = '${entity.path}:${i + 1}';
          if (line.contains('/retraite/rente-vs-capital') ||
              line.contains('rente_vs_capital')) {
            routeReferences.add(ref);
            if (line.contains('CHF') ||
                line.contains('/mois') ||
                line.contains('%')) {
              forbiddenNumberHits.add('$ref: $line');
            }
          }
          if (line.contains('ArbitrageEngine.compareRenteVsCapital') ||
              line.contains('ApiService.compareRenteVsCapital') ||
              RegExp(r'(^|[^A-Za-z0-9_])computeRenteVsCapital\(')
                  .hasMatch(line)) {
            forbiddenCalculatorHits.add('$ref: $line');
          }
        }
      }
    }

    expect(routeReferences, isNotEmpty);
    expect(
      forbiddenCalculatorHits,
      isEmpty,
      reason: 'Coach may navigate/explain RvC, but must not calculate it.',
    );
    expect(
      forbiddenNumberHits,
      isEmpty,
      reason: 'Coach RvC route/explain lines must not carry financial numbers.',
    );
  });
}
