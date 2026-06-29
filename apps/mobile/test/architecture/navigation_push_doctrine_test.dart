import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

final _commentPattern = RegExp(
  r'//[^\n]*|/\*[\s\S]*?\*/',
  multiLine: true,
);

final _coachChatPushPattern = RegExp(
  r'''context\s*\.\s*push\s*\(\s*['"]/coach/chat(?:\?[^'"]*)?['"]''',
  multiLine: true,
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

String _stripComments(String source) {
  return source.replaceAllMapped(
    _commentPattern,
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

  test('top-level shell surfaces open Coach with branch switch semantics', () {
    final root = Directory.current;
    final auditedFiles = [
      'lib/screens/aujourdhui/aujourdhui_screen.dart',
      'lib/screens/mon_argent/mon_argent_screen.dart',
      'lib/widgets/aujourdhui/commitments_and_checkins_card.dart',
    ];
    final violations = <String>[];

    for (final relativePath in auditedFiles) {
      final file = File('${root.path}/$relativePath');
      if (!file.existsSync()) {
        violations.add('$relativePath: missing audited file');
        continue;
      }

      final source = file.readAsStringSync();
      final searchableSource = _stripComments(source);
      final lines = source.split('\n');
      for (final match in _coachChatPushPattern.allMatches(searchableSource)) {
        final lineNumber =
            '\n'.allMatches(searchableSource.substring(0, match.start)).length +
                1;
        violations.add(
          '$relativePath:$lineNumber: ${lines[lineNumber - 1].trim()}',
        );
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Coach is a StatefulShellRoute branch. Top-level shell surfaces '
          'use context.go("/coach/chat...") so content and bottom navigation '
          'select the Coach branch together. Leaf/detail and mid-flow screens '
          'need a separate root-owned handoff route before they can preserve '
          'both back-stack and tab selection.\n'
          '${violations.join('\n')}',
    );
  });

  test('production code never pushes the Coach shell branch', () {
    final root = Directory.current;
    final targets = [
      Directory('${root.path}/lib'),
    ];
    final violations = <String>[];

    for (final target in targets) {
      if (!target.existsSync()) continue;
      for (final entity in target.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        final searchableSource = _stripComments(source);
        final lines = source.split('\n');
        for (final match in _coachChatPushPattern.allMatches(searchableSource)) {
          final lineNumber =
              '\n'.allMatches(searchableSource.substring(0, match.start)).length +
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
      reason: '/coach/chat is a StatefulShellRoute branch. Product code must '
          'select it with context.go("/coach/chat...") so the Coach tab, URL, '
          'and visible surface stay coherent. A future leaf-preserving flow '
          'needs a dedicated root-owned handoff route instead of pushing the '
          'shell branch.\n'
          '${violations.join('\n')}',
    );
  });

  test('production router keeps coach chat in its own shell branch', () {
    final source = File('lib/app.dart').readAsStringSync();
    expect(source, contains('StatefulShellRoute.indexedStack'));

    final coachBranchPattern = RegExp(
      r'''StatefulShellBranch\s*\(\s*navigatorKey:\s*_shellNavigatorKeyCoach,[\s\S]*?path:\s*['"]/coach/chat['"]''',
      multiLine: true,
    );
    expect(
      coachBranchPattern.hasMatch(source),
      isTrue,
      reason: '/coach/chat must remain owned by the Coach shell branch. '
          'Top-level shell surfaces use context.go("/coach/chat...") because '
          'it is a tab switch, not a leaf-route push.',
    );
  });

  test('standalone coach back uses lifecycle-aware fallback on empty stack',
      () {
    final source =
        File('lib/screens/coach/coach_chat_screen.dart').readAsStringSync();
    final backPattern = RegExp(
      r'onBack:\s*\(\)\s*=>\s*safePop\(\s*context\s*,\s*'
      r'fallbackRoute:\s*MintNav\.coachFallbackRouteFor\(\s*'
      r'context\.read<AuthProvider>\(\)\.authLifecycle\s*,?\s*\)\s*,?\s*\)',
      multiLine: true,
    );

    expect(
      source,
      contains(
        "import 'package:mint_mobile/services/navigation/mint_nav.dart';",
      ),
    );
    expect(
      backPattern.hasMatch(_stripComments(source)),
      isTrue,
      reason: 'Standalone /coach/chat is shared by guests and accounts. '
          'With an empty stack, back must use allowsMainNavigation: false '
          'lifecycles go to /onb, true lifecycles preserve /home.',
    );
  });

  testWidgets('go to coach branch keeps shell selection coherent and query',
      (tester) async {
    String? capturedTopic;
    final router = GoRouter(
      initialLocation: '/mon-argent',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return Scaffold(
              body: Column(
                children: [
                  Text('branch:${navigationShell.currentIndex}'),
                  Expanded(child: navigationShell),
                ],
              ),
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/mon-argent',
                  builder: (context, state) => Center(
                    child: ElevatedButton(
                      key: const Key('open_coach'),
                      onPressed: () => context.go('/coach/chat?topic=budget'),
                      child: const Text('Open Coach'),
                    ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/coach/chat',
                  builder: (context, state) {
                    capturedTopic = state.uri.queryParameters['topic'];
                    return Center(
                      child: Text('Coach topic:${capturedTopic ?? ''}'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text('branch:0'), findsOneWidget);
    expect(find.text('Open Coach'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open_coach')));
    await tester.pumpAndSettle();

    expect(find.text('branch:1'), findsOneWidget);
    expect(find.text('Coach topic:budget'), findsOneWidget);
    expect(capturedTopic, 'budget');
    expect(router.canPop(), isFalse);

    router.go('/mon-argent');
    await tester.pumpAndSettle();

    expect(find.text('branch:0'), findsOneWidget);
    expect(find.text('Open Coach'), findsOneWidget);
  });
}
