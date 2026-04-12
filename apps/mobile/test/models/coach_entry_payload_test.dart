import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';

void main() {
  group('CoachEntryPayload', () {
    test('creates with all fields', () {
      const payload = CoachEntryPayload(
        source: CoachEntrySource.homeChiffre,
        topic: 'retirementGap',
        data: {'value': 4200.0, 'confidence': 0.62},
        userMessage: null,
      );
      expect(payload.source, CoachEntrySource.homeChiffre);
      expect(payload.topic, 'retirementGap');
      expect(payload.data?['value'], 4200.0);
    });

    test('creates minimal payload for direct entry', () {
      const payload = CoachEntryPayload(source: CoachEntrySource.direct);
      expect(payload.topic, isNull);
      expect(payload.data, isNull);
      expect(payload.userMessage, isNull);
    });

    test('creates payload with user message', () {
      const payload = CoachEntryPayload(
        source: CoachEntrySource.homeInput,
        userMessage: 'combien à la retraite ?',
      );
      expect(payload.userMessage, 'combien à la retraite ?');
      expect(payload.topic, isNull);
    });

    test('toContextInjection includes all fields', () {
      const payload = CoachEntryPayload(
        source: CoachEntrySource.simulator,
        topic: 'pillar3a',
        data: {'annual': 3000, 'maxAnnual': 7258},
        userMessage: null,
      );
      final injection = payload.toContextInjection();
      expect(injection, contains('Source: simulator'));
      expect(injection, contains('Sujet: pillar3a'));
      expect(injection, contains('annual=3000'));
      expect(injection, contains('maxAnnual=7258'));
      expect(injection, contains('INSTRUCTION'));
    });

    test('toContextInjection handles minimal payload', () {
      const payload = CoachEntryPayload(source: CoachEntrySource.direct);
      final injection = payload.toContextInjection();
      expect(injection, contains('Source: direct'));
      expect(injection, isNot(contains('Sujet:')));
      expect(injection, isNot(contains('Données:')));
    });

    test('toString is descriptive', () {
      const payload = CoachEntryPayload(
        source: CoachEntrySource.homeChiffre,
        topic: 'retirementGap',
        data: {'value': 4200.0},
      );
      expect(payload.toString(), contains('homeChiffre'));
      expect(payload.toString(), contains('retirementGap'));
      expect(payload.toString(), contains('1 fields'));
    });
  });
}
