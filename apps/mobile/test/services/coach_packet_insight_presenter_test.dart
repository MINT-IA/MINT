import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/data_spine/coach_packet_insight_presenter.dart';

void main() {
  group('CoachPacketInsightPresenter', () {
    test('builds visible copy from a safe packet fact and next question', () {
      final insight = CoachPacketInsightPresenter.fromSafeMap({
        'facts': [
          {
            'id': 'budget.monthly_capacity',
            'domain': 'budget',
            'field_path': 'trajectory.currentMonthlyCapacity',
            'value': 1200.0,
          },
        ],
        'missing_fields': [
          {
            'field_path': 'trajectory.targetAmount',
            'domain': 'trajectory',
            'reason': 'missing_target_amount',
          },
        ],
        'next_questions': [
          {
            'id': 'define_target_amount',
            'domain': 'trajectory',
            'field_path': 'trajectory.targetAmount',
          },
        ],
      });

      expect(insight, isNotNull);
      expect(insight!.knownText, 'Capacité mensuelle: CHF 1\'200');
      expect(insight.nextText, 'Objectif à atteindre');
    });

    test(
        'SALVAGE-00 SC-4: leads with monthly_free (Disponible) over '
        'monthly_capacity when both are present', () {
      final insight = CoachPacketInsightPresenter.fromSafeMap({
        'facts': [
          {
            'id': 'budget.monthly_capacity',
            'domain': 'budget',
            'field_path': 'trajectory.currentMonthlyCapacity',
            'value': 3740.0,
          },
          {
            'id': 'budget.monthly_free',
            'domain': 'budget',
            'field_path': 'budget.present.monthlyFree',
            'value': 3152.0,
          },
        ],
        'missing_fields': [
          {
            'field_path': 'trajectory.targetAmount',
            'domain': 'trajectory',
            'reason': 'missing_target_amount',
          },
        ],
        'next_questions': [
          {
            'id': 'define_target_amount',
            'domain': 'trajectory',
            'field_path': 'trajectory.targetAmount',
          },
        ],
      });

      expect(insight, isNotNull);
      // Must show the SAME Disponible/mois the user sees on Budget + Mon Argent
      // (monthlyFree 3'152), NOT monthly_capacity (3'740) — money-trust-chain.
      expect(insight!.knownText, 'Marge libre: CHF 3\'152');
    });

    test('falls back to the first missing field when no next question exists',
        () {
      final insight = CoachPacketInsightPresenter.fromSafeMap({
        'facts': [
          {
            'id': 'profile.canton',
            'domain': 'profile',
            'field_path': 'situation.canton',
            'value': 'VD',
          },
        ],
        'missing_fields': [
          {
            'field_path': 'pillars.lpp.totalBalance',
            'domain': 'pillar_lpp',
            'reason': 'missing_value',
          },
        ],
        'next_questions': [],
      });

      expect(insight, isNotNull);
      expect(insight!.knownText, 'Canton: VD');
      expect(insight.nextText, 'Avoir LPP');
    });

    test('does not present estimated LPP as already clear', () {
      final insight = CoachPacketInsightPresenter.fromSafeMap({
        'facts': [
          {
            'id': 'pillar.lpp.total_balance',
            'value': 37600.0,
            'source': 'estimated',
          },
          {'id': 'profile.canton', 'value': 'VS'},
        ],
        'missing_fields': [
          {'field_path': 'pillars.lpp.totalBalance'},
        ],
      });

      expect(insight, isNotNull);
      expect(insight!.knownText, 'Canton: VS');
      expect(insight.knownText, isNot(contains('37')));
      expect(insight.nextText, 'Avoir LPP');
    });

    test('returns null without a visible fact and follow-up', () {
      expect(
        CoachPacketInsightPresenter.fromSafeMap({
          'facts': [],
          'missing_fields': [],
          'next_questions': [],
        }),
        isNull,
      );
    });

    test('ignores raw profile keys outside the safe packet allowlist', () {
      final insight = CoachPacketInsightPresenter.fromSafeMap({
        'first_name': 'Julien',
        'q_net_income_period_chf': 9500,
        'facts': [
          {
            'id': 'profile.canton',
            'domain': 'profile',
            'field_path': 'situation.canton',
            'value': 'VD',
          },
        ],
        'missing_fields': [
          {
            'field_path': 'trajectory.targetAmount',
            'domain': 'trajectory',
            'reason': 'missing_target_amount',
          },
        ],
        'next_questions': [],
      });

      expect(insight, isNotNull);
      expect(insight!.knownText, isNot(contains('Julien')));
      expect(insight.knownText, isNot(contains('9500')));
      expect(insight.nextText, isNot(contains('Julien')));
    });
  });
}
