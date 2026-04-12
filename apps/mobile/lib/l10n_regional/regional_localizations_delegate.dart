// ────────────────────────────────────────────────────────────
//  REGIONAL LOCALIZATIONS DELEGATE — Phase 6 L1.4
// ────────────────────────────────────────────────────────────
//
// Sparse regional override layer on top of the base AppLocalizations.
// Stacking contract (see docs/VOICE_CURSOR_SPEC.md §14):
//
//   base N-level string → regional override (if present) → sensitive-topic cap
//
// The regional layer is COLORING, never intensity. It never changes the
// voice cursor N-level. Missing keys fall back SILENTLY to the base ARB.
//
// Locked decisions from .planning/phases/06-l1.4-voix-regionale/CONTEXT.md:
//   D-01: regional ARBs live in lib/l10n_regional/ (separate dir)
//   D-04: silent fallback to base — no crash, no English fallback
//   D-05: Profile.canton is the single trigger
//   D-08: every regional string ships `UNVALIDATED` until native sign-off
//
// Anti-caricature rule: every regional phrase must pass the
// "would a native smile or cringe?" test. Undercoloured > caricatural.
// ────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Regional canton codes with a carve-out ARB in Phase 6 (v1 scope).
enum RegionalCanton {
  /// Valais — fr-CH base, direct/montagnard coloring.
  vs,

  /// Zürich — de-CH base, Sparkultur / quiet-competence coloring.
  zh,

  /// Ticino — it-CH base, warm Mediterranean + Swiss rigor.
  ti,
}

/// Mapping from any Swiss canton code to its regional voice anchor.
///
/// Per CONTEXT.md D-05: secondary cantons route through this table.
/// VS is the Romande anchor (NOT VD) for Phase 6 v1 scope.
const Map<String, RegionalCanton> kCantonToRegional = <String, RegionalCanton>{
  // Romande → VS anchor
  'VS': RegionalCanton.vs,
  'VD': RegionalCanton.vs,
  'GE': RegionalCanton.vs,
  'NE': RegionalCanton.vs,
  'JU': RegionalCanton.vs,
  'FR': RegionalCanton.vs,
  // Deutschschweiz → ZH anchor
  'ZH': RegionalCanton.zh,
  'BE': RegionalCanton.zh,
  'LU': RegionalCanton.zh,
  'ZG': RegionalCanton.zh,
  'AG': RegionalCanton.zh,
  'SG': RegionalCanton.zh,
  'BS': RegionalCanton.zh,
  'BL': RegionalCanton.zh,
  'SO': RegionalCanton.zh,
  'TG': RegionalCanton.zh,
  'SH': RegionalCanton.zh,
  'AI': RegionalCanton.zh,
  'AR': RegionalCanton.zh,
  'GL': RegionalCanton.zh,
  'NW': RegionalCanton.zh,
  'OW': RegionalCanton.zh,
  'SZ': RegionalCanton.zh,
  'UR': RegionalCanton.zh,
  // Italiana → TI anchor
  'TI': RegionalCanton.ti,
  'GR': RegionalCanton.ti,
};

/// Base language for each regional canton. Regional overrides ONLY apply
/// when the active locale matches the anchor language (locale-locked per D-01).
const Map<RegionalCanton, String> kRegionalBaseLanguage =
    <RegionalCanton, String>{
  RegionalCanton.vs: 'fr',
  RegionalCanton.zh: 'de',
  RegionalCanton.ti: 'it',
};

const Map<RegionalCanton, String> _kRegionalAssetPath =
    <RegionalCanton, String>{
  RegionalCanton.vs: 'lib/l10n_regional/app_regional_vs.arb',
  RegionalCanton.zh: 'lib/l10n_regional/app_regional_zh.arb',
  RegionalCanton.ti: 'lib/l10n_regional/app_regional_ti.arb',
};

/// Resolves a free-form canton code (case/whitespace-tolerant) to a
/// [RegionalCanton], or `null` if no regional anchor applies.
RegionalCanton? resolveRegionalCanton(String? canton) {
  if (canton == null) return null;
  final key = canton.trim().toUpperCase();
  if (key.isEmpty) return null;
  return kCantonToRegional[key];
}

/// Sparse regional string table for a single canton / base language.
///
/// Loaded from the canton's `app_regional_*.arb` asset. Keys NOT present
/// in the regional ARB return `null` from [lookup] — callers MUST treat
/// `null` as "use base AppLocalizations" (silent fallback per D-04).
@immutable
class RegionalLocalizations {
  const RegionalLocalizations._(this.canton, this.locale, this._strings);

  /// The regional canton anchor this instance represents.
  final RegionalCanton canton;

  /// The locale this instance is bound to (always the canton's base language).
  final Locale locale;

  final Map<String, String> _strings;

  /// Returns the regional override for [key], or `null` if not present.
  String? lookup(String key) => _strings[key];

  /// Number of regional overrides loaded. Useful for diagnostics/tests.
  int get overrideCount => _strings.length;

  /// Retrieves the [RegionalLocalizations] from a [BuildContext], or `null`
  /// if no regional layer is installed (canton unset, locale mismatch, etc.).
  static RegionalLocalizations? of(BuildContext context) {
    return Localizations.of<RegionalLocalizations>(
      context,
      RegionalLocalizations,
    );
  }

  // Cache the parsed override tables by canton. ARB files are immutable
  // assets, so caching forever is safe — and it lets the delegate return
  // a [SynchronousFuture] on every load after the first, which keeps hot
  // canton swaps and widget tests frame-stable.
  static final Map<RegionalCanton, Map<String, String>> _cache =
      <RegionalCanton, Map<String, String>>{};

  static Future<RegionalLocalizations> _load(
    RegionalCanton canton,
    Locale locale,
  ) {
    final cached = _cache[canton];
    if (cached != null) {
      return SynchronousFuture<RegionalLocalizations>(
        RegionalLocalizations._(canton, locale, cached),
      );
    }
    return _loadFromBundle(canton, locale);
  }

  static Future<RegionalLocalizations> _loadFromBundle(
    RegionalCanton canton,
    Locale locale,
  ) async {
    final path = _kRegionalAssetPath[canton]!;
    final raw = await rootBundle.loadString(path);
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final strings = <String, String>{};
    decoded.forEach((k, v) {
      // Skip ARB metadata (@@locale, @@x-*, @keyName).
      if (k.startsWith('@')) return;
      if (v is String) strings[k] = v;
    });
    _cache[canton] = strings;
    return RegionalLocalizations._(canton, locale, strings);
  }

  /// Test-only: clear the ARB parse cache. Not used in production.
  @visibleForTesting
  static void debugClearCache() => _cache.clear();
}

/// Custom [LocalizationsDelegate] that installs the canton's sparse regional
/// override on top of the base [AppLocalizations].
///
/// Construct with the user's current canton (from `Profile.canton`). A null
/// or unmapped canton yields an unsupported delegate — the regional layer is
/// simply absent, and [RegionalLocalizations.of] returns `null` everywhere.
/// Callers already handle that via silent fallback.
class RegionalLocalizationsDelegate
    extends LocalizationsDelegate<RegionalLocalizations> {
  const RegionalLocalizationsDelegate(this.canton);

  /// The resolved regional anchor (from [resolveRegionalCanton]), or `null`.
  final RegionalCanton? canton;

  @override
  bool isSupported(Locale locale) {
    final c = canton;
    if (c == null) return false;
    return kRegionalBaseLanguage[c] == locale.languageCode;
  }

  @override
  Future<RegionalLocalizations> load(Locale locale) {
    // Must not be called when isSupported returned false.
    return RegionalLocalizations._load(canton!, locale);
  }

  @override
  bool shouldReload(covariant RegionalLocalizationsDelegate old) {
    return old.canton != canton;
  }
}
