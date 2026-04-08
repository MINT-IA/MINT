/// FinancialPlanCard — Persistent plan card for the Aujourd'hui tab.
///
/// Displays the user's current [FinancialPlan] between Section 1
/// (ChiffreVivant) and Section 2 (ItineraireAlternatif) on MintHomeScreen.
///
/// Features:
///   - Hero monthly CHF (displayMedium)
///   - Goal prefix + description
///   - Target date
///   - Progress bar (0% in Phase 4 — no check-ins yet)
///   - "Voir le détail" toggle to expand milestones + confidence bands
///   - Stale state: amber badge + "Recalculer" CTA
///
/// Threat T-04-10: "Recalculer" passes a pre-formatted i18n prompt via
/// [onRecalculate]; the user must explicitly tap Send in the coach.
///
/// Compliance: educational tool only (LSFin). No advice, no ranking.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Persistent financial plan card shown on the Aujourd'hui tab.
///
/// Hidden entirely when [hasPlan] is false — the caller (MintHomeScreen)
/// is responsible for gating visibility via `if (provider.hasPlan)`.
class FinancialPlanCard extends StatefulWidget {
  /// The current persisted plan. Must not be null when this widget is shown.
  final FinancialPlan plan;

  /// When true, shows amber "Profil modifié" badge and "Recalculer" CTA.
  final bool isStale;

  /// Called when user taps "Recalculer". Caller opens coach with pre-seeded text.
  /// The pre-seeded text is derived here and passed via the callback indirection
  /// in MintHomeScreen.
  final void Function(String recalculatePrompt) onRecalculate;

  const FinancialPlanCard({
    super.key,
    required this.plan,
    required this.isStale,
    required this.onRecalculate,
  });

  @override
  State<FinancialPlanCard> createState() => _FinancialPlanCardState();
}

class _FinancialPlanCardState extends State<FinancialPlanCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final plan = widget.plan;

    // Number formatters
    final chfFmt = NumberFormat('#,##0', 'fr_CH');
    final dateFmt = DateFormat('MMMM yyyy', 'fr');
    final quarterFmt = DateFormat('QQQ yyyy', 'fr');

    return Container(
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.border.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Goal row: label + description + stale badge ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${l10n.planCard_goalPrefix} ',
                        style: MintTextStyles.titleMedium(
                          color: MintColors.textSecondary,
                        ),
                      ),
                      TextSpan(
                        text: plan.goalDescription,
                        style: MintTextStyles.titleMedium(
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.isStale) ...[
                const SizedBox(width: MintSpacing.sm),
                _StaleBadge(label: l10n.planCard_staleBadge),
              ],
            ],
          ),

          const SizedBox(height: MintSpacing.xs),

          // ── Hero: monthly CHF target ──
          Text(
            "${chfFmt.format(plan.monthlyTarget).replaceAll(',', '\u2019')} CHF / mois",
            style: MintTextStyles.displayMedium(
              color: MintColors.textPrimary,
            ),
          ),

          const SizedBox(height: MintSpacing.sm),

          // ── Target date ──
          Text(
            l10n.planCard_targetDate(dateFmt.format(plan.targetDate)),
            style: MintTextStyles.bodyMedium(
              color: MintColors.textMuted,
            ),
          ),

          const SizedBox(height: MintSpacing.md),

          // ── Progress bar (0% — Phase 4: no check-ins yet) ──
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: 0.0,
              minHeight: 6,
              backgroundColor: MintColors.border.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(MintColors.success),
            ),
          ),

          const SizedBox(height: MintSpacing.sm),

          // ── Caption row: progress % + CTA button ──
          Row(
            children: [
              Text(
                l10n.planCard_progressCaption('0'),
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textMuted,
                ),
              ),
              const Spacer(),
              _CtaButton(
                isStale: widget.isStale,
                isExpanded: _isExpanded,
                ctaDetail: l10n.planCard_ctaDetail,
                ctaHide: l10n.planCard_ctaHide,
                ctaRecalculate: l10n.planCard_ctaRecalculate,
                onDetailTap: () => setState(() => _isExpanded = !_isExpanded),
                onRecalculateTap: () => widget.onRecalculate(
                  l10n.planCard_recalculatePrompt(plan.goalDescription),
                ),
              ),
            ],
          ),

          // ── Expanded detail section ──
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isExpanded ? 1.0 : 0.0,
              child: _isExpanded
                  ? _ExpandedDetail(
                      plan: plan,
                      quarterFmt: quarterFmt,
                      chfFmt: chfFmt,
                      l10n: l10n,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Amber badge shown when the plan is stale (profile changed since generation).
class _StaleBadge extends StatelessWidget {
  final String label;

  const _StaleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.sm,
        vertical: MintSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: MintTextStyles.bodyMedium(color: MintColors.warning),
      ),
    );
  }
}

/// CTA button that changes label based on state (normal vs stale, expanded vs collapsed).
class _CtaButton extends StatelessWidget {
  final bool isStale;
  final bool isExpanded;
  final String ctaDetail;
  final String ctaHide;
  final String ctaRecalculate;
  final VoidCallback onDetailTap;
  final VoidCallback onRecalculateTap;

  const _CtaButton({
    required this.isStale,
    required this.isExpanded,
    required this.ctaDetail,
    required this.ctaHide,
    required this.ctaRecalculate,
    required this.onDetailTap,
    required this.onRecalculateTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isStale) {
      return TextButton(
        onPressed: onRecalculateTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.sm,
            vertical: MintSpacing.xs,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          ctaRecalculate,
          style: MintTextStyles.bodyMedium(color: MintColors.warning),
        ),
      );
    }

    return TextButton(
      onPressed: onDetailTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.sm,
          vertical: MintSpacing.xs,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        isExpanded ? ctaHide : ctaDetail,
        style: MintTextStyles.bodyMedium(color: MintColors.primary),
      ),
    );
  }
}

/// Expanded detail section showing milestones, confidence bands, and disclaimer.
class _ExpandedDetail extends StatelessWidget {
  final FinancialPlan plan;
  final DateFormat quarterFmt;
  final NumberFormat chfFmt;
  final S l10n;

  const _ExpandedDetail({
    required this.plan,
    required this.quarterFmt,
    required this.chfFmt,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final milestones = plan.milestones.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: MintSpacing.md),

        // ── Milestones heading ──
        Text(
          l10n.planCard_milestonesHeading,
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),

        const SizedBox(height: MintSpacing.xs),

        // ── Milestone rows ──
        ...milestones.map((m) => _MilestoneRow(
              date: quarterFmt.format(m.targetDate),
              amount: '${chfFmt.format(m.targetAmount).replaceAll(',', '\u2019')} CHF',
              description: m.description,
            )),

        const SizedBox(height: MintSpacing.md),

        // ── Confidence bands (only when available) ──
        if (plan.projectedLow != null && plan.projectedHigh != null)
          Padding(
            padding: const EdgeInsets.only(bottom: MintSpacing.sm),
            child: Text(
              l10n.planCard_confidenceBands(
                chfFmt.format(plan.projectedLow!).replaceAll(',', '\u2019'),
                chfFmt.format(plan.projectedOutcome).replaceAll(',', '\u2019'),
                chfFmt.format(plan.projectedHigh!).replaceAll(',', '\u2019'),
              ),
              style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        // ── Disclaimer ──
        Text(
          l10n.planCard_disclaimer,
          style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),

        const SizedBox(height: MintSpacing.xs),
      ],
    );
  }
}

/// A single milestone row: date | description | CHF amount.
class _MilestoneRow extends StatelessWidget {
  final String date;
  final String amount;
  final String description;

  const _MilestoneRow({
    required this.date,
    required this.amount,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              date,
              style: MintTextStyles.bodyMedium(color: MintColors.textMuted),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              description,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
          ),
          const SizedBox(width: MintSpacing.sm),
          Text(
            amount,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
