import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/premium/mint_confidence_notice.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_signal_row.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Trajectory view for the Dossier/Profil tab.
///
/// Shows the user's financial trajectory: their declared goal, known profile
/// data, completed decisions from CapMemory, the current cap, and the
/// confidence score. All on a warm porcelaine background.
class TrajectoryView extends StatelessWidget {
  final CoachProfile profile;
  final CapMemory capMemory;

  const TrajectoryView({
    super.key,
    required this.profile,
    required this.capMemory,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return Container(
      color: MintColors.porcelaine,
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.lg,
        vertical: MintSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Ton objectif ──
          _GoalSection(profile: profile, s: s),

          const SizedBox(height: MintSpacing.xxl),

          // ── 2. Ce que MINT sait ──
          _KnownDataSection(profile: profile, s: s),

          const SizedBox(height: MintSpacing.xxl),

          // ── 3. Tes décisions ──
          if (capMemory.completedActions.isNotEmpty) ...[
            _DecisionsSection(capMemory: capMemory, s: s),
            const SizedBox(height: MintSpacing.xxl),
          ],

          // ── 4. Prochaine étape ──
          if (capMemory.lastCapServed != null) ...[
            _NextStepSection(capMemory: capMemory, s: s),
            const SizedBox(height: MintSpacing.xxl),
          ],

          // ── 5. Confiance ──
          _ConfidenceSection(profile: profile, s: s),

          const SizedBox(height: MintSpacing.xl),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  1. GOAL SECTION
// ════════════════════════════════════════════════════════════════

class _GoalSection extends StatelessWidget {
  final CoachProfile profile;
  final S s;

  const _GoalSection({required this.profile, required this.s});

  String _goalLabel() {
    switch (profile.goalA.type) {
      case GoalAType.retraite:
        return s.trajectoryGoalRetraite;
      case GoalAType.achatImmo:
        return s.trajectoryGoalAchatImmo;
      case GoalAType.independance:
        return s.trajectoryGoalIndependance;
      case GoalAType.debtFree:
        return s.trajectoryGoalDebtFree;
      case GoalAType.custom:
        return profile.goalA.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthsLeft = profile.goalA.moisRestants;
    final yearsLeft = (monthsLeft / 12).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.trajectoryGoalSectionTitle,
          style: MintTextStyles.headlineMedium(),
        ),
        const SizedBox(height: MintSpacing.md),
        MintSurface(
          tone: MintSurfaceTone.sauge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _goalLabel(),
                style: MintTextStyles.titleMedium(),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                s.trajectoryGoalHorizon(yearsLeft),
                style:
                    MintTextStyles.bodyMedium(color: MintColors.textSecondary),
              ),
              if (profile.goalA.targetAmount != null) ...[
                const SizedBox(height: MintSpacing.xs),
                Text(
                  s.trajectoryGoalTarget(
                    formatChfWithPrefix(profile.goalA.targetAmount!),
                  ),
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  2. KNOWN DATA SECTION
// ════════════════════════════════════════════════════════════════

class _KnownDataSection extends StatelessWidget {
  final CoachProfile profile;
  final S s;

  const _KnownDataSection({required this.profile, required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.trajectoryKnownSectionTitle,
          style: MintTextStyles.headlineMedium(),
        ),
        const SizedBox(height: MintSpacing.md),
        MintSurface(
          tone: MintSurfaceTone.blanc,
          child: Column(
            children: [
              MintSignalRow(
                label: s.trajectoryFieldAge,
                value: '${profile.age}\u00a0${s.trajectoryFieldAgeUnit}',
              ),
              MintSignalRow(
                label: s.trajectoryFieldRevenu,
                value: profile.salaireBrutMensuel > 0
                    ? formatChfWithPrefix(profile.revenuBrutAnnuel)
                    : s.trajectoryFieldIncomplete,
                valueColor: profile.salaireBrutMensuel > 0
                    ? null
                    : MintColors.textMuted,
              ),
              MintSignalRow(
                label: s.trajectoryFieldCanton,
                value: profile.canton.isNotEmpty
                    ? profile.canton.toUpperCase()
                    : s.trajectoryFieldIncomplete,
                valueColor: profile.canton.isNotEmpty
                    ? null
                    : MintColors.textMuted,
              ),
              MintSignalRow(
                label: s.trajectoryFieldLpp,
                value: profile.prevoyance.avoirLppTotal != null
                    ? formatChfWithPrefix(profile.prevoyance.avoirLppTotal!)
                    : s.trajectoryFieldIncomplete,
                valueColor: profile.prevoyance.avoirLppTotal != null
                    ? null
                    : MintColors.textMuted,
              ),
              MintSignalRow(
                label: s.trajectoryField3a,
                value: profile.prevoyance.totalEpargne3a > 0
                    ? formatChfWithPrefix(profile.prevoyance.totalEpargne3a)
                    : s.trajectoryFieldIncomplete,
                valueColor: profile.prevoyance.totalEpargne3a > 0
                    ? null
                    : MintColors.textMuted,
              ),
              MintSignalRow(
                label: s.trajectoryFieldConjoint,
                value: profile.isCouple
                    ? (profile.conjoint?.firstName ??
                        s.trajectoryFieldConjointYes)
                    : s.trajectoryFieldConjointNo,
                valueColor:
                    profile.isCouple ? null : MintColors.textMuted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  3. DECISIONS SECTION
// ════════════════════════════════════════════════════════════════

class _DecisionsSection extends StatelessWidget {
  final CapMemory capMemory;
  final S s;

  const _DecisionsSection({required this.capMemory, required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.trajectoryDecisionsSectionTitle,
          style: MintTextStyles.headlineMedium(),
        ),
        const SizedBox(height: MintSpacing.md),
        ...capMemory.completedActions.map(
          (action) => Padding(
            padding: const EdgeInsets.only(bottom: MintSpacing.sm),
            child: MintSurface(
              tone: MintSurfaceTone.craie,
              padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.md,
                vertical: MintSpacing.md,
              ),
              radius: 12,
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: MintColors.success,
                  ),
                  const SizedBox(width: MintSpacing.sm + 4),
                  Expanded(
                    child: Text(
                      _humanizeAction(action),
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Convert a raw action ID (e.g. "pillar_3a_2026") into a human-readable label.
  String _humanizeAction(String actionId) {
    return actionId
        .replaceAll('_', ' ')
        .replaceFirst(
          actionId[0],
          actionId[0].toUpperCase(),
        );
  }
}

// ════════════════════════════════════════════════════════════════
//  4. NEXT STEP SECTION
// ════════════════════════════════════════════════════════════════

class _NextStepSection extends StatelessWidget {
  final CapMemory capMemory;
  final S s;

  const _NextStepSection({required this.capMemory, required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.trajectoryNextStepSectionTitle,
          style: MintTextStyles.headlineMedium(),
        ),
        const SizedBox(height: MintSpacing.md),
        MintNarrativeCard(
          headline: capMemory.lastCapServed ?? '',
          body: s.trajectoryNextStepBody,
          tone: MintSurfaceTone.bleu,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  5. CONFIDENCE SECTION
// ════════════════════════════════════════════════════════════════

class _ConfidenceSection extends StatelessWidget {
  final CoachProfile profile;
  final S s;

  const _ConfidenceSection({required this.profile, required this.s});

  /// Quick heuristic confidence based on filled fields.
  /// Real confidence should come from EnhancedConfidence scorer,
  /// but this provides a lightweight fallback for the view.
  int _estimateConfidence() {
    int filled = 0;
    int total = 6;

    if (profile.salaireBrutMensuel > 0) filled++;
    if (profile.canton.isNotEmpty) filled++;
    if (profile.prevoyance.avoirLppTotal != null) filled++;
    if (profile.prevoyance.totalEpargne3a > 0) filled++;
    if (profile.isCouple && profile.conjoint != null) filled++;
    if (profile.prevoyance.anneesContribuees != null) filled++;

    return ((filled / total) * 100).round().clamp(5, 100);
  }

  @override
  Widget build(BuildContext context) {
    final pct = _estimateConfidence();
    final isLow = pct < 50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.trajectoryConfidenceSectionTitle,
          style: MintTextStyles.headlineMedium(),
        ),
        const SizedBox(height: MintSpacing.md),
        MintConfidenceNotice(
          percent: pct,
          message: isLow
              ? s.trajectoryConfidenceLowMessage
              : s.trajectoryConfidenceHighMessage,
          ctaLabel: isLow ? s.trajectoryConfidenceCta : null,
        ),
      ],
    );
  }
}
