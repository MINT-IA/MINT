// Phase 96 D-12 — Dart mirror of backend Pydantic SerializedCardContext.
//
// Carries a card snapshot to the backend coach_chat endpoint for narrator
// source-card context injection. NO PII (no IBAN, no name, no employer,
// no email). Fields per 96-CONTEXT.md D-12 — 7 fields, all derived from
// financial_core values + life-event metadata. The backend Pydantic v2
// frozen+forbid mirror at services/backend/app/schemas/card_context.py
// lands in Plan 96-02.
//
// Threat model: T-96-W1-SerializedCardContextPII — structural enforcement
// here (no field = no carrier). The backend extra="forbid" is the canonical
// PII gate.

class SerializedCardContext {
  /// Stable card identifier (e.g. `mon_3a_2026`, `lpp_projection`).
  final String cardId;

  /// Taxonomy slug (e.g. `pillar_3a`, `lpp_retirement`, `tax_optimization`,
  /// `mortgage`, `cross_pillar`).
  final String cardType;

  /// Financial_core values ONLY (no PII, no raw user input).
  /// Decimal serialised as String per Pydantic camelCase emission.
  final Map<String, dynamic> computedFacts;

  /// Citation key candidates from the card, subset of the 18-key
  /// CITATION_REGISTRY namespace (or new keys added to it).
  final List<String> groundingKeys;

  /// One of MINT's 18 life events (housing/family/career/tax/debt/
  /// retirement/...). Nullable when the card spans multiple events.
  final String? lifeEvent;

  /// 2-letter Swiss canton (VD, GE, ZH, ...).
  final String? canton;

  /// One of the 8 archetypes (swiss_native, expat_eu, expat_us,
  /// cross_border, indep_with_lpp, indep_no_lpp, returning_swiss, retiree).
  final String? archetype;

  const SerializedCardContext({
    required this.cardId,
    required this.cardType,
    this.computedFacts = const <String, dynamic>{},
    this.groundingKeys = const <String>[],
    this.lifeEvent,
    this.canton,
    this.archetype,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cardId': cardId,
        'cardType': cardType,
        'computedFacts': computedFacts,
        'groundingKeys': groundingKeys,
        if (lifeEvent != null) 'lifeEvent': lifeEvent,
        if (canton != null) 'canton': canton,
        if (archetype != null) 'archetype': archetype,
      };

  factory SerializedCardContext.fromJson(Map<String, dynamic> json) {
    return SerializedCardContext(
      cardId: json['cardId'] as String,
      cardType: json['cardType'] as String,
      computedFacts: (json['computedFacts'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      groundingKeys:
          (json['groundingKeys'] as List?)?.cast<String>() ?? const <String>[],
      lifeEvent: json['lifeEvent'] as String?,
      canton: json['canton'] as String?,
      archetype: json['archetype'] as String?,
    );
  }
}
