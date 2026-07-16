import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _balancedMapAfter(String source, String marker) {
  final markerOffset = source.indexOf(marker);
  if (markerOffset < 0) return '';
  final mapStart = source.indexOf('{', markerOffset + marker.length);
  if (mapStart < 0) return '';

  var depth = 0;
  for (var index = mapStart; index < source.length; index++) {
    switch (source[index]) {
      case '{':
        depth++;
        break;
      case '}':
        depth--;
        if (depth == 0) return source.substring(mapStart, index + 1);
        break;
    }
  }
  return '';
}

String _withoutWhitespace(String value) => value.replaceAll(RegExp(r'\s+'), '');

void main() {
  test('BYOK generate_financial_plan schema is intent-only and closed', () {
    final source =
        File('lib/services/coach/coach_orchestrator.dart').readAsStringSync();
    final toolStart = source.indexOf("'name': 'generate_financial_plan'");
    final toolEnd = source.indexOf("'name': 'record_check_in'", toolStart);
    final toolSource = toolStart < 0 || toolEnd < 0
        ? ''
        : source.substring(toolStart, toolEnd);
    final schema = _balancedMapAfter(toolSource, "'input_schema':");

    expect(
      _withoutWhitespace(schema),
      _withoutWhitespace("""
        {
          'type': 'object',
          'properties': {
            'goal': {'type': 'string'},
          },
          'required': ['goal'],
          'additionalProperties': false,
        }
      """),
      reason: 'BYOK may provide only a goal display hint. Flutter owns '
          'category, amount, date, final confirmation, calculation, and save.',
    );
  });
}
