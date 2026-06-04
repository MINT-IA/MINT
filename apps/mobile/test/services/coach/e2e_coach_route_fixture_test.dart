import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/e2e_coach_route_fixture.dart';

void main() {
  group('E2eCoachRouteFixture', () {
    test('is inactive for unknown fixture names', () {
      final fixture = E2eCoachRouteFixture.orchestratorFor(
        '',
        debugMode: true,
      );

      expect(fixture, isNull);
    });

    test('is inactive outside debug mode', () {
      final fixture = E2eCoachRouteFixture.orchestratorFor(
        'retirement_choice',
        debugMode: false,
      );

      expect(fixture, isNull);
    });

    test('retirement_choice emits deterministic route_to_screen tool call',
        () async {
      final fixture = E2eCoachRouteFixture.orchestratorFor(
        'retirement_choice',
        debugMode: true,
      );

      expect(fixture, isNotNull);

      final response = await fixture!(
        userMessage: 'Rente ou capital ?',
        history: const [],
        ctx: const CoachContext(),
        language: 'fr',
        cashLevel: 3,
        isLoggedIn: false,
      );

      expect(response.message, contains('outil'));
      expect(response.toolCalls, hasLength(1));
      final call = response.toolCalls.single;
      expect(call.name, 'route_to_screen');
      expect(call.input['intent'], 'retirement_choice');
      expect(call.input['confidence'], 0.9);
      expect(
        call.input['context_message'],
        contains('rente et le capital'),
      );
    });
  });
}
