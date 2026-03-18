import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/advisor/advisor_matching_service.dart';

// ═══════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════

CoachProfile _profile({
  String canton = 'VS',
  double salaireBrutMensuel = 10000,
  int birthYear = 1977,
  CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
  int nombreEnfants = 0,
  String? nationality,
  PatrimoineProfile patrimoine = const PatrimoineProfile(),
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaireBrutMensuel,
    nationality: nationality,
    etatCivil: etatCivil,
    nombreEnfants: nombreEnfants,
    patrimoine: patrimoine,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042, 12, 31),
      label: 'Retraite',
    ),
  );
}

/// Banned terms that must NEVER appear in user-facing output.
const _bannedTerms = [
  'garanti',
  'certain',
  'assuré',
  'sans risque',
  'optimal',
  'meilleur',
  'parfait',
  'conseiller',
];

/// PII patterns that must NEVER appear in dossier output.
final _piiPatterns = [
  RegExp(r'CH\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d'), // IBAN
  RegExp(r'\d{3}\.\d{4}\.\d{4}\.\d{2}'), // AVS/SSN number
  RegExp(r'\b756\.\d{4}\.\d{4}\.\d{2}\b'), // Swiss SSN
];

void main() {
  // ═══════════════════════════════════════════════════════════════
  //  ADVISOR MATCHING SERVICE — 12 unit tests
  // ═══════════════════════════════════════════════════════════════

  group('AdvisorMatchingService.findMatches', () {
    test('1. matches by specialization', () {
      final profile = _profile(canton: 'ZZ'); // non-matching canton
      final matches = AdvisorMatchingService.findMatches(
        profile: profile,
        need: AdvisorSpecialization.succession,
      );

      expect(matches, isNotEmpty);
      for (final advisor in matches) {
        expect(
          advisor.specializations,
          contains(AdvisorSpecialization.succession),
        );
      }
    });

    test('2. matches by canton', () {
      final profile = _profile(canton: 'VS');
      final matches = AdvisorMatchingService.findMatches(
        profile: profile,
        need: AdvisorSpecialization.retirement,
      );

      expect(matches, isNotEmpty);
      // When canton match exists, all results should include the canton.
      for (final advisor in matches) {
        expect(advisor.cantons, contains('VS'));
      }
    });

    test('3. matches by language', () {
      final profile = _profile(canton: 'ZZ');
      final matches = AdvisorMatchingService.findMatches(
        profile: profile,
        need: AdvisorSpecialization.tax,
        preferredLanguage: 'it',
      );

      expect(matches, isNotEmpty);
      for (final advisor in matches) {
        expect(advisor.languages, contains('it'));
      }
    });

    test('4. no advisors available returns empty list', () {
      final profile = _profile();
      final matches = AdvisorMatchingService.findMatches(
        profile: profile,
        need: AdvisorSpecialization.succession,
        advisorPool: const [], // empty pool
      );

      expect(matches, isEmpty);
    });

    test('5. results are sorted alphabetically, never ranked', () {
      final profile = _profile(canton: 'ZZ');
      final matches = AdvisorMatchingService.findMatches(
        profile: profile,
        need: AdvisorSpecialization.tax,
      );

      expect(matches.length, greaterThanOrEqualTo(2));
      for (var i = 1; i < matches.length; i++) {
        expect(
          matches[i].displayName.compareTo(matches[i - 1].displayName),
          greaterThanOrEqualTo(0),
          reason: 'Results must be alphabetical, not ranked by rating',
        );
      }
    });
  });

  group('AdvisorMatchingService.prepareDossier', () {
    test('6. dossier contains key metrics in ranges (not exact values)', () async {
      final profile = _profile(salaireBrutMensuel: 10184);
      final dossier = await AdvisorMatchingService.prepareDossier(
        profile: profile,
        topic: AdvisorSpecialization.retirement,
        now: DateTime(2026, 3, 18),
      );

      // Metrics should use range format, not exact values.
      final incomeMetric = dossier.keyMetrics['Revenu brut annuel']!;
      expect(incomeMetric, contains('Tranche'));
      expect(incomeMetric, contains('CHF'));
      // Exact salary (10184 * 12 = 122208) must NOT appear.
      expect(incomeMetric, isNot(contains('122')));
      expect(incomeMetric, isNot(contains('10184')));
    });

    test('7. dossier never contains PII', () async {
      final profile = _profile();
      final dossier = await AdvisorMatchingService.prepareDossier(
        profile: profile,
        topic: AdvisorSpecialization.tax,
        now: DateTime(2026, 3, 18),
      );

      final allText = [
        dossier.summary,
        ...dossier.keyMetrics.values,
        ...dossier.questionsForAdvisor,
        dossier.disclaimer,
      ].join(' ');

      for (final pattern in _piiPatterns) {
        expect(
          pattern.hasMatch(allText),
          isFalse,
          reason: 'Dossier must not contain PII matching: ${pattern.pattern}',
        );
      }
    });

    test('8. dossier summary under 500 chars', () async {
      final profile = _profile();
      final dossier = await AdvisorMatchingService.prepareDossier(
        profile: profile,
        topic: AdvisorSpecialization.succession,
        now: DateTime(2026, 3, 18),
      );

      expect(
        dossier.summary.length,
        lessThanOrEqualTo(500),
        reason: 'Summary must be 500 chars max',
      );
    });

    test('9. questions are relevant to specialization', () async {
      final profile = _profile();

      for (final topic in AdvisorSpecialization.values) {
        final dossier = await AdvisorMatchingService.prepareDossier(
          profile: profile,
          topic: topic,
          now: DateTime(2026, 3, 18),
        );

        expect(
          dossier.questionsForAdvisor,
          isNotEmpty,
          reason: 'Topic $topic must have suggested questions',
        );
        expect(
          dossier.questionsForAdvisor.length,
          greaterThanOrEqualTo(2),
          reason: 'At least 2 questions per topic',
        );
      }
    });

    test('10. disclaimer always present', () async {
      final profile = _profile();
      final dossier = await AdvisorMatchingService.prepareDossier(
        profile: profile,
        topic: AdvisorSpecialization.retirement,
        now: DateTime(2026, 3, 18),
      );

      expect(dossier.disclaimer, isNotEmpty);
      expect(dossier.disclaimer, contains('LSFin'));
      expect(dossier.disclaimer, contains('éducatif'));
    });

    test('11. no banned terms in any output', () async {
      final profile = _profile();

      for (final topic in AdvisorSpecialization.values) {
        final dossier = await AdvisorMatchingService.prepareDossier(
          profile: profile,
          topic: topic,
          now: DateTime(2026, 3, 18),
        );

        final allText = [
          dossier.summary,
          ...dossier.keyMetrics.values,
          ...dossier.questionsForAdvisor,
          dossier.disclaimer,
        ].join(' ').toLowerCase();

        for (final banned in _bannedTerms) {
          expect(
            allText.contains(banned),
            isFalse,
            reason: 'Banned term "$banned" found in $topic dossier',
          );
        }
      }
    });

    test('12. French accents correct and non-breaking spaces present', () async {
      final profile = _profile();
      final dossier = await AdvisorMatchingService.prepareDossier(
        profile: profile,
        topic: AdvisorSpecialization.retirement,
        now: DateTime(2026, 3, 18),
      );

      // Summary should contain proper French accents.
      final allText = [
        dossier.summary,
        ...dossier.questionsForAdvisor,
        dossier.disclaimer,
      ].join(' ');

      // Check for French-specific chars (accents).
      expect(allText, contains('é'), reason: 'French accent é expected');

      // Check non-breaking spaces before colons.
      expect(
        allText,
        contains('\u00a0:'),
        reason: 'Non-breaking space required before colon in French',
      );
    });
  });
}
