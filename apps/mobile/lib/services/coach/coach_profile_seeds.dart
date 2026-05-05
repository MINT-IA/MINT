/// CoachProfileSeeds — E2E archetype seed loader (Phase 74).
///
/// Reads `--dart-define=MINT_E2E_ARCHETYPE=<slug>` and resolves it to a
/// minimal seed [Map] used by the walker harness to drive the anonymous
/// chat flow with realistic profile data.
///
/// In production builds the env var is empty → [activeSeed] returns null
/// and there is zero behavior change. The seed is consumed only by
/// E2E-aware code paths (Phase 74 walker_premier_eclairage.sh).
///
/// Slug catalog (12 total) :
///   - 8 CONTEXT D-02 archetypes :
///     swiss_native, expat_eu, expat_us, cross_border,
///     independent_no_lpp, recent_arrival, near_retirement,
///     young_starter
///   - 4 Phase 74 walker archetypes (per archetype JSON fixtures
///     under tools/simulator/archetypes/) :
///     julien_swiss, couple_acheteurs_lausanne, jeune_diplome_zurich,
///     cadre_40_55_lpp_rachat
///
/// The map values mirror the JSON fixtures so the seed loader stays
/// hardcoded (no asset bundle lookup → no production runtime cost).
/// When fixtures change, regenerate manually + add a TODO note.
///
/// References :
///   - PANEL-VERDICT.md §3 + §8 hidden risk #2
///   - tools/simulator/archetypes/*.json
library;

/// Coach profile seed used by the walker harness.
///
/// Fields are intentionally a flat [Map<String, Object>] to mirror the
/// JSON fixture format (no schema drift between Dart and tooling).
typedef CoachProfileSeed = Map<String, Object>;

/// Static seed catalog for both legacy CONTEXT D-02 slugs and Phase 74
/// walker archetypes.
///
/// Production callers MUST NOT branch on these — use [activeSeed] which
/// only returns non-null when the dart-define is set.
class CoachProfileSeeds {
  CoachProfileSeeds._();

  /// `--dart-define=MINT_E2E_ARCHETYPE=<slug>` — empty in production.
  static const String _activeSlugEnv =
      String.fromEnvironment('MINT_E2E_ARCHETYPE');

  /// Resolved active slug, or null when no E2E override is set.
  static String? get activeSlug =>
      _activeSlugEnv.isEmpty ? null : _activeSlugEnv;

  /// Returns the seed for [slug], or null if the slug is unknown.
  static CoachProfileSeed? seedFor(String slug) => _seeds[slug];

  /// Returns the seed for the active E2E archetype slug, or null when no
  /// E2E override is set or the slug is unknown.
  static CoachProfileSeed? get activeSeed {
    final s = activeSlug;
    if (s == null) return null;
    return _seeds[s];
  }

  /// All registered slugs (D-02 + Phase 74).
  static List<String> get knownSlugs => _seeds.keys.toList(growable: false);

  // ── seed catalog ────────────────────────────────────────────────────
  //
  // 8 CONTEXT D-02 slugs : minimal stubs sufficient for archetype
  //   selection in coach_context_builder. Full profiles live in
  //   coach_models / coach_context_builder defaults.
  // 4 Phase 74 slugs : mirror tools/simulator/archetypes/*.json for the
  //   walker. Source of truth = JSON fixtures.
  //
  static final Map<String, CoachProfileSeed> _seeds = {
    // ── CONTEXT D-02 (8) ─────────────────────────────────────────────
    'swiss_native': {
      'archetype': 'swiss_native',
      'age': 32,
      'canton': 'ZH',
      'salary_brut_year': 95000,
      'has_lpp': true,
      'has_3a': true,
    },
    'expat_eu': {
      'archetype': 'expat_eu',
      'age': 30,
      'canton': 'GE',
      'salary_brut_year': 105000,
      'has_lpp': true,
      'has_3a': false,
    },
    'expat_us': {
      'archetype': 'expat_us',
      'age': 36,
      'canton': 'ZG',
      'salary_brut_year': 180000,
      'has_lpp': true,
      'has_3a': false,
    },
    'cross_border': {
      'archetype': 'cross_border',
      'age': 40,
      'canton': 'GE',
      'salary_brut_year': 88000,
      'has_lpp': true,
      'has_3a': false,
    },
    'independent_no_lpp': {
      'archetype': 'independent_no_lpp',
      'age': 42,
      'canton': 'VD',
      'salary_brut_year': 130000,
      'has_lpp': false,
      'has_3a': true,
    },
    'recent_arrival': {
      'archetype': 'recent_arrival',
      'age': 28,
      'canton': 'BS',
      'salary_brut_year': 75000,
      'has_lpp': true,
      'has_3a': false,
    },
    'near_retirement': {
      'archetype': 'near_retirement',
      'age': 58,
      'canton': 'BE',
      'salary_brut_year': 130000,
      'has_lpp': true,
      'has_3a': true,
    },
    'young_starter': {
      'archetype': 'young_starter',
      'age': 24,
      'canton': 'ZH',
      'salary_brut_year': 68000,
      'has_lpp': true,
      'has_3a': false,
    },

    // ── PHASE 74 walker archetypes (4) — mirror JSON fixtures ────────
    'julien_swiss': {
      'archetype': 'swiss_native',
      'age': 34,
      'canton': 'VD',
      'salary_brut_year': 110000,
      'has_lpp': true,
      'lpp_balance': 95000,
      'has_3a': true,
      '3a_balance': 12500,
      'marital_status': 'single',
      'kids_count': 0,
      'owns_property': false,
      'expected_eclairage_kind': 'fiscal_margin_3a',
    },
    'couple_acheteurs_lausanne': {
      'archetype': 'swiss_native',
      'age': 38,
      'canton': 'VD',
      'salary_brut_year': 145000,
      'has_lpp': true,
      'lpp_balance': 220000,
      'has_3a': true,
      '3a_balance': 18000,
      'marital_status': 'married',
      'kids_count': 1,
      'owns_property': false,
      'expected_eclairage_kind': 'lpp_rachat_3a_nantissement',
    },
    'jeune_diplome_zurich': {
      'archetype': 'young_starter',
      'age': 26,
      'canton': 'ZH',
      'salary_brut_year': 82000,
      'has_lpp': true,
      'lpp_balance': 8500,
      'has_3a': false,
      '3a_balance': 0,
      'marital_status': 'single',
      'kids_count': 0,
      'owns_property': false,
      'expected_eclairage_kind': 'fiscal_margin_3a',
    },
    'cadre_40_55_lpp_rachat': {
      'archetype': 'swiss_native',
      'age': 48,
      'canton': 'GE',
      'salary_brut_year': 185000,
      'has_lpp': true,
      'lpp_balance': 410000,
      'has_3a': true,
      '3a_balance': 45000,
      'marital_status': 'married',
      'kids_count': 2,
      'owns_property': true,
      'expected_eclairage_kind': 'lpp_rachat_3a_nantissement',
    },
  };
}
