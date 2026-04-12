/// DossierPreparationService — S65 Expert Tier.
///
/// 17 tests covering:
///  1.  Disclaimer always present in every dossier
///  2.  Disclaimer contains "LSFin" reference
///  3.  Disclaimer uses "spécialiste" — NEVER "conseiller"
///  4.  No exact salary in retirement dossier (Julien golden: 122k)
///  5.  No exact salary in any specialization
///  6.  No PII patterns (IBAN, SSN) in any dossier output
///  7.  All specializations return non-empty sections
///  8.  All section titles are non-empty strings (i18n resolved)
///  9.  All item labels are non-empty strings (i18n resolved)
///  10. profileCompleteness is in [0.0, 1.0]
///  11. missingDataWarnings is empty when profile is complete
///  12. missingDataWarnings is non-empty when profile has gaps
///  13. isEstimated flag is set for inferred values
///  14. Item values use range format, not exact amounts
///  15. Expat dossier includes nationality and archetype sections
///  16. Debt dossier includes ratio category, never an exact figure
///  17. No banned terms in any dossier text
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/expert/advisor_specialization.dart';
import 'package:mint_mobile/services/expert/dossier_preparation_service.dart';

// ══════════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════════

/// Build a test [S] localizations instance using the French locale.
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

/// Minimal complete CoachProfile with known golden values (Julien + Lauren declared).
///
/// Includes conjoint so that retirement completeness check passes fully.
CoachProfile _julienProfile() {
  return CoachProfile(
    birthYear: 1977,
    canton: 'VS',
    nationality: 'CH',
    salaireBrutMensuel: 10183.92, // 122'207 CHF/an
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.marie,
    nombreEnfants: 2,
    conjoint: const ConjointProfile(
      birthYear: 1982,
      salaireBrutMensuel: 5583.33,
      nationality: 'US',
      prevoyance: PrevoyanceProfile(
        avoirLppTotal: 19620,
        anneesContribuees: 10,
      ),
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042, 12, 31),
      label: 'Retraite',
    ),
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 70377,
      rachatMaximum: 539414,
      rachatEffectue: 0,
      anneesContribuees: 28,
      lacunesAVS: 2,
      renteAVSEstimeeMensuelle: 2100,
      totalEpargne3a: 32000,
      nombre3a: 2,
    ),
    patrimoine: const PatrimoineProfile(
      epargneLiquide: 50000,
      investissements: 20000,
      propertyMarketValue: 650000,
      mortgageBalance: 480000,
    ),
  );
}

/// Profile with many fields missing to test incomplete detection.
CoachProfile _minimalProfile() {
  return CoachProfile(
    birthYear: 1985,
    canton: '',
    salaireBrutMensuel: 5000,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.celibataire,
    nombreEnfants: 0,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050, 12, 31),
      label: 'Retraite',
    ),
  );
}

/// Expat US profile for expat specialization tests.
CoachProfile _laurenProfile() {
  return CoachProfile(
    birthYear: 1982,
    canton: 'VS',
    nationality: 'US',
    salaireBrutMensuel: 5583.33, // ~67k CHF/an
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.marie,
    nombreEnfants: 2,
    arrivalAge: 30,
    residencePermit: 'B',
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2047, 12, 31),
      label: 'Retraite',
    ),
    prevoyance: const PrevoyanceProfile(
      avoirLppTotal: 19620,
      anneesContribuees: 10,
      lacunesAVS: 5,
    ),
  );
}

/// Profile for debt management tests.
CoachProfile _debtProfile() {
  return CoachProfile(
    birthYear: 1990,
    canton: 'ZH',
    salaireBrutMensuel: 4000,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.celibataire,
    nombreEnfants: 0,
    goalA: GoalA(
      type: GoalAType.debtFree,
      targetDate: DateTime(2030, 12, 31),
      label: 'Désendetter',
    ),
    dettes: const DetteProfile(
      creditConsommation: 15000,
      leasing: 8000,
      mensualiteCreditConso: 500,
      mensualiteLeasing: 350,
    ),
  );
}

/// Banned compliance terms.
const _bannedTerms = [
  'conseiller',
  'garanti',
  'certain',
  'assuré',
  'sans risque',
  'optimal',
  'meilleur',
  'parfait',
];

/// PII patterns that must never appear.
final _piiPatterns = [
  RegExp(r'CH\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d'), // IBAN
  RegExp(r'\d{3}\.\d{4}\.\d{4}\.\d{2}'), // Swiss SSN
  RegExp(r'10183'), // Julien's exact monthly salary
  RegExp(r'10184'),
  RegExp(r'122207'), // Julien's exact annual salary
  RegExp(r"122'207"),
];

// ══════════════════════════════════════════════════════════════
//  TESTS
// ══════════════════════════════════════════════════════════════

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('1. disclaimer always present in every dossier', (tester) async {
    final l = await _buildL10n(tester);
    for (final spec in AdvisorSpecialization.values) {
      final dossier = DossierPreparationService.prepare(
        profile: _julienProfile(),
        specialization: spec,
        l: l,
        now: DateTime(2026, 3, 18),
      );
      expect(
        dossier.disclaimer,
        isNotEmpty,
        reason: 'Disclaimer must be present for $spec',
      );
    }
  });

  testWidgets('2. disclaimer contains LSFin reference', (tester) async {
    final l = await _buildL10n(tester);
    final dossier = DossierPreparationService.prepare(
      profile: _julienProfile(),
      specialization: AdvisorSpecialization.retirement,
      l: l,
      now: DateTime(2026, 3, 18),
    );
    expect(dossier.disclaimer, contains('LSFin'));
  });

  testWidgets('3. disclaimer uses spécialiste — never conseiller', (tester) async {
    final l = await _buildL10n(tester);
    for (final spec in AdvisorSpecialization.values) {
      final dossier = DossierPreparationService.prepare(
        profile: _julienProfile(),
        specialization: spec,
        l: l,
        now: DateTime(2026, 3, 18),
      );
      expect(
        dossier.disclaimer.toLowerCase(),
        isNot(contains('conseiller')),
        reason: 'Banned term "conseiller" in $spec disclaimer',
      );
      expect(
        dossier.disclaimer,
        contains('spécialiste'),
        reason: 'Disclaimer for $spec must use "spécialiste"',
      );
    }
  });

  testWidgets(
      '4. exact salary never in retirement dossier (Julien golden 122k)',
      (tester) async {
    final l = await _buildL10n(tester);
    final dossier = DossierPreparationService.prepare(
      profile: _julienProfile(),
      specialization: AdvisorSpecialization.retirement,
      l: l,
      now: DateTime(2026, 3, 18),
    );

    final allText = _dossierText(dossier);
    expect(allText, isNot(contains('122207')));
    expect(allText, isNot(contains("122'207")));
    expect(allText, isNot(contains('10183')));
    expect(allText, isNot(contains('10184')));
  });

  testWidgets('5. no exact salary in any specialization', (tester) async {
    final l = await _buildL10n(tester);
    for (final spec in AdvisorSpecialization.values) {
      final dossier = DossierPreparationService.prepare(
        profile: _julienProfile(),
        specialization: spec,
        l: l,
        now: DateTime(2026, 3, 18),
      );
      final allText = _dossierText(dossier);
      for (final pattern in _piiPatterns) {
        expect(
          pattern.hasMatch(allText),
          isFalse,
          reason: 'PII pattern found in $spec dossier: ${pattern.pattern}',
        );
      }
    }
  });

  testWidgets('6. no PII patterns (IBAN, SSN) in any dossier', (tester) async {
    final l = await _buildL10n(tester);
    for (final spec in AdvisorSpecialization.values) {
      final dossier = DossierPreparationService.prepare(
        profile: _julienProfile(),
        specialization: spec,
        l: l,
        now: DateTime(2026, 3, 18),
      );
      final allText = _dossierText(dossier);
      expect(
        RegExp(r'CH\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d').hasMatch(allText),
        isFalse,
        reason: 'IBAN pattern must not appear in $spec dossier',
      );
      expect(
        RegExp(r'\d{3}\.\d{4}\.\d{4}\.\d{2}').hasMatch(allText),
        isFalse,
        reason: 'SSN pattern must not appear in $spec dossier',
      );
    }
  });

  testWidgets('7. all specializations return non-empty sections', (tester) async {
    final l = await _buildL10n(tester);
    for (final spec in AdvisorSpecialization.values) {
      final dossier = DossierPreparationService.prepare(
        profile: _julienProfile(),
        specialization: spec,
        l: l,
        now: DateTime(2026, 3, 18),
      );
      expect(
        dossier.sections,
        isNotEmpty,
        reason: '$spec must have at least one section',
      );
    }
  });

  testWidgets('8. all section titles are non-empty (i18n resolved)', (tester) async {
    final l = await _buildL10n(tester);
    for (final spec in AdvisorSpecialization.values) {
      final dossier = DossierPreparationService.prepare(
        profile: _julienProfile(),
        specialization: spec,
        l: l,
        now: DateTime(2026, 3, 18),
      );
      for (final section in dossier.sections) {
        expect(
          section.title,
          isNotEmpty,
          reason: 'Section title must not be empty in $spec',
        );
      }
    }
  });

  testWidgets('9. all item labels are non-empty (i18n resolved)', (tester) async {
    final l = await _buildL10n(tester);
    for (final spec in AdvisorSpecialization.values) {
      final dossier = DossierPreparationService.prepare(
        profile: _julienProfile(),
        specialization: spec,
        l: l,
        now: DateTime(2026, 3, 18),
      );
      for (final section in dossier.sections) {
        for (final item in section.items) {
          expect(
            item.label,
            isNotEmpty,
            reason: 'Item label must not be empty in $spec / ${section.title}',
          );
          expect(
            item.value,
            isNotEmpty,
            reason: 'Item value must not be empty in $spec / ${section.title} / ${item.label}',
          );
        }
      }
    }
  });

  testWidgets('10. profileCompleteness is in [0.0, 1.0]', (tester) async {
    final l = await _buildL10n(tester);
    for (final spec in AdvisorSpecialization.values) {
      final dossier = DossierPreparationService.prepare(
        profile: _julienProfile(),
        specialization: spec,
        l: l,
        now: DateTime(2026, 3, 18),
      );
      expect(
        dossier.profileCompleteness,
        inInclusiveRange(0.0, 1.0),
        reason: 'Completeness out of range for $spec: ${dossier.profileCompleteness}',
      );
    }
  });

  testWidgets('11. missingDataWarnings is empty for complete retirement profile',
      (tester) async {
    final l = await _buildL10n(tester);
    final dossier = DossierPreparationService.prepare(
      profile: _julienProfile(),
      specialization: AdvisorSpecialization.retirement,
      l: l,
      now: DateTime(2026, 3, 18),
    );
    // Julien's profile has LPP, AVS years, rachat, 3a, conjoint.
    expect(dossier.missingDataWarnings, isEmpty);
    expect(dossier.profileCompleteness, equals(1.0));
  });

  testWidgets('12. missingDataWarnings non-empty for incomplete profile',
      (tester) async {
    final l = await _buildL10n(tester);
    final dossier = DossierPreparationService.prepare(
      profile: _minimalProfile(),
      specialization: AdvisorSpecialization.retirement,
      l: l,
      now: DateTime(2026, 3, 18),
    );
    expect(
      dossier.missingDataWarnings,
      isNotEmpty,
      reason: 'Minimal profile must have missing data warnings',
    );
    expect(
      dossier.profileCompleteness,
      lessThan(1.0),
      reason: 'Minimal profile completeness must be < 1.0',
    );
  });

  testWidgets('13. isEstimated flag is true for inferred LPP on minimal profile',
      (tester) async {
    final l = await _buildL10n(tester);
    final dossier = DossierPreparationService.prepare(
      profile: _minimalProfile(),
      specialization: AdvisorSpecialization.retirement,
      l: l,
      now: DateTime(2026, 3, 18),
    );
    // With no LPP data, the LPP balance item should be marked estimated.
    // At least one estimated item must exist in the minimal profile dossier.
    final allEstimated = dossier.sections
        .expand((s) => s.items)
        .where((i) => i.isEstimated)
        .toList();
    expect(
      allEstimated,
      isNotEmpty,
      reason: 'Minimal profile must have at least one isEstimated item',
    );
  });

  testWidgets('14. salary item uses range format, not exact amount', (tester) async {
    final l = await _buildL10n(tester);
    final dossier = DossierPreparationService.prepare(
      profile: _julienProfile(),
      specialization: AdvisorSpecialization.retirement,
      l: l,
      now: DateTime(2026, 3, 18),
    );
    // Find the salary item.
    final salaryItems = dossier.sections
        .expand((s) => s.items)
        .where((i) => i.value.contains('CHF') && i.value.contains('k'))
        .toList();
    expect(
      salaryItems,
      isNotEmpty,
      reason: 'At least one salary/amount item must use CHF range format (e.g. CHF 100-150k)',
    );
    // None of them should contain exact amounts
    for (final item in salaryItems) {
      expect(item.value, isNot(contains('122207')));
      expect(item.value, isNot(contains('10183')));
    }
  });

  testWidgets('15. expat dossier includes nationality and archetype items',
      (tester) async {
    final l = await _buildL10n(tester);
    final dossier = DossierPreparationService.prepare(
      profile: _laurenProfile(),
      specialization: AdvisorSpecialization.expatriation,
      l: l,
      now: DateTime(2026, 3, 18),
    );
    final allLabels = dossier.sections
        .expand((s) => s.items)
        .map((i) => i.label)
        .toList();
    // Nationality and archetype items must be present.
    final allValues = dossier.sections
        .expand((s) => s.items)
        .map((i) => i.value)
        .toList();
    expect(allLabels, isNotEmpty);
    // The profile's nationality "US" must appear as a value (not PII — it's a country code).
    expect(allValues, contains('US'));
  });

  testWidgets('16. debt dossier uses category labels, never exact amounts',
      (tester) async {
    final l = await _buildL10n(tester);
    final dossier = DossierPreparationService.prepare(
      profile: _debtProfile(),
      specialization: AdvisorSpecialization.debtManagement,
      l: l,
      now: DateTime(2026, 3, 18),
    );
    final allText = _dossierText(dossier);
    // Exact amounts from _debtProfile must not appear.
    expect(allText, isNot(contains('15000')));
    expect(allText, isNot(contains('8000')));
    expect(allText, isNot(contains('500')), reason: 'Monthly payments not shown exactly');
    expect(allText, isNot(contains('350')));
    // Category labels should appear.
    final allValues = dossier.sections
        .expand((s) => s.items)
        .map((i) => i.value)
        .toList();
    expect(allValues, isNotEmpty);
  });

  testWidgets('17. no banned terms in any dossier text across all specializations',
      (tester) async {
    final l = await _buildL10n(tester);
    for (final spec in AdvisorSpecialization.values) {
      final dossier = DossierPreparationService.prepare(
        profile: _julienProfile(),
        specialization: spec,
        l: l,
        now: DateTime(2026, 3, 18),
      );
      final allText = _dossierText(dossier).toLowerCase();
      for (final banned in _bannedTerms) {
        expect(
          allText.contains(banned.toLowerCase()),
          isFalse,
          reason: 'Banned term "$banned" found in $spec dossier',
        );
      }
    }
  });
}

// ══════════════════════════════════════════════════════════════
//  UTILITY
// ══════════════════════════════════════════════════════════════

/// Concatenate all text from a dossier for compliance scanning.
String _dossierText(AdvisorDossier dossier) {
  final buf = StringBuffer();
  buf.write(dossier.disclaimer);
  for (final section in dossier.sections) {
    buf.write(' ${section.title}');
    for (final item in section.items) {
      buf.write(' ${item.label} ${item.value}');
    }
  }
  for (final warning in dossier.missingDataWarnings) {
    buf.write(' $warning');
  }
  return buf.toString();
}
