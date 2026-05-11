// Phase 96 D-14 — Dart mirror of backend NarrativeSleeve Pydantic schema
// (services/backend/app/schemas/narrative_sleeve.py).
//
// Optional response envelope on CoachChatResponse.narrative_sleeve. The
// hook digit-free linter (Plan 96-03 T1, services/backend/app/services/
// coach/narrative_sleeve_lint.py) has already swapped any digit-bearing
// hook to the FR fallback before this struct is serialised — the Dart
// renderer treats the hook field as ground truth.
class NarrativeSleeve {
  /// 1-line attention-grabbing opener, digit-free at runtime per D-16.
  final String hook;

  /// Main body. Cited numbers have already been substituted via the
  /// Phase 94 citation gate + Phase 95 W2 pack double-lookup.
  final String caption;

  /// Verb-first call-to-action, ≤12 words at lint time. Rendered with
  /// a leading « › » glyph per UI-SPEC §NarrativeSleeve.
  final String nextStep;

  /// Static TOML lookup result by archetype × canton × life_event.
  /// Empty string when no entry matches — UI conditionally hides the
  /// metaphor block.
  final String metaphor;

  const NarrativeSleeve({
    required this.hook,
    required this.caption,
    required this.nextStep,
    this.metaphor = '',
  });

  /// Build from a JSON map. Backend emits camelCase keys via
  /// Pydantic v2 alias_generator=to_camel. Accepts both camelCase
  /// (`nextStep`) and snake_case (`next_step`) for robustness.
  factory NarrativeSleeve.fromJson(Map<String, dynamic> json) {
    final next = json['nextStep'] ?? json['next_step'] ?? '';
    return NarrativeSleeve(
      hook: (json['hook'] as String?) ?? '',
      caption: (json['caption'] as String?) ?? '',
      nextStep: next as String,
      metaphor: (json['metaphor'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'hook': hook,
        'caption': caption,
        'nextStep': nextStep,
        'metaphor': metaphor,
      };
}
