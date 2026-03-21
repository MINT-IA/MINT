/// Dossier Preparation Service — Sprint S65 (Expert Tier).
///
/// Generates a structured, privacy-safe dossier from the user's profile
/// for use in a human-specialist ("spécialiste") consultation.
///
/// PRIVACY RULES (NON-NEGOTIABLE):
/// - NEVER includes exact salary, IBAN, SSN, employer name, or exact amounts.
/// - All financial figures use RANGES or CATEGORIES (e.g. "100-150k CHF").
/// - [isEstimated] flag marks inferred values so the specialist knows to verify.
///
/// COMPLIANCE:
/// - Disclaimer always present on every dossier (LSFin art. 3).
/// - Term "conseiller" is BANNED — always "spécialiste".
/// - No-Advice: MINT prepares the user; the specialist gives advice.
///
/// Outil éducatif — ne constitue pas un conseil financier (LSFin art. 3).
library;

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/expert/advisor_specialization.dart';

// ════════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════════

/// A single data point in a dossier section.
///
/// [isEstimated] is true when the value was inferred by MINT,
/// not explicitly declared by the user (the specialist should verify it).
class DossierItem {
  /// Human-readable label (i18n resolved).
  final String label;

  /// Formatted value — always a range/category, NEVER an exact amount.
  final String value;

  /// True if the value is an estimate (not user-declared).
  final bool isEstimated;

  const DossierItem({
    required this.label,
    required this.value,
    this.isEstimated = false,
  });
}

/// A thematic section in the advisor dossier.
class DossierSection {
  /// Section title (i18n resolved).
  final String title;

  /// Ordered list of data points in this section.
  final List<DossierItem> items;

  const DossierSection({required this.title, required this.items});
}

/// Structured, privacy-safe advisor dossier.
///
/// Contains NO PII — only financial aggregates expressed as ranges.
/// [missingDataWarnings] lists ARB keys for data that was absent from the
/// profile (the user should bring those details to the consultation).
class AdvisorDossier {
  /// Which specialization this dossier was prepared for.
  final AdvisorSpecialization specialization;

  /// Ordered thematic sections.
  final List<DossierSection> sections;

  /// Profile completeness ratio (0.0–1.0).
  ///
  /// Computed as filled-fields / total-relevant-fields for this specialization.
  final double profileCompleteness;

  /// ARB keys for missing data warnings (resolved by the UI layer).
  ///
  /// The list is empty when [profileCompleteness] == 1.0.
  final List<String> missingDataWarnings;

  /// Educational disclaimer (always present — LSFin art. 3).
  final String disclaimer;

  const AdvisorDossier({
    required this.specialization,
    required this.sections,
    required this.profileCompleteness,
    required this.missingDataWarnings,
    required this.disclaimer,
  });
}

// ════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════

/// Prepares an [AdvisorDossier] from a [CoachProfile] for a given specialization.
///
/// All methods are static and pure — no side effects, fully testable.
/// Text is resolved via [S] (AppLocalizations) so no user-visible strings
/// are hardcoded in this service.
class DossierPreparationService {
  DossierPreparationService._();

  // ── Compliance disclaimer (always present) ──────────────────

  /// Compliance disclaimer included in every dossier output.
  ///
  /// Hardcoded because it must be consistent regardless of locale for
  /// legal purposes. The UI may additionally render the `expertDisclaimer`
  /// ARB key for the localized version.
  static const String _legalDisclaimer =
      'Ce dossier est un résumé éducatif préparé par MINT. '
      'Il ne constitue pas un conseil financier personnalisé au sens de la '
      'LSFin\u00a0art.\u00a03. Les données sont des estimations arrondies\u00a0; '
      'vérifie-les avec ton\u00a0spécialiste avant la consultation.';

  // ── Public API ───────────────────────────────────────────────

  /// Generate a structured [AdvisorDossier] for [specialization].
  ///
  /// [profile] — the user's financial profile.
  /// [specialization] — the consultation topic.
  /// [l] — AppLocalizations instance (resolved by the caller from context).
  /// [now] — injectable current date for testing (defaults to [DateTime.now]).
  ///
  /// Returns a complete [AdvisorDossier] with sections, completeness score,
  /// missing-data warnings, and disclaimer. Never throws.
  static AdvisorDossier prepare({
    required CoachProfile profile,
    required AdvisorSpecialization specialization,
    required S l,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final age = effectiveNow.year - profile.birthYear;

    final sections = _buildSections(
      profile: profile,
      specialization: specialization,
      age: age,
      l: l,
    );

    final (completeness, warnings) = _computeCompleteness(
      profile: profile,
      specialization: specialization,
    );

    return AdvisorDossier(
      specialization: specialization,
      sections: sections,
      profileCompleteness: completeness,
      missingDataWarnings: warnings,
      disclaimer: _legalDisclaimer,
    );
  }

  // ── Section builders ─────────────────────────────────────────

  static List<DossierSection> _buildSections({
    required CoachProfile profile,
    required AdvisorSpecialization specialization,
    required int age,
    required S l,
  }) {
    return switch (specialization) {
      AdvisorSpecialization.retirement =>
        _retirementSections(profile, age, l),
      AdvisorSpecialization.succession =>
        _successionSections(profile, age, l),
      AdvisorSpecialization.expatriation =>
        _expatriationSections(profile, age, l),
      AdvisorSpecialization.divorce =>
        _divorceSections(profile, age, l),
      AdvisorSpecialization.selfEmployment =>
        _selfEmploymentSections(profile, age, l),
      AdvisorSpecialization.realEstate =>
        _realEstateSections(profile, age, l),
      AdvisorSpecialization.taxOptimization =>
        _taxOptimizationSections(profile, age, l),
      AdvisorSpecialization.debtManagement =>
        _debtManagementSections(profile, age, l),
    };
  }

  // ── Retirement ───────────────────────────────────────────────

  static List<DossierSection> _retirementSections(
    CoachProfile profile,
    int age,
    S l,
  ) {
    final hasPrevoyance = profile.prevoyance.avoirLppTotal != null;
    final has3a = profile.prevoyance.totalEpargne3a > 0;
    final hasConjoint = profile.conjoint != null;

    return [
      DossierSection(
        title: l.expertDossierSectionSituation,
        items: [
          DossierItem(label: l.expertItemAge, value: '$age\u00a0ans'),
          DossierItem(
            label: l.expertItemSalaryRange,
            value: _salaryRange(profile.salaireBrutMensuel * profile.nombreDeMois),
          ),
          DossierItem(
            label: l.expertItemCoupleStatus,
            value: _civilStatusLabel(profile.etatCivil, l),
          ),
          if (hasConjoint)
            DossierItem(
              label: l.expertItemConjointAge,
              value: profile.conjoint!.birthYear != null
                  ? '${DateTime.now().year - profile.conjoint!.birthYear!}\u00a0ans'
                  : l.expertValueUnknown,
              isEstimated: profile.conjoint!.birthYear == null,
            ),
        ],
      ),
      DossierSection(
        title: l.expertDossierSectionPrevoyance,
        items: [
          DossierItem(
            label: l.expertItemLppBalance,
            value: hasPrevoyance
                ? _amountRange(profile.prevoyance.avoirLppTotal!)
                : l.expertValueUnknown,
            isEstimated: !hasPrevoyance,
          ),
          DossierItem(
            label: l.expertItem3aStatus,
            value: has3a ? l.expertValue3aActive : l.expertValue3aInactive,
            isEstimated: false,
          ),
          DossierItem(
            label: l.expertItemLppBuybackPotential,
            value: profile.prevoyance.rachatMaximum != null
                ? _amountRange(profile.prevoyance.lacuneRachatRestante)
                : l.expertValueUnknown,
            isEstimated: profile.prevoyance.rachatMaximum == null,
          ),
          DossierItem(
            label: l.expertItemAvsYears,
            value: profile.prevoyance.anneesContribuees != null
                ? '${profile.prevoyance.anneesContribuees}\u00a0ans'
                : l.expertValueUnknown,
            isEstimated: profile.prevoyance.anneesContribuees == null,
          ),
          DossierItem(
            label: l.expertItemReplacementRate,
            value: _replacementRateCategory(profile),
            isEstimated: true,
          ),
        ],
      ),
    ];
  }

  // ── Succession ───────────────────────────────────────────────

  static List<DossierSection> _successionSections(
    CoachProfile profile,
    int age,
    S l,
  ) {
    final totalPatrimoine = profile.patrimoine.totalPatrimoine;
    final hasProperty = profile.patrimoine.immobilierEffectif > 0;

    return [
      DossierSection(
        title: l.expertDossierSectionSituation,
        items: [
          DossierItem(label: l.expertItemAge, value: '$age\u00a0ans'),
          DossierItem(
            label: l.expertItemFamilyStatus,
            value: _civilStatusLabel(profile.etatCivil, l),
          ),
          DossierItem(
            label: l.expertItemChildren,
            value: profile.nombreEnfants > 0
                ? '${profile.nombreEnfants}'
                : l.expertValueNone,
          ),
        ],
      ),
      DossierSection(
        title: l.expertDossierSectionPatrimoine,
        items: [
          DossierItem(
            label: l.expertItemPatrimoineRange,
            value: _amountRange(totalPatrimoine),
            isEstimated: true,
          ),
          DossierItem(
            label: l.expertItemPropertyStatus,
            value: hasProperty ? l.expertValueOwner : l.expertValueTenant,
          ),
          if (hasProperty)
            DossierItem(
              label: l.expertItemPropertyValue,
              value: _amountRange(profile.patrimoine.immobilierEffectif),
              isEstimated: profile.patrimoine.propertyMarketValue == null,
            ),
        ],
      ),
    ];
  }

  // ── Expatriation ─────────────────────────────────────────────

  static List<DossierSection> _expatriationSections(
    CoachProfile profile,
    int age,
    S l,
  ) {
    final arrivalAge = profile.arrivalAge;
    final yearsInCh = arrivalAge != null ? (age - arrivalAge).clamp(0, 99) : null;

    return [
      DossierSection(
        title: l.expertDossierSectionSituation,
        items: [
          DossierItem(label: l.expertItemAge, value: '$age\u00a0ans'),
          DossierItem(
            label: l.expertItemNationality,
            value: profile.nationality?.isNotEmpty == true
                ? profile.nationality!
                : l.expertValueUnknown,
          ),
          DossierItem(
            label: l.expertItemArchetype,
            value: _archetypeLabel(profile.archetype, l),
          ),
          DossierItem(
            label: l.expertItemYearsInCh,
            value: yearsInCh != null ? '$yearsInCh\u00a0ans' : l.expertValueUnknown,
            isEstimated: arrivalAge == null,
          ),
          DossierItem(
            label: l.expertItemResidencePermit,
            value: profile.residencePermit?.isNotEmpty == true
                ? profile.residencePermit!
                : l.expertValueUnknown,
          ),
        ],
      ),
      DossierSection(
        title: l.expertDossierSectionPrevoyance,
        items: [
          DossierItem(
            label: l.expertItemAvsStatus,
            value: profile.prevoyance.anneesContribuees != null
                ? '${profile.prevoyance.anneesContribuees}\u00a0ans cotisés'
                : l.expertValueUnknown,
            isEstimated: profile.prevoyance.anneesContribuees == null,
          ),
          DossierItem(
            label: l.expertItemAvsGaps,
            value: profile.prevoyance.lacunesAVS != null
                ? '${profile.prevoyance.lacunesAVS}\u00a0an(s)'
                : l.expertValueUnknown,
            isEstimated: profile.prevoyance.lacunesAVS == null,
          ),
        ],
      ),
    ];
  }

  // ── Divorce ──────────────────────────────────────────────────

  static List<DossierSection> _divorceSections(
    CoachProfile profile,
    int age,
    S l,
  ) {
    final hasConjoint = profile.conjoint != null;
    final hasProperty = profile.patrimoine.immobilierEffectif > 0;

    return [
      DossierSection(
        title: l.expertDossierSectionSituation,
        items: [
          DossierItem(label: l.expertItemAge, value: '$age\u00a0ans'),
          DossierItem(
            label: l.expertItemCivilStatus,
            value: _civilStatusLabel(profile.etatCivil, l),
          ),
          DossierItem(
            label: l.expertItemChildren,
            value: profile.nombreEnfants > 0
                ? '${profile.nombreEnfants}'
                : l.expertValueNone,
          ),
        ],
      ),
      DossierSection(
        title: l.expertDossierSectionPrevoyance,
        items: [
          DossierItem(
            label: l.expertItemLppBalance,
            value: profile.prevoyance.avoirLppTotal != null
                ? _amountRange(profile.prevoyance.avoirLppTotal!)
                : l.expertValueUnknown,
            isEstimated: profile.prevoyance.avoirLppTotal == null,
          ),
          if (hasConjoint)
            DossierItem(
              label: l.expertItemConjointLpp,
              value: profile.conjoint?.prevoyance?.avoirLppTotal != null
                  ? _amountRange(profile.conjoint!.prevoyance!.avoirLppTotal!)
                  : l.expertValueUnknown,
              isEstimated: profile.conjoint?.prevoyance?.avoirLppTotal == null,
            ),
          DossierItem(
            label: l.expertItemPropertyStatus,
            value: hasProperty ? l.expertValueOwner : l.expertValueTenant,
          ),
        ],
      ),
    ];
  }

  // ── Self-Employment ──────────────────────────────────────────

  static List<DossierSection> _selfEmploymentSections(
    CoachProfile profile,
    int age,
    S l,
  ) {
    final hasLpp = profile.prevoyance.avoirLppTotal != null &&
        profile.prevoyance.avoirLppTotal! > 0;
    final has3a = profile.prevoyance.totalEpargne3a > 0;

    return [
      DossierSection(
        title: l.expertDossierSectionSituation,
        items: [
          DossierItem(label: l.expertItemAge, value: '$age\u00a0ans'),
          DossierItem(
            label: l.expertItemEmploymentStatus,
            value: _employmentStatusLabel(profile.employmentStatus, l),
          ),
          DossierItem(
            label: l.expertItemSalaryRange,
            value: _salaryRange(profile.salaireBrutMensuel * profile.nombreDeMois),
          ),
          DossierItem(
            label: l.expertItemArchetype,
            value: _archetypeLabel(profile.archetype, l),
          ),
        ],
      ),
      DossierSection(
        title: l.expertDossierSectionPrevoyance,
        items: [
          DossierItem(
            label: l.expertItemLppCoverage,
            value: hasLpp ? l.expertValueLppYes : l.expertValueLppNo,
          ),
          DossierItem(
            label: l.expertItem3aStatus,
            value: has3a ? l.expertValue3aActive : l.expertValue3aInactive,
          ),
          DossierItem(
            label: l.expertItem3aBalance,
            value: has3a
                ? _amountRange(profile.prevoyance.totalEpargne3a)
                : l.expertValueNone,
            isEstimated: false,
          ),
        ],
      ),
    ];
  }

  // ── Real Estate ──────────────────────────────────────────────

  static List<DossierSection> _realEstateSections(
    CoachProfile profile,
    int age,
    S l,
  ) {
    final hasProperty = profile.patrimoine.immobilierEffectif > 0;
    final annualRevenu = profile.salaireBrutMensuel * profile.nombreDeMois;

    return [
      DossierSection(
        title: l.expertDossierSectionSituation,
        items: [
          DossierItem(label: l.expertItemAge, value: '$age\u00a0ans'),
          DossierItem(
            label: l.expertItemSalaryRange,
            value: _salaryRange(annualRevenu),
          ),
          DossierItem(
            label: l.expertItemCanton,
            value: profile.canton.isNotEmpty ? profile.canton : l.expertValueUnknown,
          ),
          DossierItem(
            label: l.expertItemCurrentHousing,
            value: hasProperty ? l.expertValueOwner : l.expertValueTenant,
          ),
        ],
      ),
      DossierSection(
        title: l.expertDossierSectionFinancement,
        items: [
          DossierItem(
            label: l.expertItemEquityEstimate,
            value: _amountRange(
              profile.patrimoine.epargneLiquide + profile.patrimoine.investissements,
            ),
            isEstimated: true,
          ),
          DossierItem(
            label: l.expertItemLppEpl,
            value: profile.prevoyance.avoirLppTotal != null
                ? l.expertValueLppEplPossible
                : l.expertValueUnknown,
            isEstimated: profile.prevoyance.avoirLppTotal == null,
          ),
          if (hasProperty)
            DossierItem(
              label: l.expertItemMortgageBalance,
              value: profile.patrimoine.mortgageBalance != null
                  ? _amountRange(profile.patrimoine.mortgageBalance!)
                  : l.expertValueUnknown,
              isEstimated: profile.patrimoine.mortgageBalance == null,
            ),
        ],
      ),
    ];
  }

  // ── Tax Optimization ─────────────────────────────────────────

  static List<DossierSection> _taxOptimizationSections(
    CoachProfile profile,
    int age,
    S l,
  ) {
    final has3a = profile.prevoyance.totalEpargne3a > 0;
    final hasLppBuyback = (profile.prevoyance.lacuneRachatRestante) > 0;

    return [
      DossierSection(
        title: l.expertDossierSectionSituation,
        items: [
          DossierItem(label: l.expertItemAge, value: '$age\u00a0ans'),
          DossierItem(
            label: l.expertItemCanton,
            value: profile.canton.isNotEmpty ? profile.canton : l.expertValueUnknown,
          ),
          DossierItem(
            label: l.expertItemSalaryRange,
            value: _salaryRange(profile.salaireBrutMensuel * profile.nombreDeMois),
          ),
          DossierItem(
            label: l.expertItemArchetype,
            value: _archetypeLabel(profile.archetype, l),
          ),
        ],
      ),
      DossierSection(
        title: l.expertDossierSectionDeductions,
        items: [
          DossierItem(
            label: l.expertItem3aStatus,
            value: has3a ? l.expertValue3aActive : l.expertValue3aInactive,
          ),
          DossierItem(
            label: l.expertItem3aBalance,
            value: has3a
                ? _amountRange(profile.prevoyance.totalEpargne3a)
                : l.expertValueNone,
          ),
          DossierItem(
            label: l.expertItemLppBuybackPotential,
            value: hasLppBuyback
                ? _amountRange(profile.prevoyance.lacuneRachatRestante)
                : l.expertValueNone,
            isEstimated: profile.prevoyance.rachatMaximum == null,
          ),
        ],
      ),
    ];
  }

  // ── Debt Management ──────────────────────────────────────────

  static List<DossierSection> _debtManagementSections(
    CoachProfile profile,
    int age,
    S l,
  ) {
    final totalDettes = profile.dettes.totalDettes;
    final annualRevenu = profile.salaireBrutMensuel * profile.nombreDeMois;
    final debtRatio = annualRevenu > 0 ? totalDettes / annualRevenu : 0.0;
    final totalMensualites = profile.dettes.totalMensualite;
    final mensuelRevenu = profile.salaireBrutMensuel;
    final chargesRatio = mensuelRevenu > 0
        ? totalMensualites / mensuelRevenu
        : 0.0;

    return [
      DossierSection(
        title: l.expertDossierSectionSituation,
        items: [
          DossierItem(label: l.expertItemAge, value: '$age\u00a0ans'),
          DossierItem(
            label: l.expertItemSalaryRange,
            value: _salaryRange(annualRevenu),
          ),
          DossierItem(
            label: l.expertItemDebtRatio,
            value: _debtRatioCategory(debtRatio, l),
            isEstimated: totalDettes == 0,
          ),
        ],
      ),
      DossierSection(
        title: l.expertDossierSectionBudget,
        items: [
          DossierItem(
            label: l.expertItemChargesVsIncome,
            value: _chargesCategory(chargesRatio, l),
            isEstimated: totalMensualites == 0,
          ),
          DossierItem(
            label: l.expertItemDebtType,
            value: _debtTypeDescription(profile, l),
          ),
        ],
      ),
    ];
  }

  // ── Completeness computation ─────────────────────────────────

  /// Compute profile completeness (0.0–1.0) and missing data warning keys
  /// for the given [specialization].
  static (double completeness, List<String> warnings) _computeCompleteness({
    required CoachProfile profile,
    required AdvisorSpecialization specialization,
  }) {
    final missing = <String>[];
    int total = 0;
    int filled = 0;

    void check(bool isPresent, String warningKey) {
      total++;
      if (isPresent) {
        filled++;
      } else {
        missing.add(warningKey);
      }
    }

    switch (specialization) {
      case AdvisorSpecialization.retirement:
        check(profile.prevoyance.avoirLppTotal != null, 'expertMissingLppBalance');
        check(profile.prevoyance.anneesContribuees != null, 'expertMissingAvsYears');
        check(profile.prevoyance.rachatMaximum != null, 'expertMissingLppBuyback');
        check(profile.prevoyance.totalEpargne3a > 0, 'expertMissing3a');
        check(profile.conjoint != null || profile.etatCivil == CoachCivilStatus.celibataire,
            'expertMissingConjoint');

      case AdvisorSpecialization.succession:
        check(profile.patrimoine.totalPatrimoine > 0, 'expertMissingPatrimoine');
        check(profile.patrimoine.immobilierEffectif > 0 ||
            profile.housingStatus != null, 'expertMissingHousing');
        check(profile.nombreEnfants >= 0, 'expertMissingChildren');

      case AdvisorSpecialization.expatriation:
        check(profile.nationality?.isNotEmpty == true, 'expertMissingNationality');
        check(profile.arrivalAge != null, 'expertMissingArrivalAge');
        check(profile.residencePermit?.isNotEmpty == true, 'expertMissingPermit');
        check(profile.prevoyance.anneesContribuees != null, 'expertMissingAvsYears');

      case AdvisorSpecialization.divorce:
        check(profile.prevoyance.avoirLppTotal != null, 'expertMissingLppBalance');
        check(profile.conjoint?.prevoyance?.avoirLppTotal != null,
            'expertMissingConjointLpp');
        check(profile.patrimoine.immobilierEffectif > 0 ||
            profile.housingStatus != null, 'expertMissingHousing');

      case AdvisorSpecialization.selfEmployment:
        check(profile.employmentStatus == 'independant', 'expertMissingIndependantStatus');
        check(profile.prevoyance.avoirLppTotal != null || true,
            'expertMissingLppCoverage'); // always filled (yes/no)
        check(profile.prevoyance.totalEpargne3a >= 0, 'expertMissing3a');

      case AdvisorSpecialization.realEstate:
        check(profile.canton.isNotEmpty, 'expertMissingCanton');
        check(profile.patrimoine.epargneLiquide > 0 ||
            profile.patrimoine.investissements > 0, 'expertMissingEquity');
        check(profile.prevoyance.avoirLppTotal != null, 'expertMissingLppBalance');
        check(profile.housingStatus != null, 'expertMissingHousingStatus');

      case AdvisorSpecialization.taxOptimization:
        check(profile.canton.isNotEmpty, 'expertMissingCanton');
        check(profile.prevoyance.rachatMaximum != null, 'expertMissingLppBuyback');
        check(profile.prevoyance.totalEpargne3a >= 0, 'expertMissing3a');

      case AdvisorSpecialization.debtManagement:
        check(profile.dettes.totalDettes > 0, 'expertMissingDebtDetail');
        check(profile.dettes.totalMensualite > 0, 'expertMissingMensualites');
    }

    final completeness = total > 0 ? filled / total : 1.0;
    return (completeness, missing);
  }

  // ── Private helpers ───────────────────────────────────────────

  /// Convert an annual salary to a CHF bracket label.
  ///
  /// NEVER exposes the exact figure — only a 50k-wide bracket.
  static String _salaryRange(double annualSalary) {
    if (annualSalary <= 0) return 'CHF\u00a0–';
    if (annualSalary < 50000) return 'CHF\u00a0<\u00a050k';
    if (annualSalary < 100000) return 'CHF\u00a050–100k';
    if (annualSalary < 150000) return 'CHF\u00a0100–150k';
    if (annualSalary < 200000) return 'CHF\u00a0150–200k';
    if (annualSalary < 300000) return 'CHF\u00a0200–300k';
    if (annualSalary < 500000) return 'CHF\u00a0300–500k';
    return 'CHF\u00a0>\u00a0500k';
  }

  /// Convert an amount to a CHF range label.
  ///
  /// Used for patrimoine, LPP balance, and buyback potential.
  static String _amountRange(double amount) {
    if (amount <= 0) return 'CHF\u00a00';
    if (amount < 25000) return 'CHF\u00a0<\u00a025k';
    if (amount < 50000) return 'CHF\u00a025–50k';
    if (amount < 100000) return 'CHF\u00a050–100k';
    if (amount < 200000) return 'CHF\u00a0100–200k';
    if (amount < 350000) return 'CHF\u00a0200–350k';
    if (amount < 500000) return 'CHF\u00a0350–500k';
    if (amount < 1000000) return 'CHF\u00a0500k–1M';
    return 'CHF\u00a0>\u00a01M';
  }

  /// Human-readable civil status label.
  static String _civilStatusLabel(CoachCivilStatus status, S l) {
    return switch (status) {
      CoachCivilStatus.celibataire => l.expertValueSingle,
      CoachCivilStatus.marie => l.expertValueMarried,
      CoachCivilStatus.divorce => l.expertValueDivorced,
      CoachCivilStatus.veuf => l.expertValueWidowed,
      CoachCivilStatus.concubinage => l.expertValueConcubinage,
    };
  }

  /// Human-readable archetype label.
  static String _archetypeLabel(FinancialArchetype archetype, S l) {
    return switch (archetype) {
      FinancialArchetype.swissNative => l.expertArchetypeSwissNative,
      FinancialArchetype.expatEu => l.expertArchetypeExpatEu,
      FinancialArchetype.expatNonEu => l.expertArchetypeExpatNonEu,
      FinancialArchetype.expatUs => l.expertArchetypeExpatUs,
      FinancialArchetype.independentWithLpp => l.expertArchetypeIndepWithLpp,
      FinancialArchetype.independentNoLpp => l.expertArchetypeIndepNoLpp,
      FinancialArchetype.crossBorder => l.expertArchetypeCrossBorder,
      FinancialArchetype.returningSwiss => l.expertArchetypeReturningSwiss,
    };
  }

  /// Human-readable employment status label.
  static String _employmentStatusLabel(String status, S l) {
    return switch (status) {
      'salarie' => l.expertValueSalarie,
      'independant' => l.expertValueIndependant,
      'chomage' => l.expertValueChomage,
      'retraite' => l.expertValueRetraite,
      _ => status,
    };
  }

  /// Replacement rate category (never an exact percentage).
  static String _replacementRateCategory(CoachProfile profile) {
    final annualRevenu = profile.salaireBrutMensuel * profile.nombreDeMois;
    if (annualRevenu <= 0) return 'N/A';
    // LPP estimate: avoir / 1.5 years to go factor (rough band)
    final lppAnnual = (profile.prevoyance.avoirLppTotal ?? 0) *
        (profile.prevoyance.tauxConversion);
    final avsAnnual = (profile.prevoyance.renteAVSEstimeeMensuelle ?? 2000) * 12;
    final totalAnnual = lppAnnual + avsAnnual;
    final rate = totalAnnual / annualRevenu;
    if (rate < 0.50) return '< 50\u00a0%';
    if (rate < 0.65) return '50–65\u00a0%';
    if (rate < 0.80) return '65–80\u00a0%';
    return '> 80\u00a0%';
  }

  /// Debt ratio category.
  static String _debtRatioCategory(double ratio, S l) {
    if (ratio <= 0) return l.expertValueDebtNone;
    if (ratio < 0.5) return l.expertValueDebtLow;
    if (ratio < 1.0) return l.expertValueDebtMedium;
    return l.expertValueDebtHigh;
  }

  /// Monthly charges vs income category.
  static String _chargesCategory(double ratio, S l) {
    if (ratio <= 0) return l.expertValueChargesNone;
    if (ratio < 0.25) return '< 25\u00a0%\u00a0du revenu';
    if (ratio < 0.33) return '25–33\u00a0%\u00a0du revenu';
    if (ratio < 0.50) return '33–50\u00a0%\u00a0du revenu';
    return '> 50\u00a0%\u00a0du revenu';
  }

  /// Describe which debt types are present (no amounts).
  static String _debtTypeDescription(CoachProfile profile, S l) {
    final parts = <String>[];
    if ((profile.dettes.creditConsommation ?? 0) > 0) parts.add(l.expertDebtTypeConso);
    if ((profile.dettes.leasing ?? 0) > 0) parts.add(l.expertDebtTypeLeasing);
    if ((profile.dettes.hypotheque ?? 0) > 0) parts.add(l.expertDebtTypeHypo);
    if ((profile.dettes.autresDettes ?? 0) > 0) parts.add(l.expertDebtTypeAutre);
    return parts.isEmpty ? l.expertValueNone : parts.join(', ');
  }
}
