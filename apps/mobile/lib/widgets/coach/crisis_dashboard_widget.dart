import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P7-E  Tableau de bord crise — 5 indicateurs vitaux
//  Charte : L3 (3 niveaux) + L1 (CHF/mois)
//  Source : LACI art. 27 (délais), LPP art. 5 (libre passage),
//           LP art. 93 (minimum vital)
// ────────────────────────────────────────────────────────────

enum CrisisStatus { ok, warning, critical }

class CrisisIndicator {
  const CrisisIndicator({
    required this.label,
    required this.emoji,
    required this.value,
    required this.unit,
    required this.status,
    required this.legalRef,
    this.action,
  });

  final String label;
  final String emoji;
  final String value;
  final String unit;
  final CrisisStatus status;
  final String legalRef;
  final String? action;
}

class CrisisDashboardWidget extends StatelessWidget {
  const CrisisDashboardWidget({
    super.key,
    required this.indicators,
    this.priorityAction,
  });

  final List<CrisisIndicator> indicators;
  final String? priorityAction;

  @override
  Widget build(BuildContext context) {
    final criticalCount = indicators.where((i) => i.status == CrisisStatus.critical).length;
    final warningCount = indicators.where((i) => i.status == CrisisStatus.warning).length;

    return Semantics(
      label: 'Tableau de bord crise chômage LPP budget réserves indicateurs vitaux',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(criticalCount, warningCount),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...indicators.map((ind) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildIndicatorRow(ind),
                  )),
                  if (priorityAction != null) ...[
                    const SizedBox(height: 4),
                    _buildPriorityAction(priorityAction!),
                  ],
                  const SizedBox(height: 16),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int criticalCount, int warningCount) {
    final overallStatus = criticalCount > 0
        ? CrisisStatus.critical
        : warningCount > 0
            ? CrisisStatus.warning
            : CrisisStatus.ok;

    final headerColor = _statusColor(overallStatus).withValues(alpha: 0.1);
    final headerLabel = criticalCount > 0
        ? '$criticalCount point${criticalCount > 1 ? 's' : ''} critique${criticalCount > 1 ? 's' : ''}'
        : warningCount > 0
            ? '$warningCount point${warningCount > 1 ? 's' : ''} à surveiller'
            : 'Situation stabilisée';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚨', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tableau de bord crise',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(overallStatus),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  headerLabel,
                  style: MintTextStyles.labelSmall(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${indicators.length} indicateurs vitaux — actions prioritaires en rouge.',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorRow(CrisisIndicator ind) {
    final color = _statusColor(ind.status);
    final bgColor = color.withValues(alpha: 0.07);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(ind.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ind.label,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${ind.value} ${ind.unit}',
                  style: MintTextStyles.labelSmall(color: MintColors.white).copyWith(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusDot(ind.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ind.legalRef,
            style: MintTextStyles.micro(color: MintColors.textSecondary),
          ),
          if (ind.action != null && ind.status != CrisisStatus.ok) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.arrow_forward, size: 12, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ind.action!,
                    style: MintTextStyles.labelSmall(color: color).copyWith(fontWeight: FontWeight.w700, height: 1.3),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusDot(CrisisStatus status) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _statusColor(status),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildPriorityAction(String action) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action prioritaire maintenant',
                  style: MintTextStyles.labelSmall(color: MintColors.scoreCritique).copyWith(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  action,
                  style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(CrisisStatus status) {
    switch (status) {
      case CrisisStatus.ok:
        return MintColors.scoreExcellent;
      case CrisisStatus.warning:
        return MintColors.scoreAttention;
      case CrisisStatus.critical:
        return MintColors.scoreCritique;
    }
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : LACI art. 27 (délai max chômage), LPP art. 5 (libre passage 30j), LP art. 93 (minimum vital).',
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
