/// Eclairage data contract — Phase 80 (v2.11 milestone).
///
/// Closes phantom contract C1 from the 2026-05-05 audit cycle: the
/// "Premier Éclairage" payload that the backend emits at coach turn 2
/// (Phase 81) and the Flutter anonymous chat screen renders as a
/// distinct, deterministic card (NOT free-form prose).
///
/// LSFin compliance baked in:
///   - Always conditional CHF range (low + high), never absolute.
///   - LSFin disclaimer mandatory on every card (`lsfinDisclaimer`).
///   - "Soft account hint" copy frames the upgrade as enabling, not
///     gating ("crée un compte pour…", never "tu ne peux pas sans").
///
/// References:
///   - REQUIREMENTS.md ECLW-01..05 (Flutter wiring)
///   - REQUIREMENTS.md ECLB-01..05 (backend contract — Phase 81)
///   - decisions/2026-05-04-post-handoff2-sweep-panel.md
library;

/// Discrete kinds of "Premier Éclairage" cards.
///
/// Pinned to the 4 v2.10 walker archetypes. New kinds require a coordinated
/// Flutter + backend bump (Phase 80 + 81 contract).
enum EclairageKind {
  /// 3a fiscal margin headline (julien_swiss). Compares user's effective 3a
  /// contribution to the legal ceiling and surfaces the tax saving range.
  fiscalMargin3a('fiscal_margin_3a'),

  /// LPP rachat opportunity (cadre_40_55_lpp_rachat). Surfaces the cumulative
  /// rachat envelope and yearly tax saving range.
  lppRachatWindow('lpp_rachat_window'),

  /// Liquidity reserve sanity check (couple_acheteurs_lausanne). Months of
  /// expenses currently covered, framed as a range.
  liquidityRunway('liquidity_runway'),

  /// Compound growth advantage for early career (jeune_diplome_zurich).
  /// Range = early-start vs delayed-start CHF delta at 65.
  compoundGrowthEdge('compound_growth_edge');

  const EclairageKind(this.wireName);

  /// Snake-case identifier exchanged with the backend / dart-define.
  final String wireName;

  /// Parse a wire identifier (case-sensitive). Returns null on unknown values
  /// so callers can degrade to free-form prose without throwing.
  static EclairageKind? fromWire(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final k in EclairageKind.values) {
      if (k.wireName == raw) return k;
    }
    return null;
  }
}

/// Data class for a renderable eclairage card.
///
/// Fields mirror the backend `EclairageSchema` (Phase 81 ECLB-02). Field
/// names are snake_case on the wire but camelCase here per Dart convention;
/// [fromMap] / [toMap] handle the mapping.
class EclairageCardData {
  /// Discrete kind (drives template / colour / icon).
  final EclairageKind kind;

  /// Hero headline — short, declarative, no CTA verbs ("Ta marge fiscale 3a"
  /// not "Économise X CHF !"). Max ~60 chars.
  final String headline;

  /// Body copy — 1-2 sentences explaining what the range means. No promise
  /// language (see ComplianceGuard banned terms).
  final String body;

  /// Lower bound of the CHF range (inclusive). Always non-negative.
  final double chfRangeLow;

  /// Upper bound of the CHF range (inclusive). Always >= [chfRangeLow].
  final double chfRangeHigh;

  /// Period covered by the range — "year", "month", "lifetime". Free-form
  /// string for now; the backend pins it to a controlled vocabulary.
  final String chfRangePeriod;

  /// Soft hint copy to invite account creation. Optional — when null/empty,
  /// the screen falls back to its own anonymous-chat conversion prompt.
  final String? softAccountHint;

  /// LSFin disclaimer (REQUIRED). Empty string is treated as a contract
  /// violation by [EclairageCardData.fromMap] which returns null.
  final String lsfinDisclaimer;

  const EclairageCardData({
    required this.kind,
    required this.headline,
    required this.body,
    required this.chfRangeLow,
    required this.chfRangeHigh,
    required this.chfRangePeriod,
    required this.lsfinDisclaimer,
    this.softAccountHint,
  });

  /// Build from a JSON map (backend response['eclairage']).
  ///
  /// Returns null when the contract is violated (missing kind, empty
  /// disclaimer, range inverted, etc.) so callers can silently degrade
  /// to free-form prose. The anonymous chat screen treats null as
  /// "no eclairage card this turn".
  static EclairageCardData? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final kind = EclairageKind.fromWire(map['kind'] as String?);
    if (kind == null) return null;

    final headline = (map['headline'] as String? ?? '').trim();
    final body = (map['body'] as String? ?? '').trim();
    final disclaimer = (map['lsfin_disclaimer'] as String? ?? '').trim();
    if (headline.isEmpty || body.isEmpty || disclaimer.isEmpty) return null;

    final low = _asDouble(map['chf_range_low']);
    final high = _asDouble(map['chf_range_high']);
    if (low == null || high == null || low < 0 || high < low) return null;

    final period =
        (map['chf_range_period'] as String? ?? 'year').trim();
    final softHint = (map['soft_account_hint'] as String?)?.trim();

    return EclairageCardData(
      kind: kind,
      headline: headline,
      body: body,
      chfRangeLow: low,
      chfRangeHigh: high,
      chfRangePeriod: period.isEmpty ? 'year' : period,
      lsfinDisclaimer: disclaimer,
      softAccountHint:
          softHint == null || softHint.isEmpty ? null : softHint,
    );
  }

  /// Return a copy with [kind] overridden — used by the
  /// `MINT_E2E_FORCE_ECLAIRAGE_KIND` dart-define path (ECLW-01 + ECLW-04).
  ///
  /// The CHF range is rewritten to the deterministic template for the forced
  /// kind. Headline / body are left EMPTY so the rendering widget resolves the
  /// localized copy from [kind] via `AppLocalizations` (hotfix 2026-06-12 —
  /// i18n + honest conditional copy; see [eclairageKindHeadlineKey] /
  /// [eclairageKindBodyKey]). This removes the hardcoded French presumption
  /// that previously shipped here (« Selon ton certificat LPP, … » for an
  /// anonymous user who never provided a certificate).
  EclairageCardData withForcedKind(EclairageKind forcedKind) {
    if (forcedKind == kind) return this;
    final tpl = _templateFor(forcedKind);
    return EclairageCardData(
      kind: forcedKind,
      headline: '',
      body: '',
      chfRangeLow: tpl.low,
      chfRangeHigh: tpl.high,
      chfRangePeriod: tpl.period,
      lsfinDisclaimer: lsfinDisclaimer,
      softAccountHint: softAccountHint,
    );
  }

  /// Build a deterministic card from a forced kind alone (used when the
  /// backend did NOT emit any eclairage payload but the dart-define is set
  /// — typically in walker / widget-test runs).
  ///
  /// Headline / body are intentionally EMPTY: the localized strings are
  /// resolved by the rendering widget from [kind] (hotfix 2026-06-12). The
  /// LSFin disclaimer is likewise resolved by the widget; the empty sentinel
  /// here keeps the data class free of hardcoded user-facing French.
  static EclairageCardData fromForcedKind(EclairageKind forcedKind) {
    final tpl = _templateFor(forcedKind);
    return EclairageCardData(
      kind: forcedKind,
      headline: '',
      body: '',
      chfRangeLow: tpl.low,
      chfRangeHigh: tpl.high,
      chfRangePeriod: tpl.period,
      lsfinDisclaimer: '',
      softAccountHint: null,
    );
  }

  /// ARB key for the localized headline of [kind] — resolved by the rendering
  /// widget via `AppLocalizations` (hotfix 2026-06-12). Kept as a pure
  /// kind→key map so the const data class stays BuildContext-free.
  static String eclairageKindHeadlineKey(EclairageKind kind) {
    switch (kind) {
      case EclairageKind.fiscalMargin3a:
        return 'eclairageFiscalMargin3aHeadline';
      case EclairageKind.lppRachatWindow:
        return 'eclairageLppRachatWindowHeadline';
      case EclairageKind.liquidityRunway:
        return 'eclairageLiquidityRunwayHeadline';
      case EclairageKind.compoundGrowthEdge:
        return 'eclairageCompoundGrowthEdgeHeadline';
    }
  }

  /// ARB key for the localized body of [kind] (hotfix 2026-06-12).
  static String eclairageKindBodyKey(EclairageKind kind) {
    switch (kind) {
      case EclairageKind.fiscalMargin3a:
        return 'eclairageFiscalMargin3aBody';
      case EclairageKind.lppRachatWindow:
        return 'eclairageLppRachatWindowBody';
      case EclairageKind.liquidityRunway:
        return 'eclairageLiquidityRunwayBody';
      case EclairageKind.compoundGrowthEdge:
        return 'eclairageCompoundGrowthEdgeBody';
    }
  }

  static double? _asDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

/// Internal template payload for deterministic rendering when a kind is
/// forced via dart-define.
///
/// Hotfix 2026-06-12: only the CHF range (low / high / period) lives here now.
/// The user-facing headline / body strings were moved to ARB keys ×6 locales
/// (resolved by the rendering widget via `AppLocalizations`) — see
/// [EclairageCardData.eclairageKindHeadlineKey] /
/// [EclairageCardData.eclairageKindBodyKey]. This removes hardcoded French
/// from the data layer (CLAUDE.md NEVER #1) and replaces the presumptuous
/// « Selon ton certificat LPP, … » copy with honest conditional phrasing in
/// the ARBs.
class _EclairageTemplate {
  const _EclairageTemplate({
    required this.low,
    required this.high,
    required this.period,
  });
  final double low;
  final double high;
  final String period;
}

_EclairageTemplate _templateFor(EclairageKind kind) {
  switch (kind) {
    case EclairageKind.fiscalMargin3a:
      return const _EclairageTemplate(low: 1500, high: 2500, period: 'year');
    case EclairageKind.lppRachatWindow:
      return const _EclairageTemplate(low: 4000, high: 9000, period: 'year');
    case EclairageKind.liquidityRunway:
      return const _EclairageTemplate(low: 2, high: 4, period: 'months');
    case EclairageKind.compoundGrowthEdge:
      return const _EclairageTemplate(
          low: 35000, high: 70000, period: 'lifetime');
  }
}
