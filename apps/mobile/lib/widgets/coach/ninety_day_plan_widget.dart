import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  NINETY DAY PLAN WIDGET — P6-B / S42 UX Redesign
// ────────────────────────────────────────────────────────────
//
//  Checklist de survie pour un·e indépendant·e en 4 phases.
//  Chaque phase a un délai et des conséquences.
//
//  Widget pur — aucune dépendance Provider.
//  Lois : L5 (une action) + L4 (raconte, ne montre pas)
// ────────────────────────────────────────────────────────────

/// Single action item in the 90-day plan.
class PlanAction {
  final String label;
  final String? consequence;
  final String? legalRef;
  final bool isCompleted;

  const PlanAction({
    required this.label,
    this.consequence,
    this.legalRef,
    this.isCompleted = false,
  });
}

/// One phase in the 90-day plan.
class PlanPhase {
  final String title;
  final String emoji;
  final String deadline;
  final Color urgencyColor;
  final List<PlanAction> actions;

  const PlanPhase({
    required this.title,
    required this.emoji,
    required this.deadline,
    required this.urgencyColor,
    required this.actions,
  });
}

class NinetyDayPlanWidget extends StatelessWidget {
  final List<PlanPhase> phases;
  final int completedCount;
  final int totalCount;

  const NinetyDayPlanWidget({
    super.key,
    required this.phases,
    this.completedCount = 0,
    this.totalCount = 0,
  });

  int get _total =>
      totalCount > 0 ? totalCount : phases.fold(0, (s, p) => s + p.actions.length);
  int get _done =>
      completedCount > 0 ? completedCount : phases.fold(
          0, (s, p) => s + p.actions.where((a) => a.isCompleted).length);

  @override
  Widget build(BuildContext context) {
    if (phases.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: 'Plan 90 jours ind\u00e9pendant. $_done sur $_total actions compl\u00e9t\u00e9es.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Plan 90 jours \u2014 Checklist de survie',
                    style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MintColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_done/$_total',
                    style: MintTextStyles.labelSmall(color: MintColors.primary).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Les 90 premiers jours d\u00e9finissent ta protection',
              style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontSize: 12),
            ),

            const SizedBox(height: 16),

            // ── Progress bar ──
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      color: MintColors.surface,
                    ),
                    FractionallySizedBox(
                      widthFactor: _total > 0 ? _done / _total : 0,
                      child: Container(color: MintColors.scoreExcellent),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Phases ──
            ...phases.asMap().entries.map((e) => _buildPhase(e.key, e.value)),

            const SizedBox(height: 12),
            Text(
              'R\u00e9f\u00e9rences\u00a0: LEI, LAVS art. 12, LACI, LAA art. 4. '
              'Outil \u00e9ducatif \u2014 ne constitue pas un conseil financier (LSFin).',
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhase(int index, PlanPhase phase) {
    return Padding(
      padding: EdgeInsets.only(bottom: index < phases.length - 1 ? 14 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase header
          Row(
            children: [
              Text(phase.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  phase.title,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: phase.urgencyColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  phase.deadline,
                  style: MintTextStyles.micro(color: phase.urgencyColor).copyWith(fontWeight: FontWeight.w600, fontStyle: FontStyle.normal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Action items
          ...phase.actions.map(_buildAction),
        ],
      ),
    );
  }

  Widget _buildAction(PlanAction action) {
    return Padding(
      padding: const EdgeInsets.only(left: 30, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            action.isCompleted
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            size: 16,
            color: action.isCompleted
                ? MintColors.scoreExcellent
                : MintColors.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.label,
                  style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(fontSize: 12, decoration: action.isCompleted ? TextDecoration.lineThrough : null),
                ),
                if (action.consequence != null)
                  Text(
                    action.consequence!,
                    style: MintTextStyles.micro(color: MintColors.scoreCritique),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
