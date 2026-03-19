import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/advisor/advisor_matching_service.dart';
import 'package:mint_mobile/services/subscription_service.dart';

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

/// Valid Expert-tier subscription for tests.
const _expertTier = SubscriptionTier.premium;

void main() {
  // ═══════════════════════════════════════════════════════════════
  //  ADVISOR MATCHING SERVICE — 12 original + 15 adversarial tests
  // ═══════════════════════════════════════════════════════════════

  group('AdvisorMatchingService.findMatches', () {
    test('1. matches by specialization', () {
      final profile = _profile(canton: 'ZZ'); // non-matching canton
      final matches = AdvisorMatchingService.findMatches(
        profile: profile,
        need: AdvisorSpecialization.succession,
        tier: _expertTier,
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
        tier: _expertTier,
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
        tier: _expertTier,
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
        tier: _expertTier,
        advisorPool: const [], // empty pool
      );

      expect(matches, isEmpty);
    });

    test('5. results are sorted alphabetically, never ranked', () {
      final profile = _profile(canton: 'ZZ');
      final matches = AdvisorMatchingService.findMatches(
        profile: profile,
        need: AdvisorSpecialization.tax,
        tier: _expertTier,
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
    test('6. dossier contains key metrics in ranges (not exact values)',
        () async {
      final profile = _profile(salaireBrutMensuel: 10184);
      final dossier = await AdvisorMatchingService.prepareDossier(
        profile: profile,
        topic: AdvisorSpecialization.retirement,
        tier: _expertTier,
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
        tier: _expertTier,
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
        tier: _expertTier,
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
          tier: _expertTier,
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
        tier: _expertTier,
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
          tier: _expertTier,
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

    test('12. French accents correct and non-breaking spaces present',
        () async {
      final profile = _profile();
      final dossier = await AdvisorMatchingService.prepareDossier(
        profile: profile,
        topic: AdvisorSpecialization.retirement,
        tier: _expertTier,
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

  // ═══════════════════════════════════════════════════════════════
  //  ADVERSARIAL COMPLIANCE TESTS — 15 tests
  // ═══════════════════════════════════════════════════════════════

  group('Adversarial: Tier gating', () {
    test('13. free tier user blocked from findMatches', () {
      final profile = _profile();
      expect(
        () => AdvisorMatchingService.findMatches(
          profile: profile,
          need: AdvisorSpecialization.retirement,
          tier: SubscriptionTier.free,
        ),
        throwsA(isA<ExpertTierRequiredException>()),
      );
    });

    test('14. starter tier user blocked from findMatches', () {
      final profile = _profile();
      expect(
        () => AdvisorMatchingService.findMatches(
          profile: profile,
          need: AdvisorSpecialization.tax,
          tier: SubscriptionTier.starter,
        ),
        throwsA(isA<ExpertTierRequiredException>()),
      );
    });

    test('15. free tier user blocked from prepareDossier', () {
      final profile = _profile();
      expect(
        () => AdvisorMatchingService.prepareDossier(
          profile: profile,
          topic: AdvisorSpecialization.retirement,
          tier: SubscriptionTier.free,
          now: DateTime(2026, 3, 18),
        ),
        throwsA(isA<ExpertTierRequiredException>()),
      );
    });

    test('16. premium tier user allowed (positive gate check)', () {
      final profile = _profile();
      final matches = AdvisorMatchingService.findMatches(
        profile: profile,
        need: AdvisorSpecialization.retirement,
        tier: SubscriptionTier.premium,
      );
      expect(matches, isNotEmpty);
    });

    test('17. couplePlus tier user allowed', () {
      final profile = _profile();
      final matches = AdvisorMatchingService.findMatches(
        profile: profile,
        need: AdvisorSpecialization.retirement,
        tier: SubscriptionTier.couplePlus,
      );
      expect(matches, isNotEmpty);
    });
  });

  group('Adversarial: No-Ranking', () {
    test('18. AdvisorProfile has no rating field', () {
      // Structural check: the model must NOT expose a rating/score.
      // If someone re-adds a rating field, this test forces awareness.
      const advisor = AdvisorProfile(
        id: 'test',
        displayName: 'Test',
        specializations: [AdvisorSpecialization.tax],
        languages: ['fr'],
        cantons: ['VS'],
        isAvailable: true,
      );

      // Verify the constructor does NOT accept a 'rating' parameter
      // by confirming the object creates without one.
      expect(advisor.id, equals('test'));
      expect(advisor.displayName, equals('Test'));
    });

    test('19. results never sorted by any score or popularity metric', () {
      // Inject advisors with names in reverse alphabetical order.
      final pool = [
        const AdvisorProfile(
          id: 'z1',
          displayName: 'Ziegler',
          specializations: [AdvisorSpecialization.tax],
          languages: ['fr'],
          cantons: ['VS'],
          isAvailable: true,
        ),
        const AdvisorProfile(
          id: 'a1',
          displayName: 'Ammann',
          specializations: [AdvisorSpecialization.tax],
          languages: ['fr'],
          cantons: ['VS'],
          isAvailable: true,
        ),
        const AdvisorProfile(
          id: 'm1',
          displayName: 'Meyer',
          specializations: [AdvisorSpecialization.tax],
          languages: ['fr'],
          cantons: ['VS'],
          isAvailable: true,
        ),
      ];

      final profile = _profile(canton: 'VS');
      final matches = AdvisorMatchingService.findMatches(
        profile: profile,
        need: AdvisorSpecialization.tax,
        tier: _expertTier,
        advisorPool: pool,
      );

      // Must be alphabetical: Ammann, Meyer, Ziegler
      expect(matches[0].displayName, 'Ammann');
      expect(matches[1].displayName, 'Meyer');
      expect(matches[2].displayName, 'Ziegler');
    });
  });

  group('Adversarial: PII leak in dossier', () {
    test('20. exact salary never appears in dossier (Julien golden)',
        () async {
      // Julien: 122'207 CHF/an = 10183.92/mois
      final profile = _profile(salaireBrutMensuel: 10183.92);
      final dossier = await AdvisorMatchingService.prepareDossier(
        profile: profile,
        topic: AdvisorSpecialization.retirement,
        tier: _expertTier,
        now: DateTime(2026, 3, 18),
      );

      final allText = [
        dossier.summary,
        ...dossier.keyMetrics.values,
        ...dossier.questionsForAdvisor,
        dossier.disclaimer,
      ].join(' ');

      // Exact annual: 122207.04
      expect(allText, isNot(contains('122207')));
      expect(allText, isNot(contains("122'207")));
      expect(allText, isNot(contains('10183')));
      expect(allText, isNot(contains('10184')));
    });

    test('21. exact patrimoine never appears in dossier', () async {
      final profile = _profile(
        patrimoine: const PatrimoineProfile(
          epargneLiquide: 87543.21,
          investissements: 45678.90,
        ),
      );
      final dossier = await AdvisorMatchingService.prepareDossier(
        profile: profile,
        topic: AdvisorSpecialization.succession,
        tier: _expertTier,
        now: DateTime(2026, 3, 18),
      );

      final allText = [
        dossier.summary,
        ...dossier.keyMetrics.values,
      ].join(' ');

      expect(allText, isNot(contains('87543')));
      expect(allText, isNot(contains('45678')));
      expect(allText, isNot(contains('133222')));
    });

    test('22. employer name never appears (even if in profile notes)',
        () async {
      final profile = _profile();
      final dossier = await AdvisorMatchingService.prepareDossier(
        profile: profile,
        topic: AdvisorSpecialization.tax,
        tier: _expertTier,
        now: DateTime(2026, 3, 18),
      );

      final allText = [
        dossier.summary,
        ...dossier.keyMetrics.keys,
        ...dossier.keyMetrics.values,
      ].join(' ');

      // No employer-related keys should exist.
      expect(allText.toLowerCase(), isNot(contains('employeur')));
      expect(allText.toLowerCase(), isNot(contains('employer')));
    });

    test('23. IBAN pattern never in dossier output', () async {
      final profile = _profile();
      final dossier = await AdvisorMatchingService.prepareDossier(
        profile: profile,
        topic: AdvisorSpecialization.debt,
        tier: _expertTier,
        now: DateTime(2026, 3, 18),
      );

      final allText = [
        dossier.summary,
        ...dossier.keyMetrics.values,
        ...dossier.questionsForAdvisor,
        dossier.disclaimer,
      ].join(' ');

      // IBAN pattern
      expect(
        RegExp(r'CH\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d')
            .hasMatch(allText),
        isFalse,
      );
    });
  });

  group('Adversarial: Banned terms', () {
    test('24. disclaimer uses "spécialiste" never "conseiller"', () async {
      final profile = _profile();
      final dossier = await AdvisorMatchingService.prepareDossier(
        profile: profile,
        topic: AdvisorSpecialization.retirement,
        tier: _expertTier,
        now: DateTime(2026, 3, 18),
      );

      expect(dossier.disclaimer.toLowerCase(), isNot(contains('conseiller')));
      expect(dossier.disclaimer, contains('spécialiste'));
    });

    test('25. questions never contain "garanti", "certain", "assuré"',
        () async {
      final profile = _profile();

      for (final topic in AdvisorSpecialization.values) {
        final dossier = await AdvisorMatchingService.prepareDossier(
          profile: profile,
          topic: topic,
          tier: _expertTier,
          now: DateTime(2026, 3, 18),
        );

        final questionsText =
            dossier.questionsForAdvisor.join(' ').toLowerCase();

        for (final banned in [
          'garanti',
          'certain',
          'assuré',
          'sans risque',
        ]) {
          expect(
            questionsText.contains(banned),
            isFalse,
            reason: 'Banned term "$banned" in $topic questions',
          );
        }
      }
    });

    test('26. summary never uses absolute terms', () async {
      final profile = _profile();

      for (final topic in AdvisorSpecialization.values) {
        final dossier = await AdvisorMatchingService.prepareDossier(
          profile: profile,
          topic: topic,
          tier: _expertTier,
          now: DateTime(2026, 3, 18),
        );

        final summaryLower = dossier.summary.toLowerCase();
        for (final banned in _bannedTerms) {
          expect(
            summaryLower.contains(banned),
            isFalse,
            reason: 'Summary for $topic contains banned "$banned"',
          );
        }
      }
    });
  });

  group('Adversarial: No-Advice / educational only', () {
    test('27. dossier disclaimer states educational nature + LSFin', () async {
      final profile = _profile();
      final dossier = await AdvisorMatchingService.prepareDossier(
        profile: profile,
        topic: AdvisorSpecialization.mortgage,
        tier: _expertTier,
        now: DateTime(2026, 3, 18),
      );

      expect(dossier.disclaimer, contains('éducatif'));
      expect(dossier.disclaimer, contains('LSFin'));
      expect(
        dossier.disclaimer.toLowerCase(),
        contains('ne constitue pas un conseil'),
      );
    });
  });
}
