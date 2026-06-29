import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _directNavigatorNavigationPattern = RegExp(
  r'Navigator\s*'
  r'(?:\.\s*of\s*\([^;]*?\))?'
  r'\.\s*'
  r'(?:push|pushNamed|pushReplacement|pushReplacementNamed|'
  r'pushAndRemoveUntil|pushNamedAndRemoveUntil|popAndPushNamed|'
  r'restorablePush|restorablePushNamed|restorablePushReplacement|'
  r'restorablePushReplacementNamed|restorablePushAndRemoveUntil|'
  r'restorablePushNamedAndRemoveUntil|restorablePopAndPushNamed)'
  r'(?:<[^()]*>)?\s*\(',
  multiLine: true,
);

final _commentOrStringPattern = RegExp(
  r'//[^\n]*|/\*[\s\S]*?\*/|"""[\s\S]*?"""|'
  "'''[\\s\\S]*?'''|"
  r'"(?:\\.|[^"\\])*"|'
  r"'(?:\\.|[^'\\])*'",
);

String _blankPreservingLines(String text) {
  return text.split('\n').map((line) => ' ' * line.length).join('\n');
}

String _stripCommentsAndStrings(String source) {
  return source.replaceAllMapped(
    _commentOrStringPattern,
    (match) => _blankPreservingLines(match[0]!),
  );
}

void main() {
  test('doctrine detector catches direct Navigator navigation variants', () {
    const samples = [
      'Navigator.push(context, route);',
      "Navigator.pushNamed(context, '/budget');",
      'Navigator.of(context).push(route);',
      'Navigator.of(context).push<bool>(route);',
      "Navigator.of(context).pushNamed('/budget');",
      "Navigator.of(context).pushNamed<String>('/budget');",
      'Navigator.of(rootContext()).pushReplacement(route);',
      'Navigator.of(context).pushAndRemoveUntil(route, (_) => false);',
      "Navigator.of(context).pushNamedAndRemoveUntil('/x', (_) => false);",
      "Navigator.of(context).popAndPushNamed('/coach/chat');",
      'Navigator.restorablePush(context, routeBuilder);',
      "Navigator.of(context).restorablePushNamed<bool>('/budget');",
    ];

    for (final sample in samples) {
      expect(
        _directNavigatorNavigationPattern.hasMatch(sample),
        isTrue,
        reason: sample,
      );
    }
  });

  test('doctrine detector ignores comments, strings, and non-navigation pop',
      () {
    const sample = """
// Navigator.push(context, route);
/* Navigator.pushNamed(context, '/budget'); */
final text = "Navigator.of(context).push(route)";
final triple = '''Navigator.of(context).pushNamed('/budget')''';
Navigator.of(context).pop();
""";

    expect(
      _directNavigatorNavigationPattern.hasMatch(
        _stripCommentsAndStrings(sample),
      ),
      isFalse,
    );
  });

  test('screen and widget code does not use Navigator navigation directly', () {
    final root = Directory.current;
    final targets = [
      Directory('${root.path}/lib/screens'),
      Directory('${root.path}/lib/widgets'),
    ];
    final violations = <String>[];

    for (final target in targets) {
      if (!target.existsSync()) continue;
      for (final entity in target.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        final searchableSource = _stripCommentsAndStrings(source);
        final lines = source.split('\n');
        for (final match in _directNavigatorNavigationPattern.allMatches(
          searchableSource,
        )) {
          final lineNumber = '\n'
                  .allMatches(searchableSource.substring(0, match.start))
                  .length +
              1;
          violations.add(
            '${entity.path.replaceFirst('${root.path}/', '')}:$lineNumber: '
            '${lines[lineNumber - 1].trim()}',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Use GoRouter for navigation and showDialog/showGeneralDialog '
          'for overlays. Direct Navigator navigation makes route ownership '
          'opaque.\n'
          '${violations.join('\n')}',
    );
  });
}
