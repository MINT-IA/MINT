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

  const CoachProfileSeed({
    required this.slug,
    required this.firstName,
    required this.age,
    required this.canton,
    required this.archetype,
    required this.grossMonthlySalary,
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
  };

  /// Return the slug forced via `MINT_E2E_ARCHETYPE`, or null when:
  ///   - we are in a release build ([kReleaseMode] = true), OR
  ///   - the dart-define is empty / unknown.
  ///
  /// Release-build short-circuit keeps the codepath dead in production
  /// (defense-in-depth alongside the dart-define being absent on prod).
  static String? forcedArchetypeSlug() {
    if (kReleaseMode) return null;
    final slug = _archetypeDartDefine.trim();
    if (slug.isEmpty) return null;
    if (!registry.containsKey(slug)) return null;
    return slug;
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
}
