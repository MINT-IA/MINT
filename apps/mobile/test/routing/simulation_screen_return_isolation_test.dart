import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _confirmedConfidenceRoutes = <String, String>{
  'lib/screens/document_scan/document_impact_screen.dart': '/scan/impact',
};

class _ReturnCall {
  final String file;
  final String source;

  const _ReturnCall(this.file, this.source);

  String? get route => RegExp(
        r'''route\s*:\s*['"]([^'"]+)['"]''',
      ).firstMatch(source)?.group(1);

  bool get hasUpdatedFields => RegExp(r'\bupdatedFields\s*:').hasMatch(source);
  bool get hasConfidenceDelta =>
      RegExp(r'\bconfidenceDelta\s*:').hasMatch(source);
}

List<File> _productionScreenFiles() => Directory('lib/screens')
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

String _readBalancedCall(String source, int start) {
  var depth = 1;
  String? quote;
  var escaped = false;
  var end = start;
  for (; end < source.length && depth > 0; end += 1) {
    final char = source[end];
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
    } else if (char == '(') {
      depth += 1;
    } else if (char == ')') {
      depth -= 1;
    }
  }
  return source.substring(start, end);
}

List<_ReturnCall> _returnCalls(String file, String source) => [
      for (final match in RegExp(
        r'ScreenReturn(?:\.(?:completed|changedInputs))?\(',
      ).allMatches(source))
        _ReturnCall(file, _readBalancedCall(source, match.end)),
    ];

List<String> _violations(Iterable<_ReturnCall> calls) => [
      for (final call in calls)
        if (call.hasUpdatedFields)
          '${call.file} (${call.route}): simulation/metadata return uses '
              'updatedFields instead of stepOutputs',
      for (final call in calls)
        if (call.hasConfidenceDelta &&
            _confirmedConfidenceRoutes[call.file] != call.route)
          '${call.file} (${call.route}): unconfirmed interaction increases '
              'confidence',
    ];

void main() {
  group('ScreenReturn profile-write hard floor', () {
    test('matcher rejects hypothetical fields and confidence', () {
      const seededViolation = '''
ScreenReturn(
  route: '/simulation',
  outcome: ScreenOutcome.completed,
  updatedFields: {'fakeProjection': 42000},
  confidenceDelta: 0.05,
);
''';
      final violations = _violations(
        _returnCalls('lib/screens/fake_simulation.dart', seededViolation),
      );

      expect(violations, hasLength(2));
    });

    test('stepOutputs are explicitly not CoachProfile writes', () {
      const safeReturn = '''
ScreenReturn.completed(
  route: '/simulation',
  stepOutputs: {'projection': 42000},
);
''';

      expect(
        _violations(_returnCalls('lib/screens/simulation.dart', safeReturn)),
        isEmpty,
      );
    });

    test('all production screen returns reserve facts for confirmed paths', () {
      final files = _productionScreenFiles();
      final calls = [
        for (final file in files)
          ..._returnCalls(file.path, file.readAsStringSync()),
      ];

      expect(files.length, greaterThan(50));
      expect(calls.length, greaterThan(10));
      expect(
        _violations(calls),
        isEmpty,
        reason: 'Simulation/cache outputs belong in ScreenReturn.stepOutputs. '
            'Only the explicit confirmed-document route may raise confidence.',
      );
    });
  });
}
