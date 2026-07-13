import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _allowedEnumPayloadsByFile = <String, Set<String>>{
  'lib/screens/document_scan/avs_guide_screen.dart': {
    'DocumentType.avsExtract',
  },
  'lib/widgets/report/retirement_projection_card.dart': {
    'DocumentType.lppCertificate',
  },
};

const _allowedOpaqueIdPayloads = <String>{
  'scanSessionId',
  'runId',
  'stepId',
};

const _allowedSequenceKeys = <String>{'runId', 'stepId'};

class _ExtraOccurrence {
  final String file;
  final String expression;

  const _ExtraOccurrence(this.file, this.expression);

  @override
  String toString() => '$file: extra: $expression';
}

List<File> _productionDartFiles() => Directory('lib')
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

String _stripComments(String source) {
  final out = StringBuffer();
  String? quote;
  var escaped = false;
  var lineComment = false;
  var blockComment = false;

  for (var i = 0; i < source.length; i += 1) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';

    if (lineComment) {
      if (char == '\n') {
        lineComment = false;
        out.write(char);
      } else {
        out.write(' ');
      }
      continue;
    }
    if (blockComment) {
      if (char == '*' && next == '/') {
        blockComment = false;
        out.write('  ');
        i += 1;
      } else {
        out.write(char == '\n' ? '\n' : ' ');
      }
      continue;
    }
    if (quote != null) {
      out.write(char);
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == '/' && next == '/') {
      lineComment = true;
      out.write('  ');
      i += 1;
      continue;
    }
    if (char == '/' && next == '*') {
      blockComment = true;
      out.write('  ');
      i += 1;
      continue;
    }
    if (char == "'" || char == '"') quote = char;
    out.write(char);
  }
  return out.toString();
}

String _readExpression(String source, int start) {
  var parens = 0;
  var braces = 0;
  var brackets = 0;
  var angles = 0;
  String? quote;
  var escaped = false;
  var end = start;

  for (; end < source.length; end += 1) {
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
      continue;
    }
    if (char == '(') parens += 1;
    if (char == '{') braces += 1;
    if (char == '[') brackets += 1;
    if (char == '<') angles += 1;
    if (char == '>') angles -= 1;
    if (char == ')' && parens == 0 && braces == 0 && brackets == 0) break;
    if (char == ')') parens -= 1;
    if (char == '}') braces -= 1;
    if (char == ']') brackets -= 1;
    if (char == ',' &&
        parens == 0 &&
        braces == 0 &&
        brackets == 0 &&
        angles == 0) {
      break;
    }
  }
  return source.substring(start, end).trim();
}

List<_ExtraOccurrence> _extraOccurrences(String file, String source) {
  final stripped = _stripComments(source);
  return [
    for (final match in RegExp(r'\bextra\s*:').allMatches(stripped))
      if (!RegExp(r'\?\s*$').hasMatch(stripped.substring(0, match.start)))
        _ExtraOccurrence(file, _readExpression(stripped, match.end)),
  ];
}

List<String> _splitTopLevel(String source) {
  final parts = <String>[];
  var start = 0;
  var depth = 0;
  String? quote;
  var escaped = false;
  for (var i = 0; i < source.length; i += 1) {
    final char = source[i];
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
    } else if ('({['.contains(char)) {
      depth += 1;
    } else if (')}]'.contains(char)) {
      depth -= 1;
    } else if (char == ',' && depth == 0) {
      parts.add(source.substring(start, i).trim());
      start = i + 1;
    }
  }
  final tail = source.substring(start).trim();
  if (tail.isNotEmpty) parts.add(tail);
  return parts;
}

bool _isAllowedSequenceMap(String expression) {
  var source = expression.trim();
  source = source.replaceFirst(
    RegExp(r'^<String,\s*dynamic>\s*'),
    '',
  );
  if (!source.startsWith('{') || !source.endsWith('}')) return false;
  final entries = _splitTopLevel(source.substring(1, source.length - 1));
  if (entries.length != 2) return false;

  final seenKeys = <String>{};
  for (final entry in entries) {
    final match = RegExp(
      r'''^['"](runId|stepId)['"]\s*:\s*([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)$''',
    ).firstMatch(entry);
    if (match == null) return false;
    final key = match.group(1)!;
    final value = match.group(2)!;
    final expectedValue = key == 'runId'
        ? RegExp(r'^(?:runId|_seqRunId|[A-Za-z_]\w*\.runId)$')
        : RegExp(r'^(?:stepId|_seqStepId|[A-Za-z_]\w*\.stepId)$');
    if (!expectedValue.hasMatch(value)) return false;
    seenKeys.add(key);
  }
  return seenKeys.containsAll(_allowedSequenceKeys);
}

bool _isAllowedExtra(_ExtraOccurrence occurrence) {
  if (_allowedEnumPayloadsByFile[occurrence.file]
          ?.contains(occurrence.expression) ??
      false) {
    return true;
  }
  if (_allowedOpaqueIdPayloads.contains(occurrence.expression)) return true;
  return _isAllowedSequenceMap(occurrence.expression);
}

List<String> _findWriterViolations(String file, String source) => [
      for (final occurrence in _extraOccurrences(file, source))
        if (!_isAllowedExtra(occurrence)) occurrence.toString(),
    ];

String? _enclosingBlock(String source, int index) {
  var depth = 0;
  int? start;
  for (var i = index - 1; i >= 0; i -= 1) {
    if (source[i] == '}') {
      depth += 1;
    } else if (source[i] == '{') {
      if (depth == 0) {
        start = i;
        break;
      }
      depth -= 1;
    }
  }
  if (start == null) return null;

  depth = 0;
  for (var i = start; i < source.length; i += 1) {
    if (source[i] == '{') {
      depth += 1;
    } else if (source[i] == '}') {
      depth -= 1;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  return null;
}

List<String> _findRawReaderViolations(String file, String source) {
  final rawExtra = RegExp(
    r'(?:state|GoRouterState\.of\([^)]*\))\.extra',
  );
  final assignment = RegExp(
    r'final\s+([A-Za-z_]\w*)\s*=\s*'
    r'(?:state|GoRouterState\.of\([^)]*\))\.extra\s*;',
  );
  final assignments = assignment.allMatches(source).toList();
  final violations = <String>[];

  for (final raw in rawExtra.allMatches(source)) {
    RegExpMatch? owner;
    for (final candidate in assignments) {
      if (candidate.start <= raw.start && candidate.end >= raw.end) {
        owner = candidate;
        break;
      }
    }
    if (owner == null) {
      violations.add('$file: raw extra read is not assigned for validation');
      continue;
    }

    final name = owner.group(1)!;
    final escaped = RegExp.escape(name);
    final block = _enclosingBlock(source, owner.start);
    if (block == null) {
      violations.add('$file: cannot resolve extra reader scope for "$name"');
      continue;
    }
    final useCount = RegExp('\\b$escaped\\b').allMatches(block).length;
    final exactDocumentType = RegExp(
      '\\b$escaped\\s+is\\s+DocumentType\\s*\\?\\s*'
      '$escaped\\s*:\\s*null',
    ).hasMatch(block);
    if (exactDocumentType && useCount == 4) continue;

    final exactMapGuard = RegExp(
      '\\b$escaped\\s+is\\s+Map<String,\\s*dynamic>',
    ).hasMatch(block);
    final keyMatches = RegExp(
      '''\\b$escaped\\s*\\[\\s*['"]([^'"]+)['"]\\s*\\]''',
    ).allMatches(block).toList();
    final keys = keyMatches.map((match) => match.group(1)!).toSet();
    final typedStringReads = RegExp(
      '''\\b$escaped\\s*\\[\\s*['"](?:runId|stepId)['"]\\s*\\]\\s+as\\s+String\\?''',
    ).allMatches(block).length;
    final exactSequenceMap = exactMapGuard &&
        keyMatches.length == 2 &&
        keys.length == 2 &&
        keys.containsAll(_allowedSequenceKeys) &&
        typedStringReads == 2 &&
        useCount == 5;
    if (!exactSequenceMap) {
      violations.add(
        '$file: extra reader "$name" is not an exact DocumentType or '
        'runId/stepId consumer '
        '(document=$exactDocumentType, map=$exactMapGuard, keys=$keys, '
        'typed=$typedStringReads, uses=$useCount)',
      );
    }
  }
  return violations;
}

List<String> _findReaderViolations(String file, String source) {
  final stripped = _stripComments(source);
  final violations = _findRawReaderViolations(file, stripped);

  for (final match in RegExp(
    r'''\bextra\s*\[\s*['"]([^'"]+)['"]\s*\]''',
  ).allMatches(stripped)) {
    final key = match.group(1)!;
    if (!_allowedSequenceKeys.contains(key)) {
      violations.add('$file: forbidden extra key "$key"');
    }
  }
  for (final match in RegExp(
    r'\bextra\s+is\s+([A-Za-z_]\w*(?:<[^>]+>)?)',
  ).allMatches(stripped)) {
    final type = match.group(1)!.replaceAll(RegExp(r'\s+'), '');
    if (type != 'DocumentType' && type != 'Map<String,dynamic>') {
      violations.add('$file: forbidden extra type "$type"');
    }
  }
  for (final match in RegExp(
    r'(?:state|GoRouterState\.of\([^)]*\))\.extra\s+as\s+[^;,)]+',
  ).allMatches(stripped)) {
    violations.add('$file: forbidden cast "${match.group(0)}"');
  }
  return violations;
}

List<String> _findProductionViolations(Iterable<File> files) => [
      for (final file in files)
        ..._findWriterViolations(file.path, file.readAsStringSync()),
      for (final file in files)
        ..._findReaderViolations(file.path, file.readAsStringSync()),
    ];

void main() {
  group('GoRouter.extra explicit allowlist hard floor', () {
    test('rejects Stream, callback, and arbitrary Map fixtures', () {
      const seededViolations = '''
context.push('/stream', extra: stream);
context.push('/callback', extra: labelFor);
context.push('/profile', extra: {'salary': 120000});
''';

      expect(
        _findWriterViolations('lib/fixture.dart', seededViolations),
        hasLength(3),
      );
    });

    test('rejects an aliased arbitrary extra reader', () {
      const seededReader = '''
void read(BuildContext context) {
  final payload = GoRouterState.of(context).extra;
  use(payload as FinancialProjection);
}
''';

      expect(
        _findReaderViolations('lib/fixture.dart', seededReader),
        isNotEmpty,
      );
    });

    test('allows only exact enums, opaque IDs, and runId/stepId ephemera', () {
      const scan = "context.push('/scan', extra: DocumentType.avsExtract);";
      const sequence = '''
context.push('/step', extra: {'runId': runId, 'stepId': stepId});
''';

      expect(
        _findWriterViolations(
          'lib/screens/document_scan/avs_guide_screen.dart',
          scan,
        ),
        isEmpty,
      );
      expect(_findWriterViolations('lib/sequence.dart', sequence), isEmpty);
    });

    test('all production Dart uses the explicit extra allowlist', () {
      final files = _productionDartFiles();

      expect(
        files.length,
        greaterThan(100),
        reason: 'The gate must scan lib/**/*.dart, not a hand-picked list.',
      );
      expect(
        _findProductionViolations(files),
        isEmpty,
        reason: 'Any new GoRouter.extra reader or writer must fit the exact '
            'enum/opaque-ID/sequence-ephemera contract.',
      );
    });

    test('the orphan stream-result transport is not reintroduced', () {
      expect(
        File('lib/screens/document_scan/document_stream_result_screen.dart')
            .existsSync(),
        isFalse,
      );
      final production = _productionDartFiles()
          .map((file) => file.readAsStringSync())
          .join('\n');
      expect(production, isNot(contains('/scan/stream-result')));
      expect(production, isNot(contains('pushDocumentStreamResult')));
    });

    test('scan navigation carries scanSessionId, never extraction payloads',
        () {
      final sources = [
        'lib/screens/document_scan/document_scan_screen.dart',
        'lib/screens/document_scan/avs_guide_screen.dart',
        'lib/screens/document_scan/extraction_review_screen.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');

      expect(
        sources,
        isNot(matches(RegExp(
          r"context\.push\('/scan/(?:review|impact)'\s*,\s*extra\s*:",
        ))),
      );
      expect(sources, contains('scanSessionId'));
    });

    test('coach suggestion navigation never transports its readiness map', () {
      final suggestionCard = File(
        'lib/widgets/coach/route_suggestion_card.dart',
      ).readAsStringSync();
      expect(suggestionCard, isNot(contains('context.push(route, extra:')));
    });

    test('coach routing exposes no financial prefill facade', () {
      final sources = [
        'lib/widgets/coach/route_suggestion_card.dart',
        'lib/widgets/coach/widget_renderer.dart',
        'lib/services/navigation/route_planner.dart',
        'lib/services/navigation/screen_registry.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');

      expect(sources, isNot(matches(RegExp(r'\bprefill\b'))));
      expect(sources, isNot(contains('prefillFromProfile')));
      expect(sources, isNot(contains('_buildPrefill')));
      expect(sources, isNot(contains('_resolveProfileValue')));
    });
  });
}
