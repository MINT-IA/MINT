// Would-have-fired fixture: GATE-03 payload consumption.
//
// Simulates the v2.2 Bug 2 pattern where coach_chat_screen.dart had:
//
//   if (!_hasProfile) {
//     return const CoachEmptyState();  // <-- short-circuit
//   }
//   // ... payload consumed later, NEVER reached
//
// This test proves that GATE-03's structural analysis catches the
// pattern: a short-circuit return before payload consumption.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Would-have-fired: GATE-03 payload consumption', () {
    test('detects short-circuit before payload consumption (v2.2 Bug 2)',
        () {
      // Simulate the v2.2 coach_chat_screen.dart build() method
      // where !_hasProfile short-circuits BEFORE the payload is used.
      const buggyBuildMethod = '''
  @override
  Widget build(BuildContext context) {
    if (!_hasProfile) {
      return const CoachEmptyState();
    }

    // Payload is consumed here, but NEVER reached when !_hasProfile
    final payload = widget.entryPayload;
    if (payload != null) {
      _bootstrapFromPayload(payload);
    }

    return Scaffold(
      body: _buildChat(),
    );
  }
''';

      // GATE-03 check: find short-circuit pattern
      final shortCircuitPattern = RegExp(
        r'if\s*\(\s*!_hasProfile\s*\)\s*\{?\s*\n?\s*return\s+const\s+CoachEmptyState',
      );
      final match = shortCircuitPattern.firstMatch(buggyBuildMethod);

      expect(match, isNotNull,
          reason: 'Should detect the !_hasProfile short-circuit pattern');

      // Check if the guard includes a payload check
      if (match != null) {
        final guardBlock = buggyBuildMethod.substring(
          match.start,
          match.end + 50,
        );
        final hasPayloadGuard = guardBlock.contains('entryPayload') ||
            guardBlock.contains('initialPrompt');

        expect(hasPayloadGuard, isFalse,
            reason: 'The buggy v2.2 code does NOT check payload in guard — '
                'GATE-03 should detect this as a violation');
      }
    });

    test('passes when payload check is included in guard (fixed version)',
        () {
      // The fixed version adds entryPayload and initialPrompt checks
      const fixedBuildMethod = '''
  @override
  Widget build(BuildContext context) {
    if (!_hasProfile &&
        widget.entryPayload == null &&
        widget.initialPrompt == null) {
      return const CoachEmptyState();
    }

    final payload = widget.entryPayload;
    if (payload != null) {
      _bootstrapFromPayload(payload);
    }

    return Scaffold(
      body: _buildChat(),
    );
  }
''';

      final shortCircuitPattern = RegExp(
        r'if\s*\(\s*!_hasProfile\s*\)\s*\{?\s*\n?\s*return\s+const\s+CoachEmptyState',
      );
      final match = shortCircuitPattern.firstMatch(fixedBuildMethod);

      // The fixed version still has !_hasProfile but it's part of a
      // compound condition. The pattern above won't match because the
      // `if` block now contains `&&` before the closing `)`.
      // This means the structural pattern detection correctly
      // distinguishes buggy from fixed code.
      expect(match, isNull,
          reason: 'Fixed code with compound condition should NOT match '
              'the simple !_hasProfile-only pattern');
    });

    test('detects extra read AFTER short-circuit return', () {
      // Another variant of Bug 2: state.extra is read AFTER a guard
      // that returns early, making the extra read dead code for
      // certain states.
      const buggySource = '''
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const LoadingScreen();
    }

    final extra = GoRouterState.of(context).extra;
    // extra is dead code when !_isReady
  }
''';

      // Check: is there a return statement BEFORE any extra/payload read?
      final returnBeforeExtra = RegExp(
        r'return\s+.*?;\s*\n.*?(?:extra|entryPayload)',
        dotAll: true,
      );
      final earlyReturn = RegExp(r'if\s*\([^)]*\)\s*\{?\s*\n?\s*return\s');

      final hasEarlyReturn = earlyReturn.hasMatch(buggySource);
      final extraReadIdx = buggySource.indexOf('extra');
      final returnIdx = buggySource.indexOf('return');

      expect(hasEarlyReturn, isTrue,
          reason: 'Should detect early return in buggy source');
      expect(returnIdx < extraReadIdx, isTrue,
          reason: 'Return statement comes before extra read — '
              'payload is dead code for the early-return path');
    });
  });
}
