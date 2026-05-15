// Wave 1b Plan 05 — golden snapshot stubs (6 tools × default state).
// NOTE: testWidgets only accepts bool for skip; skip reasons live in comments
// (Plan 01 deviation Rule 1 — auto-fix from plan-prescribed String skip).
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoachCitationChipsSection golden (Wave 1b stubs)', () {
    for (final tool in const [
      'budget_snapshot',
      'retirement_projection',
      'cross_pillar_analysis',
      'couple_optimization',
      'cap_status',
      'retrieve_memories',
    ]) {
      // skip reason: Wave 1b — golden snapshot lands in Plan 05
      testWidgets('renders golden for $tool',
          (tester) async {},
          skip: true);
    }
  });
}
