import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/sequence_run.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Displays the progress of an active guided sequence in the coach chat.
///
/// Shows:
/// - Goal label
/// - Progress bar (completed / total)
/// - Current step title
/// - "Prêt pour l'étape suivante ?" CTA (when advancing)
/// - "Quitter le parcours" secondary action
///
/// Pure presentational widget — no side effects, no providers.
/// All data comes from [template] and [run].
///
/// See: docs/RFC_AGENT_LOOP_STATEFUL.md §3.6, Phase 2
class SequenceProgressCard extends StatelessWidget {
  /// The current runtime state.
  final SequenceRun run;

  /// Label of the current step (resolved from ARB by caller).
  final String currentStepLabel;

  /// Called when user taps "Continuer" to advance to the next step.
  final VoidCallback? onAdvance;

  /// Called when user taps "Quitter le parcours".
  final VoidCallback? onQuit;

  /// Label for the goal (resolved from ARB by caller).
  final String goalLabel;

  const SequenceProgressCard({
    super.key,
    required this.run,
    required this.currentStepLabel,
    required this.goalLabel,
    this.onAdvance,
    this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final completed = run.completedCount;
    final total = run.totalCount;
    final progress = run.progress;

    return MintSurface(
      padding: const EdgeInsets.all(20),
      radius: 20,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Goal + Progress ─────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.route_outlined,
                size: 20,
                color: MintColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  goalLabel,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: MintColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$completed/$total',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MintColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Progress bar ────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: MintColors.lightBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(
                MintColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Current step ────────────────────────────────────
          Text(
            currentStepLabel,
            style: MintTextStyles.bodySmall(
              color: MintColors.textSecondary,
            ).copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),

          // ── CTA: Advance ────────────────────────────────────
          if (onAdvance != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAdvance,
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  foregroundColor: MintColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Pr\u00eat pour l\'\u00e9tape suivante',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // ── Secondary: Quit ─────────────────────────────────
          if (onQuit != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: onQuit,
                style: TextButton.styleFrom(
                  foregroundColor: MintColors.textMuted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Quitter le parcours',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
