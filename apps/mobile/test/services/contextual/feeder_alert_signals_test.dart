import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/anticipation_provider.dart';
import 'package:mint_mobile/services/coach/proactive_trigger_service.dart';
import 'package:mint_mobile/services/nudge/nudge_engine.dart';
import 'package:mint_mobile/services/nudge/nudge_trigger.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart';
import 'package:mint_mobile/widgets/alert/mint_alert_signal.dart';

void main() {
  group('Phase 9 D-09 — feeders emit MintAlertSignal', () {
    test('AnticipationProvider exposes broadcast alertSignals stream', () {
      final provider = AnticipationProvider();
      expect(provider.alertSignals, isA<Stream<MintAlertSignal>>());
      expect(provider.currentDebtCrisisSignal, isNull);
      provider.dispose();
    });

    test(
        'AnticipationProvider.markDebtCrisis emits a G3 signal '
        'and exposes currentDebtCrisisSignal', () async {
      final provider = AnticipationProvider();
      final emissions = <MintAlertSignal>[];
      final sub = provider.alertSignals.listen(emissions.add);

      provider.markDebtCrisis(now: DateTime(2026, 4, 7));

      // Allow microtask to flush.
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentDebtCrisisSignal, isNotNull);
      expect(provider.currentDebtCrisisSignal!.gravity, Gravity.g3);
      expect(provider.currentDebtCrisisSignal!.factKey, 'mintAlertDebtFact');
      expect(provider.currentDebtCrisisSignal!.topicTag, 'debt');
      expect(emissions, hasLength(1));
      expect(emissions.first.alertId, contains('20260407'));

      // Idempotent: same day → no re-emit.
      provider.markDebtCrisis(now: DateTime(2026, 4, 7));
      await Future<void>.delayed(Duration.zero);
      expect(emissions, hasLength(1));

      provider.clearDebtCrisis();
      expect(provider.currentDebtCrisisSignal, isNull);

      await sub.cancel();
      provider.dispose();
    });

    test(
        'NudgeEngine.alertSignalsFrom maps NudgePriority → Gravity '
        'and yields ARB-key signals', () async {
      final nudges = [
        Nudge(
          id: 'nudgeSalaryReceived_20260407',
          trigger: NudgeTrigger.salaryReceived,
          priority: NudgePriority.high,
          intentTag: '/pilier-3a',
          titleKey: 'nudgeSalaryTitle',
          bodyKey: 'nudgeSalaryBody',
          expiresAt: DateTime(2026, 4, 8),
        ),
        Nudge(
          id: 'nudgeProfileIncomplete_20260407',
          trigger: NudgeTrigger.profileIncomplete,
          priority: NudgePriority.medium,
          intentTag: '/onboarding/intent',
          titleKey: 'nudgeProfileTitle',
          bodyKey: 'nudgeProfileBody',
          expiresAt: DateTime(2026, 4, 14),
        ),
      ];

      final emitted =
          await NudgeEngine.alertSignalsFrom(nudges).toList();

      expect(emitted, hasLength(2));
      expect(emitted[0].gravity, Gravity.g3);
      expect(emitted[0].factKey, 'nudgeSalaryTitle');
      expect(emitted[0].causeKey, 'nudgeSalaryBody');
      expect(emitted[0].alertId, startsWith('nudge:'));
      expect(emitted[1].gravity, Gravity.g2);
    });

    test(
        'ProactiveTriggerService.alertSignalsFrom yields nothing for null '
        'and a typed signal otherwise', () async {
      final none =
          await ProactiveTriggerService.alertSignalsFrom(null).toList();
      expect(none, isEmpty);

      final trigger = ProactiveTrigger(
        type: ProactiveTriggerType.contractDeadlineApproaching,
        messageKey: 'proactiveContractDeadlineMessage',
        triggeredAt: DateTime(2026, 4, 7),
      );

      final emitted = await ProactiveTriggerService.alertSignalsFrom(trigger)
          .toList();

      expect(emitted, hasLength(1));
      expect(emitted.first.gravity, Gravity.g3);
      expect(emitted.first.topicTag, 'contractDeadlineApproaching');
      expect(emitted.first.alertId,
          'proactive:contractDeadlineApproaching:2026-04-07');
    });
  });
}
