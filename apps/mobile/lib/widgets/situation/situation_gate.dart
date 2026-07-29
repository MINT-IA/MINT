import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Provenance of a situation-fact, in the strict P2 "gate dur" sense.
///
/// A fact only counts as *confirmed* when it comes from the user's real data:
/// either it was seeded from a provenance-backed profile field
/// (`CoachProfile.userProvidedFields`) or the user touched its control.
/// A value that merely *equals* a fabricated default is [assumed] — never
/// confirmed. See `.planning/decisions/2026-07-25-p2-simulator-result-gating.md`.
enum FactProvenance {
  /// Seeded from a profile field the user explicitly provided.
  seededFromProfile,

  /// The user touched the control (including confirming a default / a zero).
  touched,

  /// Not backed by any user data — a fabricated default. Never gates open.
  assumed,
}

/// A single determinative situation-fact for one computed output.
///
/// [label] and [why] are resolved lazily against a [BuildContext] so the copy
/// stays localized. [onComplete] scrolls the screen to the control that lets
/// the user provide this fact (wired by each screen).
@immutable
class SituationFact {
  const SituationFact({
    required this.key,
    required this.label,
    required this.provenance,
    this.why,
    this.onComplete,
  });

  /// Stable identifier (e.g. `'canton'`), used for scroll routing + tests.
  final String key;

  /// Human-readable fact name (localized).
  final String Function(BuildContext context) label;

  /// Why this fact is required for the output (localized, educational).
  final String Function(BuildContext context)? why;

  /// How this fact was (or was not) established.
  final FactProvenance provenance;

  /// Called when the user asks to complete this fact.
  final VoidCallback? onComplete;

  /// A fact is confirmed unless it is a fabricated [FactProvenance.assumed].
  bool get confirmed => provenance != FactProvenance.assumed;
}

/// The gate guarding a single computed output behind its determinative facts.
///
/// Pure + unit-testable: no widget dependencies in the gating logic.
@immutable
class SituationGate {
  const SituationGate(this.facts);

  final List<SituationFact> facts;

  /// Every determinative fact is confirmed.
  bool get complete => facts.every((f) => f.confirmed);

  /// The still-unconfirmed facts, in declaration order.
  List<SituationFact> get missing =>
      [for (final f in facts) if (!f.confirmed) f];

  /// Total number of determinative facts.
  int get total => facts.length;

  /// Number of confirmed facts.
  int get confirmedCount => facts.where((f) => f.confirmed).length;
}

/// Renders in the *result slot* when an output is gated: it replaces the
/// figure with a progress header + a discrete, focusable node per missing
/// fact. There is deliberately **no** "continuer avec l'estimation" escape
/// hatch — P2 bans computing on fabricated data.
class SituationGateCard extends StatelessWidget {
  const SituationGateCard({
    super.key,
    required this.title,
    required this.gate,
  });

  /// Screen-provided, output-specific heading.
  final String title;

  /// The gate whose missing facts are surfaced.
  final SituationGate gate;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final missing = gate.missing;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.warning.withValues(alpha: 0.10),
            MintColors.warning.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header (discrete node) ──
            Semantics(
              header: true,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MintColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 20,
                      color: MintColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: MintTextStyles.labelLarge(
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── Progress (discrete node) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s.situationGateProgress(gate.confirmedCount, gate.total),
                style: MintTextStyles.labelMedium(color: MintColors.warning)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 14),
            // ── Missing facts (one discrete button node each) ──
            for (final fact in missing) _MissingFactRow(fact: fact),
          ],
        ),
      ),
    );
  }
}

/// One missing-fact row, exposed to assistive tech as a single labeled button.
class _MissingFactRow extends StatelessWidget {
  const _MissingFactRow({required this.fact});

  final SituationFact fact;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final label = fact.label(context);
    final why = fact.why?.call(context);
    final action = s.situationGateCompleterAction;
    final a11yLabel = why == null || why.isEmpty
        ? '$label. $action'
        : '$label. $why $action';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: a11yLabel,
        onTap: fact.onComplete,
        excludeSemantics: true,
        child: InkWell(
          onTap: fact.onComplete,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: MintColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: MintTextStyles.bodyMedium(
                          color: MintColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (why != null && why.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          why,
                          style: MintTextStyles.labelSmall(
                            color: MintColors.textSecondary,
                          ).copyWith(height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: MintSpacing.sm),
                Text(
                  action,
                  style: MintTextStyles.labelMedium(color: MintColors.warning)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: MintColors.warning,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
