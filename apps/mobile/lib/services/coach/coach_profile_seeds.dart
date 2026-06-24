/// CoachProfileSeeds — Phase 80 (v2.11).
///
/// Hydrates a deterministic [CoachContext]-like seed when the
/// `MINT_E2E_ARCHETYPE` dart-define is set at build time (walker /
/// widget-test runs). Closes phantom contract C1: the v2.10 audit
/// flagged this primitive as declared-but-never-called.
///
/// Pinned runtime seeds for walker / widget-test archetypes. New seeds require
/// a coordinated bump of the walker fixture set + this file.
///
/// SECURITY (ECLW-04 spirit): the dart-define is a build-time constant.
/// Release builds get an empty string and [activeSeed] returns null.
/// The `kReleaseMode` short-circuit in [forcedArchetypeSlug] keeps the
/// codepath dead in production binaries.
///
/// References:
///   - REQUIREMENTS.md ECLW-02
///   - decisions/2026-05-04-post-handoff2-sweep-panel.md
library;

import 'package:flutter/foundation.dart';

import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

/// A pinned, named seed for a single walker archetype.
class CoachProfileSeed {
  /// Archetype slug exchanged with the backend / walker fixtures.
  final String slug;

  /// First name baked into the seed (for greeting prompts).
  final String firstName;

  /// Age baked into the seed.
  final int age;

  /// Canton baked into the seed.
  final String canton;

  /// Archetype tag forwarded to the backend (different from [slug] only
  /// when an archetype maps to more than one archetype tag — currently
  /// 1:1).
  final String archetype;

  /// Gross monthly income in CHF (legacy seed name kept for compatibility).
  final double grossMonthlySalary;

  /// Employment status written to wizard answers.
  final String employmentStatus;

  /// Explicit monthly net income in CHF. When absent, the seed keeps the
  /// historical gross-to-net estimate used by older walker fixtures.
  final double? netMonthlyIncome;

  /// Explicit annual professional net income for self-employed/no-LPP
  /// calculation paths. This is distinct from [netMonthlyIncome], which feeds
  /// household cashflow and budget surfaces.
  final double? independentNetProfessionalIncomeAnnual;

  /// Explicit LPP affiliation for persona-flow fixtures.
  final bool? hasPensionFund;

  /// Explicit annual 3a contribution in CHF.
  final double? annual3aContribution;

  /// Explicit 3a balance in CHF.
  final double? threeABalance;

  /// Explicit number of 3a accounts.
  final int? threeAAccountsCount;

  /// Explicit civil status answer (`single`, `married`, ...).
  final String? civilStatus;

  /// Explicit housing status answer (`renter`, `owner`, ...).
  final String? housingStatus;

  /// Explicit monthly housing cost in CHF.
  final double? housingCostMonthly;

  /// Explicit monthly LAMal premium in CHF.
  final double? lamalPremiumMonthly;

  /// Explicit monthly tax provision in CHF.
  final double? taxProvisionMonthly;

  /// Explicit monthly fixed costs beyond housing/LAMal in CHF.
  final double? otherFixedCostsMonthly;

  /// Explicit planned monthly savings in CHF.
  final double? savingsMonthly;

  /// Explicit liquid cash/savings in CHF.
  final double? cashTotal;

  /// Explicit investments total in CHF.
  final double? investmentsTotal;

  /// Explicit LPP total balance in CHF.
  final double? lppBalanceTotal;

  /// Explicit LPP mandatory balance in CHF.
  final double? lppMandatoryBalance;

  /// Explicit LPP supplementary balance in CHF.
  final double? lppSupplementaryBalance;

  /// Explicit LPP insured salary in CHF.
  final double? lppInsuredSalary;

  /// Explicit LPP buyback room in CHF.
  final double? lppBuybackMax;

  /// Source marker for explicit LPP fields. Use `document_scan` when the seed
  /// represents certificate-like data so the spine treats the figures as known.
  final String? lppSource;

  /// FATCA short-circuit signal (sub-phase 01.5 Wave 02 plan 06).
  ///
  /// When `true`, the hydrated [CoachProfile.archetype] getter returns
  /// `FinancialArchetype.expatUs` regardless of nationality (per the
  /// FATCA short-circuit added in Wave 02 plan 01). When `null`, the seed
  /// carries no FATCA signal — matches the v2.10 swiss_native seeds.
  ///
  /// Optional with default `null` so the 4 v2.10 seeds are unmodified.
  final bool? usTaxPerson;

  /// ISO 2-letter nationality (e.g. `'US'`, `'CH'`, `'FR'`).
  ///
  /// Sub-phase 01.5 Wave 02 plan 06 — supplies the secondary
  /// archetype-discriminating signal alongside [usTaxPerson] for the new
  /// `julien_expat_us` seed. Optional with default `null` so the 4 v2.10
  /// seeds are unmodified.
  final String? nationality;

  const CoachProfileSeed({
    required this.slug,
    required this.firstName,
    required this.age,
    required this.canton,
    required this.archetype,
    required this.grossMonthlySalary,
    this.employmentStatus = 'employed',
    this.netMonthlyIncome,
    this.independentNetProfessionalIncomeAnnual,
    this.hasPensionFund,
    this.annual3aContribution,
    this.threeABalance,
    this.threeAAccountsCount,
    this.civilStatus,
    this.housingStatus,
    this.housingCostMonthly,
    this.lamalPremiumMonthly,
    this.taxProvisionMonthly,
    this.otherFixedCostsMonthly,
    this.savingsMonthly,
    this.cashTotal,
    this.investmentsTotal,
    this.lppBalanceTotal,
    this.lppMandatoryBalance,
    this.lppSupplementaryBalance,
    this.lppInsuredSalary,
    this.lppBuybackMax,
    this.lppSource,
    this.usTaxPerson,
    this.nationality,
  });

  /// Build a [CoachContext] hydrated from this seed.
  ///
  /// Caller may pass [overrides] to tweak a single field without rebuilding
  /// the seed registry — typically used by widget tests to vary one value.
  CoachContext toCoachContext({
    String? primaryFocus,
  }) {
    return CoachContext(
      firstName: firstName,
      archetype: archetype,
      age: age,
      canton: canton,
      primaryFocus: primaryFocus ?? '',
      knownValues: <String, double>{
        'gross_monthly_salary': grossMonthlySalary,
      },
    );
  }

  /// Build enough wizard answers to hydrate [CoachProfileProvider] during
  /// simulator runs pinned with `MINT_E2E_ARCHETYPE`.
  ///
  /// This is intentionally a debug/e2e bridge: production persistence stays
  /// owned by ReportPersistenceService and user-entered wizard answers.
  Map<String, dynamic> toWizardAnswers({DateTime? now}) {
    final year = (now ?? DateTime.now()).year;
    final birthYear = year - age;
    // Net mensuel via la source canonique NetIncomeBreakdown (canton + âge
    // aware) — plus de ratio plat 0.78 (base nette unique app-wide, matrice
    // §2 « Marge libre »). Le canton du seed est utilisé ; à défaut, ZH par
    // défaut (estimation pour les fixtures e2e sans canton fiable).
    final monthlyNetIncome = netMonthlyIncome ??
        NetIncomeBreakdown.compute(
          grossSalary: grossMonthlySalary * 12,
          canton: canton.isNotEmpty ? canton : 'ZH',
          age: age,
        ).monthlyNetPayslip.roundToDouble();
    final hasLpp = hasPensionFund ?? usTaxPerson != true;
    final annual3a = annual3aContribution ?? (hasLpp ? 7056.0 : 0.0);
    final threeAAccounts = threeAAccountsCount ?? (hasLpp ? 1 : 0);
    final has3a = annual3a > 0 ||
        threeAAccounts > 0 ||
        (threeABalance != null && threeABalance! > 0);
    final savingsAllocation = <String>[
      if (annual3a > 0) '3a',
      'investissement',
      'epargne_libre',
    ];
    final lppHasExplicitFacts = lppBalanceTotal != null ||
        lppMandatoryBalance != null ||
        lppSupplementaryBalance != null ||
        lppInsuredSalary != null ||
        lppBuybackMax != null;

    return <String, dynamic>{
      'q_firstname': firstName,
      'q_birth_year': birthYear,
      'q_canton': canton,
      if (civilStatus != null) 'q_civil_status': civilStatus,
      'q_pay_frequency': 'monthly',
      'q_gross_salary_annual': grossMonthlySalary * 12,
      'q_net_income_period_chf': monthlyNetIncome,
      if (independentNetProfessionalIncomeAnnual != null)
        'q_self_employed_net_income_annual_chf':
            independentNetProfessionalIncomeAnnual,
      'q_employment_status': employmentStatus,
      'q_household_type': 'single',
      if (housingStatus != null) 'q_housing_status': housingStatus,
      'q_housing_cost_period_chf':
          housingCostMonthly ?? (monthlyNetIncome * 0.26).roundToDouble(),
      'q_tax_provision_monthly_chf':
          taxProvisionMonthly ?? (grossMonthlySalary * 0.15).roundToDouble(),
      'q_lamal_premium_monthly_chf': lamalPremiumMonthly ?? 420.0,
      'q_other_fixed_costs_monthly_chf': otherFixedCostsMonthly ?? 850.0,
      'q_savings_monthly':
          savingsMonthly ?? (monthlyNetIncome * 0.16).roundToDouble(),
      'q_savings_allocation': savingsAllocation,
      'q_has_pension_fund': hasLpp,
      'q_has_3a': has3a,
      'q_3a_annual_contribution': annual3a,
      if (threeABalance != null) 'q_3a_total': threeABalance,
      'q_3a_accounts_count': threeAAccounts,
      'q_has_investments': true,
      'q_cash_total': cashTotal ?? monthlyNetIncome * 3,
      'q_investments_total': investmentsTotal ?? monthlyNetIncome * 6,
      if (lppBalanceTotal != null) '_coach_avoir_lpp': lppBalanceTotal,
      if (lppMandatoryBalance != null)
        '_coach_avoir_lpp_oblig': lppMandatoryBalance,
      if (lppSupplementaryBalance != null)
        '_coach_avoir_lpp_suroblig': lppSupplementaryBalance,
      if (lppInsuredSalary != null) '_coach_salaire_assure': lppInsuredSalary,
      if (lppBuybackMax != null) '_coach_rachat_maximum': lppBuybackMax,
      if (lppHasExplicitFacts) '_coach_lpp_source': lppSource ?? 'manual_seed',
      'q_avs_lacunes_status': 'unknown',
      'q_has_consumer_debt': false,
      'q_nationality':
          nationality ?? (archetype == 'swiss_native' ? 'CH' : null),
      if (usTaxPerson != null) 'q_us_tax_person': usTaxPerson,
    };
  }
}

/// Static registry of walker/runtime archetype seeds.
class CoachProfileSeeds {
  CoachProfileSeeds._();

  /// Build-time dart-define that pins the seed slug.
  ///
  /// Walker / widget-test runs pass `--dart-define=MINT_E2E_ARCHETYPE=<slug>`.
  /// Production builds get the empty string and [activeSeed] returns null.
  static const String _archetypeDartDefine =
      String.fromEnvironment('MINT_E2E_ARCHETYPE');

  /// All seeds keyed by slug. Order is deterministic for tests / walker.
  static const Map<String, CoachProfileSeed> registry =
      <String, CoachProfileSeed>{
    'julien_swiss': CoachProfileSeed(
      slug: 'julien_swiss',
      firstName: 'Julien',
      age: 36,
      canton: 'VD',
      archetype: 'swiss_native',
      grossMonthlySalary: 9500,
    ),
    'couple_acheteurs_lausanne': CoachProfileSeed(
      slug: 'couple_acheteurs_lausanne',
      firstName: 'Camille',
      age: 33,
      canton: 'VD',
      archetype: 'swiss_native',
      grossMonthlySalary: 8200,
    ),
    'jeune_diplome_zurich': CoachProfileSeed(
      slug: 'jeune_diplome_zurich',
      firstName: 'Léa',
      age: 25,
      canton: 'ZH',
      archetype: 'swiss_native',
      grossMonthlySalary: 6500,
    ),
    'cadre_40_55_lpp_rachat': CoachProfileSeed(
      slug: 'cadre_40_55_lpp_rachat',
      firstName: 'Marc',
      age: 48,
      canton: 'GE',
      archetype: 'swiss_native',
      grossMonthlySalary: 13500,
    ),
    // Canonical rich runtime persona for account/onboarding/profile gates.
    // This is intentionally salaried, Swiss-resident, and materially LPP-ready
    // so simulator proofs exercise the real Mint surfaces instead of a thin
    // fallback profile or estimated pension values.
    'cadre_salarie_lpp_suisse_ready': CoachProfileSeed(
      slug: 'cadre_salarie_lpp_suisse_ready',
      firstName: 'Alex',
      age: 33,
      canton: 'VS',
      archetype: 'swiss_native',
      grossMonthlySalary: 9600,
      employmentStatus: 'employed',
      netMonthlyIncome: 7500,
      hasPensionFund: true,
      annual3aContribution: 7056,
      threeABalance: 22000,
      threeAAccountsCount: 2,
      civilStatus: 'single',
      housingStatus: 'renter',
      housingCostMonthly: 1850,
      lamalPremiumMonthly: 430,
      taxProvisionMonthly: 1450,
      otherFixedCostsMonthly: 1250,
      savingsMonthly: 1200,
      cashTotal: 30000,
      investmentsTotal: 45000,
      lppBalanceTotal: 94000,
      lppMandatoryBalance: 76000,
      lppSupplementaryBalance: 18000,
      lppInsuredSalary: 86000,
      lppBuybackMax: 42000,
      lppSource: 'document_scan',
      nationality: 'CH',
    ),
    // Sub-phase 01.5 Wave 02 plan 06 — walker seed for archetype HARD GATE
    // testing. Hydrates a profile that resolves to FinancialArchetype.expatUs
    // via BOTH the FATCA short-circuit (usTaxPerson:true) AND nationality:'US'
    // so the gate fires at coach_chat_screen.dart and the Wave 03 Maestro
    // flow can assert /waitlist is reached. Resolved by the walker through
    // `--dart-define=MINT_E2E_ARCHETYPE=expat_us` via [byArchetype] (the
    // archetype slug → seed name contract — Codex C3 MEDIUM).
    'julien_expat_us': CoachProfileSeed(
      slug: 'julien_expat_us',
      firstName: 'Julien',
      age: 38,
      canton: 'GE',
      archetype: 'expat_us',
      grossMonthlySalary: 11500,
      usTaxPerson: true,
      nationality: 'US',
    ),
    // SALVAGE-00 SC-4 device persona: the device-layer twin of the SC-2
    // cross-path unit fixture (budget_living_engine_test.dart). A swiss_native
    // seed: toWizardAnswers sets hasLpp => q_3a_annual_contribution > 0, so the
    // hydrated profile has total3aMensuel > 0 and a positive Futur (savings) —
    // the budget hero renders Futur > 0. Load-bearing input for the SC-4 device
    // gate (Plan 04); lands pre-merge on #681 with the gate fixes.
    // kReleaseMode-guarded via forcedArchetypeSlug (no production leak).
    'cadre_3a_contributing': CoachProfileSeed(
      slug: 'cadre_3a_contributing',
      firstName: 'Sophie',
      age: 42,
      canton: 'VD',
      archetype: 'swiss_native',
      grossMonthlySalary: 9000,
    ),
    // CJT-061 follow-up runtime fixture: independent without LPP and with a
    // real monthly income + non-zero 3a behavior. This prevents Row 23 runtime
    // proofs from falling back to salaried/LPP-affiliated swiss_native seeds.
    'independent_no_lpp_income_reality': CoachProfileSeed(
      slug: 'independent_no_lpp_income_reality',
      firstName: 'Nadia',
      age: 39,
      canton: 'VD',
      archetype: 'independent_no_lpp',
      grossMonthlySalary: 9000,
      employmentStatus: 'independant',
      netMonthlyIncome: 7200,
      independentNetProfessionalIncomeAnnual: 86400,
      hasPensionFund: false,
      annual3aContribution: 6000,
      threeAAccountsCount: 1,
      nationality: 'CH',
    ),
  };

  /// Return the seed slug forced via `MINT_E2E_ARCHETYPE`, or null when:
  ///   - we are in a release build ([kReleaseMode] = true), OR
  ///   - the dart-define is empty / unknown.
  ///
  /// The dart-define accepts both historical seed slugs (`julien_swiss`) and
  /// archetype slugs (`swiss_native`, `expat_us`) used by Maestro/walker.
  ///
  /// Release-build short-circuit keeps the codepath dead in production
  /// (defense-in-depth alongside the dart-define being absent on prod).
  static String? forcedArchetypeSlug() {
    if (kReleaseMode) return null;
    final slug = _archetypeDartDefine.trim();
    if (slug.isEmpty) return null;
    if (registry.containsKey(slug)) return slug;
    return byArchetype(slug)?.slug;
  }

  /// Active seed for the current build, or null when not pinned.
  ///
  /// In release builds this is ALWAYS null regardless of dart-define value
  /// — defense-in-depth against an accidental flag leak in App Store IPAs.
  static CoachProfileSeed? get activeSeed {
    final slug = forcedArchetypeSlug();
    if (slug == null) return null;
    return registry[slug];
  }

  /// Look up a seed by slug. Returns null when unknown — never throws,
  /// so callers can safely degrade.
  static CoachProfileSeed? bySlug(String? slug) {
    if (slug == null || slug.isEmpty) return null;
    return registry[slug];
  }

  /// Resolve an archetype slug (e.g. `'expat_us'`, `'swiss_native'`) to its
  /// canonical seed profile. The walker's
  /// `--dart-define=MINT_E2E_ARCHETYPE=<slug>` carries the archetype slug,
  /// NOT the seed name — this helper is the explicit contract between the
  /// two.
  ///
  /// Returns `null` if no seed maps to the slug. Callers (walker / Maestro
  /// flow / test) MUST handle null explicitly — there is NO default seed.
  ///
  /// Sub-phase 01.5 Wave 02 plan 06 — Codex C3 MEDIUM fix
  /// (REVIEWS.md 2026-05-22). Prevents silent test-infra failures where a
  /// typo in the archetype slug would resolve to no seed without surfacing
  /// the contract break.
  static CoachProfileSeed? byArchetype(String archetypeSlug) {
    switch (archetypeSlug) {
      case 'expat_us':
        return registry['julien_expat_us'];
      case 'swiss_native':
        return registry['julien_swiss'];
      case 'independent_no_lpp':
        return registry['independent_no_lpp_income_reality'];
      // Add other slug → seed mappings here as new seeds are added in
      // future sub-phases. Do NOT add a default arm — unknown slug = null.
      default:
        return null;
    }
  }
}
