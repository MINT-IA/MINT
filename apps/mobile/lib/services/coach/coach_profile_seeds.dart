/// CoachProfileSeeds — Phase 80 (v2.11).
///
/// Hydrates a deterministic [CoachContext]-like seed when the
/// `MINT_E2E_ARCHETYPE` dart-define is set at build time (walker /
/// widget-test runs). Closes phantom contract C1: the v2.10 audit
/// flagged this primitive as declared-but-never-called.
///
/// Pinned to the 4 v2.10 walker archetypes (julien_swiss /
/// couple_acheteurs_lausanne / jeune_diplome_zurich /
/// cadre_40_55_lpp_rachat). New seeds require a coordinated bump of
/// the walker fixture set + this file.
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

  /// Gross monthly salary in CHF (typical for the archetype).
  final double grossMonthlySalary;

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
    final netMonthlySalary = (grossMonthlySalary * 0.78).roundToDouble();
    final hasLpp = usTaxPerson != true;
    final annual3a = hasLpp ? 7056.0 : 0.0;

    return <String, dynamic>{
      'q_firstname': firstName,
      'q_birth_year': birthYear,
      'q_canton': canton,
      'q_pay_frequency': 'monthly',
      'q_gross_salary_annual': grossMonthlySalary * 12,
      'q_net_income_period_chf': netMonthlySalary,
      'q_employment_status': 'employed',
      'q_household_type': 'single',
      'q_housing_cost_period_chf': (netMonthlySalary * 0.26).roundToDouble(),
      'q_tax_provision_monthly_chf':
          (grossMonthlySalary * 0.15).roundToDouble(),
      'q_lamal_premium_monthly_chf': 420.0,
      'q_other_fixed_costs_monthly_chf': 850.0,
      'q_savings_monthly': (netMonthlySalary * 0.16).roundToDouble(),
      'q_savings_allocation': const <String>[
        '3a',
        'investissement',
        'epargne_libre',
      ],
      'q_has_pension_fund': hasLpp,
      'q_has_3a': hasLpp,
      'q_3a_annual_contribution': annual3a,
      'q_3a_accounts_count': hasLpp ? 1 : 0,
      'q_has_investments': true,
      'q_cash_total': netMonthlySalary * 3,
      'q_investments_total': netMonthlySalary * 6,
      'q_avs_lacunes_status': 'unknown',
      'q_has_consumer_debt': false,
      'q_nationality':
          nationality ?? (archetype == 'swiss_native' ? 'CH' : null),
      if (usTaxPerson != null) 'q_us_tax_person': usTaxPerson,
    };
  }
}

/// Static registry of the 4 v2.10 walker archetype seeds.
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
      // Add other slug → seed mappings here as new seeds are added in
      // future sub-phases. Do NOT add a default arm — unknown slug = null.
      default:
        return null;
    }
  }
}
