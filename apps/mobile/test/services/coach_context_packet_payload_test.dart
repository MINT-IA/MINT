import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/data_spine/coach_context_packet_adapter.dart';

void main() {
  group('CoachContextPacket payload wiring', () {
    test('orchestrator profile context carries the safe packet', () {
      final packet = <String, dynamic>{
        'computed_at': '2026-05-23T12:00:00.000Z',
        'facts': [
          {
            'id': 'budget.monthly_free',
            'domain': 'budget',
            'field_path': 'budget.present.monthlyFree',
            'value': 1800.0,
            'source': 'calculated',
            'confidence': 0.91,
          },
        ],
        'missing_fields': [
          {
            'field_path': 'pillars.lpp.totalBalance',
            'domain': 'pillar_lpp',
            'reason': 'missing',
          },
        ],
        'trajectory': {
          'status': 'drifting',
          'current_monthly_capacity': 1200.0,
          'monthly_required': 1800.0,
          'monthly_gap': 600.0,
          'next_lever_id': 'increase_monthly_capacity',
        },
        'next_questions': [
          {
            'id': 'increase_monthly_capacity',
            'domain': 'budget',
            'field_path': 'budget.present.monthlyCapacity',
          },
        ],
        'readiness': {
          'overall_status': 'partial',
          'sections': [
            {
              'id': 'budget',
              'status': 'ready',
              'known_count': 4,
              'missing_count': 0,
            },
          ],
          'missing_domains': ['pillar_lpp'],
          'next_action_id': 'complete_pillar_lpp',
        },
      };

      final ctx = CoachContext(
        firstName: 'Julien',
        age: 36,
        canton: 'VD',
        archetype: 'swiss_native',
        knownValues: const {'fri_total': 62},
        coachContextPacket: packet,
      );

      final profileContext = CoachOrchestrator.buildProfileContextForTest(ctx);

      expect(profileContext['coach_context_packet'], packet);
      final emittedPacket =
          profileContext['coach_context_packet'] as Map<String, dynamic>;
      expect(emittedPacket['facts'], isA<List<dynamic>>());
      expect(emittedPacket['missing_fields'], isA<List<dynamic>>());
      expect(emittedPacket['trajectory'], isA<Map<String, dynamic>>());
      expect(emittedPacket['next_questions'], isA<List<dynamic>>());
      expect(emittedPacket['readiness'], isA<Map<String, dynamic>>());

      expect(emittedPacket.containsKey('first_name'), isFalse);
      expect(emittedPacket.containsKey('commune'), isFalse);
      expect(emittedPacket.containsKey('wizard_answers'), isFalse);

      // Legacy scalar fields remain for backward compatibility; the packet
      // is the new structured spine, not a replacement for auth/gate fields.
      expect(profileContext['first_name'], 'Julien');
      expect(profileContext['canton'], 'VD');
      expect(profileContext['fri_total'], 62);
    });

    test('orchestrator omits empty packet to avoid hollow facade payloads', () {
      const ctx = CoachContext(
        firstName: 'Julien',
        age: 36,
        canton: 'VD',
        archetype: 'swiss_native',
      );

      final profileContext = CoachOrchestrator.buildProfileContextForTest(ctx);

      expect(profileContext.containsKey('coach_context_packet'), isFalse);
    });

    test('CoachLlmService.chat passes packet into the real orchestrator seam',
        () async {
      CoachContext? capturedCtx;
      CoachLlmService.registerOrchestrator(({
        required userMessage,
        required history,
        required ctx,
        byokConfig,
        memoryBlock,
        language = 'fr',
        cashLevel = 3,
        isLoggedIn = false,
      }) async {
        capturedCtx = ctx;
        return const CoachResponse(
          message: 'ok',
          disclaimer: 'Outil educatif.',
          wasFiltered: false,
        );
      });

      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 8000,
        prevoyance: const PrevoyanceProfile(
          totalEpargne3a: 12000,
          nombre3a: 2,
          avoirLppTotal: 80000,
          renteAVSEstimeeMensuelle: 2450,
          anneesContribuees: 18,
        ),
        depenses: const DepensesProfile(loyer: 2200, assuranceMaladie: 450),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
          targetAmount: 250000,
        ),
      );

      await CoachLlmService.chat(
        userMessage: 'Ou en est mon plan?',
        profile: profile,
        history: const [],
        config: LlmConfig.defaultOpenAI,
      );

      final packet = capturedCtx?.coachContextPacket;
      expect(packet, isNotNull);
      expect(packet, isNotEmpty);
      expect(packet!['facts'], isA<List<dynamic>>());
      expect(packet['trajectory'], isA<Map<String, dynamic>>());
      expect(packet['readiness'], isA<Map<String, dynamic>>());
      expect(
        (packet['readiness'] as Map<String, dynamic>)['next_action_id'],
        isA<String>(),
      );
      expect(packet.containsKey('wizard_answers'), isFalse);
      expect(packet.containsKey('first_name'), isFalse);
    });

    test('shared adapter builds the packet used by screen and service paths',
        () {
      final profile = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 8000,
        prevoyance: const PrevoyanceProfile(
          totalEpargne3a: 12000,
          nombre3a: 2,
          avoirLppTotal: 80000,
          renteAVSEstimeeMensuelle: 2450,
          anneesContribuees: 18,
        ),
        depenses: const DepensesProfile(loyer: 2200, assuranceMaladie: 450),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: 'Retraite',
          targetAmount: 250000,
        ),
      );

      final packet = CoachContextPacketAdapter.fromProfile(profile);

      expect(packet, isNotEmpty);
      expect(packet['facts'], isA<List<dynamic>>());
      expect(packet['missing_fields'], isA<List<dynamic>>());
      expect(packet['trajectory'], isA<Map<String, dynamic>>());
      expect(packet['next_questions'], isA<List<dynamic>>());
      expect(packet['readiness'], isA<Map<String, dynamic>>());
      expect(packet.containsKey('wizard_answers'), isFalse);
      expect(packet.containsKey('first_name'), isFalse);
    });
  });
}
