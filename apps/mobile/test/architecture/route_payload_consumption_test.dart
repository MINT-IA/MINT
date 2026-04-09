// GATE-03: Route payload consumption regression test.
//
// Targeted structural test for Bug 2 pattern: a screen that reads
// `state.extra` or `widget.entryPayload` AFTER a short-circuit return
// based on a condition that prevents the payload from being consumed.
//
// The specific pattern:
//   if (!_hasProfile) return const CoachEmptyState();  // line 1317
//   ...
//   // payload is read later in didChangeDependencies  // line 280+
//
// This test scans coach_chat_screen.dart to verify that:
// 1. The `build()` method does NOT short-circuit return before
//    checking for an entry payload
// 2. If there IS a short-circuit, the payload check happens BEFORE it
//
// Additionally tests that screens receiving `state.extra` in app.dart
// handle the null case gracefully (don't crash on missing payload).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GATE-03: Payload consumption', () {
    test(
        'coach_chat_screen.dart does not short-circuit on !_hasProfile '
        'before payload is consumed', () {
      final file = File('lib/screens/coach/coach_chat_screen.dart');
      expect(file.existsSync(), isTrue);
      final source = file.readAsStringSync();

      // Find the build() method
      final buildMethodStart = source.indexOf('@override\n  Widget build(');
      expect(buildMethodStart, isNot(-1),
          reason: 'Should find build() method in coach_chat_screen.dart');

      // Extract the build() method body (find next @override or end of class)
      final afterBuild = source.substring(buildMethodStart);

      // Check for the Bug 2 pattern: short-circuit return of CoachEmptyState
      // BEFORE any payload check
      final emptyStatePattern = RegExp(
        r'if\s*\(\s*!_hasProfile\s*\)\s*\{?\s*\n?\s*return\s+const\s+CoachEmptyState',
      );
      final emptyStateMatch = emptyStatePattern.firstMatch(afterBuild);

      if (emptyStateMatch != null) {
        // If there's a short-circuit on !_hasProfile, verify it also checks
        // for entry payload. The fix for Bug 2 should be:
        //   if (!_hasProfile && widget.entryPayload == null)
        // or the short-circuit should be removed entirely.
        final shortCircuitLine = afterBuild.substring(
          emptyStateMatch.start,
          emptyStateMatch.end + 50,
        );

        // The guard MUST include a payload check
        final hasPayloadGuard = shortCircuitLine.contains('entryPayload') ||
            shortCircuitLine.contains('initialPrompt') ||
            shortCircuitLine.contains('extra');

        // Also check if the condition includes the payload
        final guardCondition = afterBuild.substring(
          emptyStateMatch.start,
          afterBuild.indexOf('return', emptyStateMatch.start),
        );

        expect(
          hasPayloadGuard || !guardCondition.contains('!_hasProfile'),
          isTrue,
          reason:
              'Bug 2 regression: coach_chat_screen.dart short-circuits on '
              '!_hasProfile WITHOUT checking widget.entryPayload. '
              'A user with a valid payload but no profile will be trapped '
              'in the CoachEmptyState -> intent -> CoachEmptyState loop. '
              'Fix: add `&& widget.entryPayload == null` to the guard, '
              'or remove the short-circuit entirely.',
        );
      }
      // If no short-circuit exists, the test passes (the guard was removed
      // or refactored, which is the ideal fix for Bug 2).
    });

    test('screens receiving state.extra in app.dart handle null gracefully',
        () {
      final appFile = File('lib/app.dart');
      expect(appFile.existsSync(), isTrue);
      final source = appFile.readAsStringSync();

      // Find all route builders that read state.extra
      final extraPattern = RegExp(
        r'''builder:\s*\(context,\s*state\)\s*\{[^}]*state\.extra[^}]*\}''',
        dotAll: true,
      );

      final violations = <String>[];

      for (final match in extraPattern.allMatches(source)) {
        final block = match.group(0)!;

        // Check if the block handles null extra
        final hasNullCheck = block.contains('extra == null') ||
            block.contains('extra is ') ||
            block.contains('extra as ') ||
            block.contains('extra != null') ||
            block.contains('extra ?? ') ||
            block.contains('extra?');

        if (!hasNullCheck) {
          // Find which route this belongs to by looking backward
          final beforeBlock = source.substring(0, match.start);
          final pathMatch = RegExp(r'''path:\s*['"]([^'"]+)['"]''')
              .allMatches(beforeBlock)
              .lastOrNull;
          final path = pathMatch?.group(1) ?? 'unknown';
          violations.add(
            'Route $path reads state.extra without null handling',
          );
        }
      }

      if (violations.isNotEmpty) {
        fail('Routes reading state.extra without null guard:\n'
            '${violations.join('\n')}');
      }
    });

    test('didChangeDependencies in coach_chat_screen processes payload '
        'regardless of _hasProfile', () {
      final file = File('lib/screens/coach/coach_chat_screen.dart');
      final source = file.readAsStringSync();

      // Find didChangeDependencies
      final dcdStart = source.indexOf('void didChangeDependencies()');
      expect(dcdStart, isNot(-1),
          reason: 'Should find didChangeDependencies in coach_chat_screen');

      // Extract the method body (approximate: next 100 lines)
      final dcdBlock = source.substring(
        dcdStart,
        (dcdStart + 2000).clamp(0, source.length),
      );

      // Verify entryPayload is handled in didChangeDependencies
      expect(dcdBlock, contains('entryPayload'),
          reason: 'didChangeDependencies should process entryPayload');

      // The payload processing should NOT be gated by _hasProfile
      // Look for pattern: if (_hasProfile) { ... entryPayload ... }
      // which would mean payload is only consumed when profile exists
      final gatedPayloadPattern = RegExp(
        r'if\s*\(\s*_hasProfile\s*\)\s*\{[^}]*entryPayload',
        dotAll: true,
      );
      final gatedMatch = gatedPayloadPattern.firstMatch(dcdBlock);
      if (gatedMatch != null) {
        // Check if it's actually gating payload consumption or just
        // doing something else with _hasProfile nearby
        final context = dcdBlock.substring(
          gatedMatch.start,
          (gatedMatch.start + 200).clamp(0, dcdBlock.length),
        );
        // This is suspicious — payload should be consumed regardless
        // of profile status to prevent Bug 2
        expect(
          context.contains('entryPayload') &&
              !context.contains('widget.entryPayload != null'),
          isFalse,
          reason:
              'entryPayload consumption should not be gated by _hasProfile '
              '(Bug 2 pattern: payload ignored when profile is missing)',
        );
      }
    });
  });
}
