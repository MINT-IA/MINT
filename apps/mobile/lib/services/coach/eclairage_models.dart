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
  /// The headline/body/range are also rewritten to the deterministic template
  /// for the forced kind so widget tests can assert on stable copy without
  /// depending on the LLM-natural payload.
  EclairageCardData withForcedKind(EclairageKind forcedKind) {
    if (forcedKind == kind) return this;
    final tpl = _templateFor(forcedKind);
    return EclairageCardData(
      kind: forcedKind,
      headline: tpl.headline,
      body: tpl.body,
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
  /// PERS-03/04 (v2.13 Phase 90) — softAccountHint is now panel-tagged
  /// per kind so Maestro YAML flows can assert on the deterministic
  /// CTA text. Previously null (no CTA rendered for forced-kind walker
  /// runs), which prevented assertVisible: "Estime ta marge précise"
  /// from passing.
  static EclairageCardData fromForcedKind(EclairageKind forcedKind) {
    final tpl = _templateFor(forcedKind);
    return EclairageCardData(
      kind: forcedKind,
      headline: tpl.headline,
      body: tpl.body,
      chfRangeLow: tpl.low,
      chfRangeHigh: tpl.high,
      chfRangePeriod: tpl.period,
      lsfinDisclaimer:
          'Information à but éducatif. Pas un conseil personnalisé au sens '
          'de la LSFin. Vérifie ta situation auprès d’un conseiller '
          'agréé avant toute décision.',
      softAccountHint: _softHintFor(forcedKind),
    );
  }

  /// Panel-tagged CTA copy per éclairage kind. Used by `fromForcedKind`
  /// (walker / widget tests) and as a fallback when the backend omits
  /// the field. Production LLM-natural payloads can override these.
  static String _softHintFor(EclairageKind kind) {
    switch (kind) {
      case EclairageKind.fiscalMargin3a:
        return 'Estime ta marge précise';
      case EclairageKind.lppRachatWindow:
        return 'Estime ton rachat LPP';
      case EclairageKind.liquidityRunway:
        return 'Estime ta réserve liquide';
      case EclairageKind.compoundGrowthEdge:
        return 'Visualise ta projection';
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
/// forced via dart-define. Matches the v2.10 archetype-pinned copy so the
/// Phase 80 widget test can assert on stable strings.
class _EclairageTemplate {
  const _EclairageTemplate({
    required this.headline,
    required this.body,
    required this.low,
    required this.high,
    required this.period,
  });
  final String headline;
  final String body;
  final double low;
  final double high;
  final String period;
}

_EclairageTemplate _templateFor(EclairageKind kind) {
  switch (kind) {
    case EclairageKind.fiscalMargin3a:
      return const _EclairageTemplate(
        headline: 'Ta marge fiscale 3a',
        body: 'À ton revenu, cotiser au plafond du 3e pilier pourrait '
            'réduire ton impôt de l’ordre indiqué chaque année. '
            'Le levier fiscal dépend de ton canton et de ta tranche '
            'marginale.',
        low: 1500,
        high: 2500,
        period: 'year',
      );
    case EclairageKind.lppRachatWindow:
      return const _EclairageTemplate(
        headline: 'Ta fenêtre de rachat LPP',
        body: 'Selon ton certificat LPP, des rachats pourraient être '
            'envisagés sur les prochaines années. L’économie '
            'd’impôt indiquée est conditionnelle à ta tranche '
            'marginale et au plafond communiqué par ta caisse.',
        low: 4000,
        high: 9000,
        period: 'year',
      );
    case EclairageKind.liquidityRunway:
      return const _EclairageTemplate(
        headline: 'Ta réserve de liquidité',
        body: 'Avec tes dépenses courantes, ton coussin couvre la '
            'fenêtre indiquée. Une réserve de 3 à 6 mois reste un '
            'repère cité par les conseillers indépendants.',
        low: 2,
        high: 4,
        period: 'months',
      );
    case EclairageKind.compoundGrowthEdge:
      return const _EclairageTemplate(
        headline: 'Ton avantage temps',
        body: 'Commencer maintenant plutôt qu’à 35 ans pourrait '
            'faire une différence dans la fourchette indiquée à 65 ans, '
            'pour un effort mensuel modeste. La capitalisation '
            'récompense la durée, pas le timing.',
        low: 35000,
        high: 70000,
        period: 'lifetime',
      );
  }
}
