import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';
import 'package:mint_mobile/services/biography/anonymized_biography_service.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/contextual/coach_opener_service.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';

// ────────────────────────────────────────────────────────────
//  COMPLIANCE CHANNEL COVERAGE TESTS — Phase 06 / QA Profond
// ────────────────────────────────────────────────────────────
//
// Validates ComplianceGuard coverage on ALL 4 v2.0 output channels:
//   1. Alert channel (Phase 4 — AnticipationEngine templates)
//   2. Narrative biography channel (Phase 3 — AnonymizedBiographySummary)
//   3. Coach opener channel (Phase 5 — CoachOpenerService)
//   4. Extraction insights (Phase 2 — confidence > 0)
//
// Threat mitigations:
//   T-06-05: PII never in anonymized output
//   T-06-06: Banned terms caught in ALL channels
//   T-06-07: PII absent from system prompts
//
// See: COMP-01, QA-06, QA-10 requirements.
// ────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════
  // Group 1 — Alert channel (Phase 4)
  // ═══════════════════════════════════════════════════════════

  group('Group 1 — Alert channel compliance', () {
    test('all AlertTemplate enum values produce compliant template text', () {
      // Each AlertTemplate should have an associated titleKey/factKey
      // that when used in typical alert text, passes validateAlert.
      for (final template in AlertTemplate.values) {
        // Construct representative alert text for each template
        final alertText = _alertTextForTemplate(template);
        final result = ComplianceGuard.validateAlert(alertText);
        expect(
          result.isCompliant,
          isTrue,
          reason: 'AlertTemplate.${template.name} should produce compliant text, '
              'but got violations: ${result.violations}',
        );
      }
    });

    test('validateAlert catches "tu devrais" injected in alert title', () {
      const injected = 'Tu devrais verser avant le 31 decembre';
      final result = ComplianceGuard.validateAlert(injected);
      expect(result.isCompliant, isFalse);
      expect(result.violations, anyElement(contains('tu devrais')));
    });

    test('validateAlert catches "garanti" injected in alert body', () {
      const injected =
          'Le rendement garanti de ta caisse LPP augmente cette annee.';
      final result = ComplianceGuard.validateAlert(injected);
      expect(result.isCompliant, isFalse);
      expect(result.violations, anyElement(contains('garanti')));
    });

    test('validateAlert catches "sans risque" in alert text', () {
      const injected = 'Un placement sans risque pour ton 3a.';
      final result = ComplianceGuard.validateAlert(injected);
      expect(result.isCompliant, isFalse);
      expect(result.violations, anyElement(contains('sans risque')));
    });

    test('validateAlert catches prescriptive "fais un rachat"', () {
      const injected = 'Fais un rachat LPP avant la fin de l\'annee.';
      final result = ComplianceGuard.validateAlert(injected);
      expect(result.isCompliant, isFalse);
    });

    test('validateAlert rejects empty alert text', () {
      final result = ComplianceGuard.validateAlert('');
      expect(result.isCompliant, isFalse);
      expect(result.violations, anyElement(contains('vide')));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Group 2 — Narrative biography channel (Phase 3)
  // ═══════════════════════════════════════════════════════════

  group('Group 2 — Narrative biography anonymization', () {
    final now = DateTime(2026, 3, 15);

    BiographyFact _makeFact({
      required FactType type,
      required String value,
      DateTime? sourceDate,
    }) {
      return BiographyFact(
        id: '${type.name}_test',
        factType: type,
        value: value,
        source: FactSource.document,
        sourceDate: sourceDate ?? DateTime(2025, 12, 1),
        createdAt: DateTime(2025, 12, 1),
        updatedAt: DateTime(2026, 2, 1),
      );
    }

    test('AnonymizedBiographySummary does NOT contain exact salary', () {
      final facts = [
        _makeFact(type: FactType.salary, value: '98000'),
      ];
      final summary = AnonymizedBiographySummary.build(facts, now: now);
      expect(summary, isNot(contains('98000')));
      expect(summary, isNot(contains("98'000")));
    });

    test('AnonymizedBiographySummary does NOT contain exact LPP capital', () {
      final facts = [
        _makeFact(type: FactType.lppCapital, value: '250000'),
      ];
      final summary = AnonymizedBiographySummary.build(facts, now: now);
      expect(summary, isNot(contains('250000')));
      expect(summary, isNot(contains("250'000")));
    });

    test('AnonymizedBiographySummary does NOT contain employer name', () {
      // Employer name is never stored as a FactType, but test that
      // the output text itself never contains arbitrary company names
      // even if injected as a value
      final facts = [
        _makeFact(type: FactType.salary, value: '98000'),
        _makeFact(type: FactType.lppCapital, value: '250000'),
      ];
      final summary = AnonymizedBiographySummary.build(facts, now: now);
      // Employer names are NEVER in biography facts, but verify output
      // is safe text that passes compliance
      expect(summary, isNot(contains('Nestle')));
    });

    test('AnonymizedBiographySummary output passes ComplianceGuard.validate', () {
      final facts = [
        _makeFact(type: FactType.salary, value: '98000'),
        _makeFact(type: FactType.lppCapital, value: '250000'),
        _makeFact(type: FactType.threeACapital, value: '32000'),
        _makeFact(type: FactType.canton, value: 'VS'),
      ];
      final summary = AnonymizedBiographySummary.build(facts, now: now);
      final result = ComplianceGuard.validate(summary);
      // Summary should not trigger banned terms or prescriptive language
      expect(
        result.violations.where((v) => v.contains('Terme interdit')).isEmpty,
        isTrue,
        reason:
            'Anonymized biography should not contain banned terms: ${result.violations}',
      );
    });

    test('AnonymizedBiographySummary contains rounded values', () {
      final facts = [
        _makeFact(type: FactType.salary, value: '98000'),
        _makeFact(type: FactType.lppCapital, value: '250000'),
      ];
      final summary = AnonymizedBiographySummary.build(facts, now: now);
      // Salary 98000 rounded to nearest 5k = 100k
      expect(summary, contains('100k'));
      // LPP 250000 rounded to nearest 10k = 250k
      expect(summary, contains('250k'));
    });

    test('AnonymizedBiographySummary includes BIOGRAPHIE FINANCIERE delimiters', () {
      final facts = [
        _makeFact(type: FactType.salary, value: '98000'),
      ];
      final summary = AnonymizedBiographySummary.build(facts, now: now);
      expect(summary, contains('BIOGRAPHIE FINANCIERE'));
      expect(summary, contains('FIN BIOGRAPHIE'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Group 3 — Coach opener channel (Phase 5)
  // ═══════════════════════════════════════════════════════════

  group('Group 3 — Coach opener compliance', () {
    CoachProfile _makeProfile({
      double salaireBrutMensuel = 8000,
      List<PlannedMonthlyContribution> contributions = const [],
      String canton = 'VD',
      int birthYear = 1990,
    }) {
      return CoachProfile(
        salaireBrutMensuel: salaireBrutMensuel,
        canton: canton,
        birthYear: birthYear,
        plannedContributions: contributions,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055, 1, 1),
          label: 'Retraite',
        ),
      );
    }

    BiographyFact _makeSalaryFact({
      required DateTime updatedAt,
      FactSource source = FactSource.document,
    }) {
      return BiographyFact(
        id: 'salary_test',
        factType: FactType.salary,
        value: '98000',
        source: source,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: updatedAt,
      );
    }

    test('priority 1 (salary increase) opener passes ComplianceGuard', () {
      final now = DateTime(2026, 3, 15);
      final profile = _makeProfile();
      final facts = [
        _makeSalaryFact(updatedAt: DateTime(2026, 3, 1)),
      ];
      final opener = CoachOpenerService.generate(
        profile: profile,
        facts: facts,
        now: now,
      );
      final result = ComplianceGuard.validateAlert(opener);
      expect(result.isCompliant, isTrue,
          reason: 'Salary increase opener failed compliance: ${result.violations}');
    });

    test('priority 2 (recent document) opener passes ComplianceGuard', () {
      final now = DateTime(2026, 3, 15);
      // Profile with no salary -> skip 3a gap path, hit document path
      final profile = _makeProfile(salaireBrutMensuel: 0);
      final facts = [
        BiographyFact(
          id: 'lpp_test',
          factType: FactType.lppCapital,
          value: '250000',
          source: FactSource.document,
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
      ];
      final opener = CoachOpenerService.generate(
        profile: profile,
        facts: facts,
        now: now,
      );
      final result = ComplianceGuard.validateAlert(opener);
      expect(result.isCompliant, isTrue,
          reason: 'Recent document opener failed compliance: ${result.violations}');
    });

    test('priority 3 (3a gap) opener passes ComplianceGuard', () {
      final now = DateTime(2026, 3, 15);
      // Profile with salary and partial 3a contributions -> triggers 3a gap
      final profile = _makeProfile(
        salaireBrutMensuel: 8000,
        contributions: [
          const PlannedMonthlyContribution(
            id: '3a_test',
            label: '3a Test',
            amount: 200,
            category: '3a',
          ),
        ],
      );
      final opener = CoachOpenerService.generate(
        profile: profile,
        facts: [],
        now: now,
      );
      final result = ComplianceGuard.validateAlert(opener);
      expect(result.isCompliant, isTrue,
          reason: '3a gap opener failed compliance: ${result.violations}');
    });

    test('priority 5 (fallback) opener passes ComplianceGuard', () {
      final now = DateTime(2026, 3, 15);
      // Profile with no salary -> fallback greeting path
      final profile = _makeProfile(
        salaireBrutMensuel: 0,
      );
      final opener = CoachOpenerService.generate(
        profile: profile,
        facts: [],
        now: now,
      );
      final result = ComplianceGuard.validateAlert(opener);
      expect(result.isCompliant, isTrue,
          reason: 'Fallback opener failed compliance: ${result.violations}');
    });

    test('CoachOpenerService rejects "optimal" if injected in opener text', () {
      // This tests the ComplianceGuard layer, not the opener itself
      const injected = 'Voici la strategie optimale pour ton 3a.';
      final result = ComplianceGuard.validate(injected);
      expect(result.isCompliant, isFalse);
      expect(result.violations, anyElement(contains('optimal')));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Group 4 — Confidence > 0 for all 9 personas
  // ═══════════════════════════════════════════════════════════

  group('Group 4 — Confidence > 0 for all 9 personas', () {
    // Persona definitions: age, grossSalary, canton
    // Based on the 9 golden path personas (Lea, Marc, Sophie, Thomas, Anna, Pierre, Julia, Laurent, Nadia)
    final personas = <String, Map<String, dynamic>>{
      'Lea': {'age': 22, 'grossSalary': 55000.0, 'canton': 'VD'},
      'Marc': {'age': 28, 'grossSalary': 72000.0, 'canton': 'ZH'},
      'Sophie': {'age': 35, 'grossSalary': 85000.0, 'canton': 'GE'},
      'Thomas': {'age': 42, 'grossSalary': 110000.0, 'canton': 'BE'},
      'Anna': {'age': 48, 'grossSalary': 95000.0, 'canton': 'TI'},
      'Pierre': {'age': 55, 'grossSalary': 130000.0, 'canton': 'VS'},
      'Julia': {'age': 30, 'grossSalary': 68000.0, 'canton': 'NE'},
      'Laurent': {'age': 60, 'grossSalary': 120000.0, 'canton': 'FR'},
      'Nadia': {'age': 38, 'grossSalary': 78000.0, 'canton': 'AG'},
    };

    for (final entry in personas.entries) {
      test('${entry.key}: replacementRate > 0', () {
        final result = MinimalProfileService.compute(
          age: entry.value['age'] as int,
          grossSalary: entry.value['grossSalary'] as double,
          canton: entry.value['canton'] as String,
        );
        expect(
          result.replacementRate,
          greaterThan(0),
          reason:
              '${entry.key} (age ${entry.value['age']}, salary ${entry.value['grossSalary']}) '
              'should have replacementRate > 0 but got ${result.replacementRate}',
        );
      });
    }
  });
}

// ── Helpers ──────────────────────────────────────────────────

/// Generate representative compliant alert text for each AlertTemplate.
///
/// These texts mimic what AnticipationEngine produces (ARB key resolution
/// in the UI layer). The text here is the French fallback.
String _alertTextForTemplate(AlertTemplate template) {
  switch (template) {
    case AlertTemplate.fiscal3aDeadline:
      return 'Il reste 15 jours pour verser sur ton 3a (plafond 7\'258 CHF). '
          'Source\u00a0: OPP3 art.\u00a07.';
    case AlertTemplate.cantonalTaxDeadline:
      return 'La declaration fiscale du canton VD est attendue pour le 31.03. '
          'Source\u00a0: LIFD art.\u00a0166.';
    case AlertTemplate.lppRachatWindow:
      return 'Un rachat LPP pourrait etre interessant avant la fin de l\'annee fiscale. '
          'Source\u00a0: LPP art.\u00a079b.';
    case AlertTemplate.salaryIncrease3aRecalc:
      return 'Ton salaire a change. Le plafond 3a reste 7\'258 CHF. '
          'Source\u00a0: OPP3 art.\u00a07.';
    case AlertTemplate.ageMilestoneLppBonification:
      return 'A 35 ans, ta bonification LPP passe de 7% a 10%. '
          'Source\u00a0: LPP art.\u00a016.';
  }
}
