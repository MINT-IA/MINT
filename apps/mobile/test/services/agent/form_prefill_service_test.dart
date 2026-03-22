/// FormPrefillService — Agent Autonome v1 (S68).
///
/// 16 tests covering:
///  1.  prepareTaxDeclaration returns non-empty fields
///  2.  Tax declaration has all required fields
///  3.  Tax declaration uses range format (not exact salary)
///  4.  3a form has correct plafond for salarié (7'258 CHF)
///  5.  3a form has correct plafond for indépendant sans LPP (36'288 CHF)
///  6.  LPP buyback form includes rachat max when available
///  7.  LPP buyback form has placeholder when rachat = 0
///  8.  All fields have userMustConfirm = true
///  9.  requiresValidation is always true
/// 10.  No PII (name, IBAN, SSN) in any pre-filled value
/// 11.  Disclaimer present and non-empty on every form type
/// 12.  Disclaimer contains "éducatif" reference
/// 13.  Golden couple Julien: taxYear produces taxYear field
/// 14.  Minimal profile (zero salary) generates valid form
/// 15.  isEstimated = true for financial amounts
/// 16.  No banned terms in any form output
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/agent/form_prefill_service.dart';

// ════════════════════════════════════════════════════════════════
//  HELPERS
// ════════════════════════════════════════════════════════════════

/// Build a French [S] localizations instance.
Future<S> _buildL10n(WidgetTester tester) async {
  late S result;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Builder(
        builder: (context) {
          result = S.of(context)!;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return result;
}

/// Julien — golden couple salarié avec LPP.
CoachProfile _julienProfile() {
  return CoachProfile(
    firstName: 'Julien',
    birthYear: 1977,
    canton: 'VS',
    nationality: 'CH',
    salaireBrutMensuel: 10183.92, // 122'207 CHF/an
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.marie,
    nombreEnfants: 2,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042, 1, 1),
      label: 'Retraite',
    ),
    prevoyance: const PrevoyanceProfile(
      nomCaisse: 'CPE',
      avoirLppTotal: 70377,
      rachatMaximum: 539414,
      rachatEffectue: 0,
      totalEpargne3a: 32000,
    ),
    patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
  );
}

/// Indépendant sans LPP.
CoachProfile _independantSansLppProfile() {
  return CoachProfile(
    birthYear: 1985,
    canton: 'GE',
    salaireBrutMensuel: 8000,
    nombreDeMois: 12,
    employmentStatus: 'independant',
    prevoyance: const PrevoyanceProfile(totalEpargne3a: 14000),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050, 1, 1),
      label: 'Retraite',
    ),
  );
}

/// Minimal profile with zero salary.
CoachProfile _minimalProfile() {
  return CoachProfile(
    birthYear: 1990,
    canton: 'ZH',
    salaireBrutMensuel: 0,
    nombreDeMois: 12,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055, 1, 1),
      label: 'Retraite',
    ),
  );
}

/// MINT compliance: banned terms.
const _bannedTerms = [
  'garanti',
  'certain',
  'assuré',
  'sans risque',
  'optimal',
  'meilleur',
  'parfait',
  'conseiller',
  'garantie',
  'assurée',
  'optimale',
  'meilleure',
  'parfaite',
];

// ════════════════════════════════════════════════════════════════
//  TESTS
// ════════════════════════════════════════════════════════════════

void main() {
  // ── 1. prepareTaxDeclaration returns non-empty fields ─────────
  testWidgets('1. prepareTaxDeclaration returns non-empty fields',
      (tester) async {
    final l = await _buildL10n(tester);
    final result = FormPrefillService.prepareTaxDeclaration(
      profile: _julienProfile(),
      taxYear: 2025,
      l: l,
    );
    expect(result.fields, isNotEmpty);
    expect(result.formType, 'taxDeclaration');
  });

  // ── 2. Tax declaration has all required fields ─────────────────
  testWidgets('2. Tax declaration has all required fields', (tester) async {
    final l = await _buildL10n(tester);
    final result = FormPrefillService.prepareTaxDeclaration(
      profile: _julienProfile(),
      taxYear: 2025,
      l: l,
    );
    final labels = result.fields.map((f) => f.label).toList();
    // Must include revenu, canton, situation, plafond 3a
    expect(labels, anyElement(contains('Revenu brut')));
    expect(labels, anyElement(contains('Canton')));
    expect(labels, anyElement(contains('familiale')));
    expect(labels, anyElement(contains('3a')));
  });

  // ── 3. Tax declaration uses range format (not exact salary) ───
  testWidgets('3. Tax declaration uses range format, not exact salary',
      (tester) async {
    final l = await _buildL10n(tester);
    final result = FormPrefillService.prepareTaxDeclaration(
      profile: _julienProfile(),
      taxYear: 2025,
      l: l,
    );
    // Exact salary is 122'207 — must NOT appear
    final allValues = result.fields.map((f) => f.value).join(' ');
    expect(allValues, isNot(contains("122'207")));
    expect(allValues, isNot(contains('122207')));
    // Range format: should contain tilde and dash
    final revenuField = result.fields
        .firstWhere((f) => f.label.contains('Revenu'));
    expect(revenuField.value, startsWith('~'));
    expect(revenuField.value, contains('-'));
  });

  // ── 4. 3a form: correct plafond for salarié (7'258) ─────────
  testWidgets("4. 3a form: correct plafond for salarié (7'258)",
      (tester) async {
    final l = await _buildL10n(tester);
    final result = FormPrefillService.prepare3aForm(
      profile: _julienProfile(),
      year: 2025,
      l: l,
    );
    final montantField = result.fields
        .firstWhere((f) => f.label.contains('versement'));
    expect(montantField.value, contains("7'258"));
  });

  // ── 5. 3a form: correct plafond for indépendant sans LPP (36'288) ─
  testWidgets("5. 3a form: correct plafond for indépendant sans LPP (36'288)",
      (tester) async {
    final l = await _buildL10n(tester);
    final result = FormPrefillService.prepare3aForm(
      profile: _independantSansLppProfile(),
      year: 2025,
      l: l,
    );
    final montantField = result.fields
        .firstWhere((f) => f.label.contains('versement'));
    expect(montantField.value, contains("36'288"));
  });

  // ── 6. LPP buyback form includes rachat max when available ───
  testWidgets('6. LPP buyback form includes rachat max when available',
      (tester) async {
    final l = await _buildL10n(tester);
    final result = FormPrefillService.prepareLppBuyback(
      profile: _julienProfile(),
      l: l,
    );
    final rachatField = result.fields
        .firstWhere((f) => f.label.contains('maximum'));
    // Julien has rachatMaximum = 539'414 → displayed as range
    expect(rachatField.value, startsWith('~'));
    expect(rachatField.value, contains('-'));
    // Must NOT contain exact 539414
    expect(rachatField.value, isNot(contains("539'414")));
  });

  // ── 7. LPP buyback form has placeholder when rachat = 0 ──────
  testWidgets('7. LPP buyback form has placeholder when rachat = 0',
      (tester) async {
    final l = await _buildL10n(tester);
    final result = FormPrefillService.prepareLppBuyback(
      profile: _minimalProfile(),
      l: l,
    );
    final rachatField = result.fields
        .firstWhere((f) => f.label.contains('maximum'));
    // No rachat available → placeholder for user
    expect(rachatField.value, contains('['));
  });

  // ── 8. All fields have userMustConfirm = true ─────────────────
  testWidgets('8. All fields have userMustConfirm = true', (tester) async {
    final l = await _buildL10n(tester);
    for (final build in [
      () => FormPrefillService.prepareTaxDeclaration(
            profile: _julienProfile(), taxYear: 2025, l: l),
      () => FormPrefillService.prepare3aForm(
            profile: _julienProfile(), year: 2025, l: l),
      () => FormPrefillService.prepareLppBuyback(
            profile: _julienProfile(), l: l),
    ]) {
      final result = build();
      for (final field in result.fields) {
        expect(
          field.userMustConfirm,
          isTrue,
          reason: 'Field "${field.label}" must have userMustConfirm = true',
        );
      }
    }
  });

  // ── 9. requiresValidation is always true ─────────────────────
  testWidgets('9. requiresValidation is always true', (tester) async {
    final l = await _buildL10n(tester);
    expect(
      FormPrefillService.prepareTaxDeclaration(
              profile: _julienProfile(), taxYear: 2025, l: l)
          .requiresValidation,
      isTrue,
    );
    expect(
      FormPrefillService.prepare3aForm(
              profile: _julienProfile(), year: 2025, l: l)
          .requiresValidation,
      isTrue,
    );
    expect(
      FormPrefillService.prepareLppBuyback(profile: _julienProfile(), l: l)
          .requiresValidation,
      isTrue,
    );
  });

  // ── 10. No PII in any pre-filled value ───────────────────────
  testWidgets('10. No PII (name, IBAN, SSN) in any pre-filled value',
      (tester) async {
    final l = await _buildL10n(tester);
    final ibanRe = RegExp(
      r'[A-Z]{2}\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{0,2}',
    );
    final ssnRe = RegExp(r'756\.\d{4}\.\d{4}\.\d{2}');

    for (final result in [
      FormPrefillService.prepareTaxDeclaration(
          profile: _julienProfile(), taxYear: 2025, l: l),
      FormPrefillService.prepare3aForm(
          profile: _julienProfile(), year: 2025, l: l),
      FormPrefillService.prepareLppBuyback(profile: _julienProfile(), l: l),
    ]) {
      final allValues = result.fields.map((f) => f.value).join(' ');
      // No IBAN
      expect(ibanRe.hasMatch(allValues), isFalse,
          reason: 'IBAN found in ${result.formType}');
      // No SSN/AVS
      expect(ssnRe.hasMatch(allValues), isFalse,
          reason: 'SSN found in ${result.formType}');
      // Name "Julien" must NOT appear in pre-filled values
      expect(allValues.toLowerCase(), isNot(contains('julien')),
          reason: 'Name found in ${result.formType}');
    }
  });

  // ── 11. Disclaimer present and non-empty ─────────────────────
  testWidgets('11. Disclaimer present and non-empty', (tester) async {
    final l = await _buildL10n(tester);
    for (final result in [
      FormPrefillService.prepareTaxDeclaration(
          profile: _julienProfile(), taxYear: 2025, l: l),
      FormPrefillService.prepare3aForm(
          profile: _julienProfile(), year: 2025, l: l),
      FormPrefillService.prepareLppBuyback(profile: _julienProfile(), l: l),
    ]) {
      expect(result.disclaimer, isNotEmpty,
          reason: 'Disclaimer missing on ${result.formType}');
    }
  });

  // ── 12. Disclaimer contains "éducatif" ───────────────────────
  testWidgets('12. Disclaimer contains "éducatif"', (tester) async {
    final l = await _buildL10n(tester);
    final result = FormPrefillService.prepareTaxDeclaration(
      profile: _julienProfile(),
      taxYear: 2025,
      l: l,
    );
    expect(result.disclaimer.toLowerCase(), contains('éducatif'));
  });

  // ── 13. Golden couple Julien: taxYear field matches input ─────
  testWidgets('13. Golden couple Julien: taxYear field matches input',
      (tester) async {
    final l = await _buildL10n(tester);
    final result = FormPrefillService.prepareTaxDeclaration(
      profile: _julienProfile(),
      taxYear: 2025,
      l: l,
    );
    // First field is the tax year
    expect(result.fields.first.value, '2025');
  });

  // ── 14. Minimal profile (zero salary) generates valid form ───
  testWidgets('14. Minimal profile generates valid form', (tester) async {
    final l = await _buildL10n(tester);
    // Should not throw
    final taxResult = FormPrefillService.prepareTaxDeclaration(
      profile: _minimalProfile(),
      taxYear: 2025,
      l: l,
    );
    expect(taxResult.fields, isNotEmpty);
    expect(taxResult.requiresValidation, isTrue);

    final threeAResult = FormPrefillService.prepare3aForm(
      profile: _minimalProfile(),
      year: 2025,
      l: l,
    );
    expect(threeAResult.fields, isNotEmpty);
    expect(threeAResult.requiresValidation, isTrue);
  });

  // ── 15. isEstimated = true for financial amounts ──────────────
  testWidgets('15. isEstimated = true for financial amounts', (tester) async {
    final l = await _buildL10n(tester);
    final result = FormPrefillService.prepareTaxDeclaration(
      profile: _julienProfile(),
      taxYear: 2025,
      l: l,
    );
    // Revenu and plafond fields must be estimated
    final revenuField = result.fields
        .firstWhere((f) => f.label.contains('Revenu'));
    expect(revenuField.isEstimated, isTrue);
    final plafondField = result.fields
        .firstWhere((f) => f.label.contains('3a'));
    expect(plafondField.isEstimated, isTrue);
  });

  // ── 16. No banned terms in any form output ───────────────────
  testWidgets('16. No banned terms in any form output', (tester) async {
    final l = await _buildL10n(tester);
    for (final result in [
      FormPrefillService.prepareTaxDeclaration(
          profile: _julienProfile(), taxYear: 2025, l: l),
      FormPrefillService.prepare3aForm(
          profile: _julienProfile(), year: 2025, l: l),
      FormPrefillService.prepareLppBuyback(profile: _julienProfile(), l: l),
    ]) {
      final allText = [
        result.disclaimer,
        ...result.fields.map((f) => '${f.label} ${f.value}'),
      ].join(' ').toLowerCase();

      for (final banned in _bannedTerms) {
        final pattern = RegExp('\\b${RegExp.escape(banned)}\\b');
        expect(
          pattern.hasMatch(allText),
          isFalse,
          reason: 'Banned term "$banned" found in ${result.formType}',
        );
      }
    }
  });
}
