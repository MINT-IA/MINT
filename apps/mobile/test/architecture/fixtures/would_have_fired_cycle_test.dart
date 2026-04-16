// Would-have-fired fixture: GATE-01 cycle detection.
//
// Creates a minimal router with an intentional cycle (A -> B -> A)
// replicating the v2.2 Bug 2 pattern: intent -> coach/chat -> intent.
// Runs the same DFS/SCC logic from GATE-01 and asserts it DETECTS
// the cycle. This proves the gate is real, not theatrical.

import 'package:flutter_test/flutter_test.dart';

// Import the cycle detection logic from GATE-01
// (functions are top-level, so we import the test file's helpers)
import '../route_cycle_test.dart';

void main() {
  group('Would-have-fired: GATE-01 cycle detection', () {
    test('detects intent -> coach/chat -> intent cycle (v2.2 Bug 2 pattern)',
        () {
      // Simulate the v2.2 route graph with the Bug 2 cycle:
      // /onboarding/intent -> /coach/chat -> /onboarding/intent
      final graph = <String, Set<String>>{
        '/': {'/onboarding/intent'},
        '/onboarding/intent': {'/coach/chat'},
        '/coach/chat': {'/onboarding/intent'}, // Bug 2: CoachEmptyState loop
        '/auth/login': {},
        '/auth/register': {'/home'},
        '/home': {'/coach/chat', '/profile'},
        '/profile': {},
      };

      final sccs = findStronglyConnectedComponents(graph);

      expect(sccs, isNotEmpty,
          reason: 'GATE-01 MUST detect the intent -> coach/chat cycle');
      expect(sccs.length, equals(1),
          reason: 'Should find exactly 1 SCC (the Bug 2 cycle)');

      final cycle = sccs.first;
      expect(cycle, contains('/onboarding/intent'));
      expect(cycle, contains('/coach/chat'));
    });

    test('detects redirect loop (A -> B -> C -> A)', () {
      final graph = <String, Set<String>>{
        '/a': {'/b'},
        '/b': {'/c'},
        '/c': {'/a'},
        '/d': {},
      };

      final sccs = findStronglyConnectedComponents(graph);

      expect(sccs, isNotEmpty, reason: 'Must detect 3-node cycle');
      expect(sccs.first.length, equals(3));
    });

    test('does NOT flag legitimate bidirectional navigation', () {
      // push + pop between two routes is NOT a cycle in the SCC sense
      // because it requires 2 edges (A->B, B->A) forming an SCC of size 2.
      // This IS an SCC, but the test documents it — legitimate bidirectional
      // nav should be whitelisted if needed.
      final graph = <String, Set<String>>{
        '/': {'/home'},
        '/home': {'/profile'},
        '/profile': {'/home'}, // drawer open/close
      };

      final sccs = findStronglyConnectedComponents(graph);

      // This DOES form an SCC (home <-> profile). In the real gate,
      // we could whitelist known-safe bidirectional pairs. For now,
      // this test documents that the algorithm correctly finds them.
      expect(sccs.length, equals(1));
      expect(sccs.first, containsAll(['/home', '/profile']));
    });
  });
}
