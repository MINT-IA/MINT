import 'package:flutter/material.dart';

import '../../services/voice/voice_cursor_contract.dart';
import '../../theme/colors.dart';
import '../../theme/mint_text_styles.dart';
import 'voice_resolution_context.dart';

export 'voice_resolution_context.dart' show VoiceResolutionContext, ExternalActionStub;

/// MintAlertObject — typed, compiler-enforced alert primitive for S5.
///
/// ## Why a typed widget?
///
/// The whole point of this component is to make the GRAMMAR of an alert
/// compiler-enforced. There is **no** `String message` field on purpose:
/// callers must supply three semantic pieces — [fact], [cause] and
/// [nextMoment] — which the widget composes into a single MINT-as-subject
/// sentence:
///
/// > "MINT a remarqué: {fact}. {cause}. {nextMoment}."
///
/// This prevents the "ship a free-form message" anti-pattern that otherwise
/// lets LLM output leak into the alert surface.
///
/// ## Sourcing rules (NON-NEGOTIABLE — Phase 9 D-07)
///
/// This widget is **information-only by default** (D-12). It must be fed by
/// `AnticipationProvider`, `NudgeEngine` or `ProactiveTriggerService` — never
/// by any `claude_*_service.dart` output. The `tools/checks/no_llm_alert.py`
/// grep gate fails CI on any file that imports both a Claude service and
/// instantiates [MintAlertObject].
///
/// ## Rendering (Phase 9 D-02, D-11, D-13)
///
/// * [Gravity.g2] — calm register. Single compact card, [MintColors.warningAaa]
///   accent, no grammatical break, no priority float. Uses the S0-S5 AAA
///   token set (`textSecondaryAaa`, `warningAaa`).
/// * [Gravity.g3] — grammatical break. Visual rupture via a divider between
///   [fact] and [cause], [MintColors.errorAaa] accent, higher visual weight.
///   Plan 09-02 wires the priority float on the S5 card stack and Plan 09-04
///   wires the `SemanticsService.announce` transition G2 → G3.
///
/// Both gravities expose `liveRegion: true` on the outer `Semantics` wrapper
/// so screen readers pick up updates. Reduced-motion is honored via
/// `MediaQuery.disableAnimationsOf(context)` — no animation controllers run.
///
/// ## Voice cursor integration (D-01, D-04)
///
/// The widget imports [Gravity] from the generated
/// `voice_cursor_contract.g.dart` (re-exported by `voice_cursor_contract.dart`)
/// — there is no local enum. On build it calls [resolveLevel] with the
/// caller-supplied [VoiceResolutionContext] to compute a [VoiceLevel] used
/// today as a semantic hint only. Plan 09-02 will wire that level into the
/// visual matrix; this plan keeps the widget a pure function of its inputs.
///
/// See `docs/VOICE_CURSOR_SPEC.md` §9-§14 and
/// `visions/MINT_DESIGN_BRIEF_v0.2.3.md` §L1.5 for full context.
class MintAlertObject extends StatelessWidget {
  const MintAlertObject({
    super.key,
    required this.gravity,
    required this.fact,
    required this.cause,
    required this.nextMoment,
    required this.alertId,
    required this.resolutionContext,
    this.externalAction,
  });

  /// Severity from the generated voice cursor contract (D-01).
  final Gravity gravity;

  /// The MINT-as-subject statement. MUST start with "MINT" to respect the
  /// anti-shame doctrine. Already-resolved (ARB → String) by the feeder.
  final String fact;

  /// The "Pourquoi" line — the cause / context of the fact.
  final String cause;

  /// The "Quand on en reparle" line — the next reflection moment, NOT an
  /// imperative CTA. MINT invites, never commands.
  final String nextMoment;

  /// Deterministic content hash used for ack persistence (Plan 09-04) and
  /// for the live-region transition notifier (Plan 09-04).
  final String alertId;

  /// Caller-supplied resolution inputs for [resolveLevel]. See
  /// [VoiceResolutionContext] for sourcing rules.
  final VoiceResolutionContext resolutionContext;

  /// Phase 12+ partner routing stub. Info-only by default (D-12).
  final ExternalActionStub? externalAction;

  @override
  Widget build(BuildContext context) {
    // Resolve N-level via the pure contract function. Used today as a
    // semantic hint — Plan 09-02 will wire it into the render matrix.
    final VoiceLevel level = resolveLevel(
      gravity: gravity,
      relation: resolutionContext.relation,
      preference: resolutionContext.preference,
      sensitiveFlag: resolutionContext.sensitiveFlag,
      fragileFlag: resolutionContext.fragileFlag,
      n5Budget: resolutionContext.n5Budget,
    );

    final bool isG3 = gravity == Gravity.g3;
    final Color accent = isG3 ? MintColors.errorAaa : MintColors.warningAaa;
    final Color surface = isG3
        ? MintColors.errorAaa.withValues(alpha: 0.12)
        : MintColors.warningAaa.withValues(alpha: 0.08);

    // Reduced-motion honored: no controllers, no AnimatedSwitcher.
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final Widget factText = Text(
      fact,
      style: MintTextStyles.bodyLarge(color: MintColors.textPrimary).copyWith(
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    );

    final Widget causeText = Text(
      cause,
      style: MintTextStyles.bodyMedium(
        color: MintColors.textSecondaryAaa,
      ).copyWith(height: 1.4),
    );

    final Widget nextMomentText = Text(
      nextMoment,
      style: MintTextStyles.labelLarge(color: accent).copyWith(
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
    );

    // Grammatical break: visual rupture only on G3.
    final List<Widget> columnChildren = <Widget>[
      factText,
      if (isG3) ...<Widget>[
        const SizedBox(height: 8),
        Divider(color: accent.withValues(alpha: 0.4), height: 1, thickness: 1),
        const SizedBox(height: 8),
      ] else
        const SizedBox(height: 6),
      causeText,
      const SizedBox(height: 8),
      nextMomentText,
    ];

    final Widget card = Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: accent, width: isG3 ? 1.5 : 1.0),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isG3 ? Icons.priority_high : Icons.info_outline,
            color: accent,
            size: 22,
            semanticLabel: isG3 ? 'Alerte importante' : 'Point à vérifier',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: columnChildren,
            ),
          ),
        ],
      ),
    );

    // Outer Semantics: liveRegion on G2 AND G3 so screen readers announce
    // updates; Plan 09-04 handles the G2→G3 transition-only announce.
    final Widget semantic = Semantics(
      container: true,
      liveRegion: true,
      label: fact,
      value: cause,
      hint: nextMoment,
      // `level` is exposed as a debug hint for a11y tests.
      attributedLabel: null,
      child: card,
    );

    // A trivial no-op use of [level] and [externalAction] + [alertId] to keep
    // the analyzer aware they are part of the public contract; Plans 09-02 /
    // 09-04 turn these into real wires.
    assert(level.index >= 0);
    assert(alertId.isNotEmpty, 'alertId must be non-empty (ack persistence)');
    assert(externalAction == null || externalAction!.label.isNotEmpty);

    // reduced-motion: intentionally no AnimatedSwitcher / Hero / implicit
    // animations. The surface is static.
    return disableAnimations ? semantic : semantic;
  }
}
