import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  CONCUBINAGE vs MARRIAGE DECISION MATRIX
// ────────────────────────────────────────────────────────────
//
//  Stunning comparison grid with animated indicators:
//    - Two columns: Mariage vs Concubinage
//    - Each row: animated advantage indicator
//    - Staggered entry animation (100ms per row)
//    - Bottom: animated score counter
//    - Neutral conclusion with balanced scale icon
// ────────────────────────────────────────────────────────────

/// Which side has the advantage for a given criteria.
enum Advantage { marriage, concubinage, neutral }

/// A single comparison criteria row.
class ComparisonCriteria {
  final String label;
  final String marriageLabel;
  final String concubinageLabel;
  final Advantage advantage;

  /// For bar-type criteria: relative advantage (0.0 to 1.0).
  final double? marriageScore;
  final double? concubinageScore;

  /// Icon to display for this criteria.
  final IconData icon;

  const ComparisonCriteria({
    required this.label,
    required this.marriageLabel,
    required this.concubinageLabel,
    required this.advantage,
    this.marriageScore,
    this.concubinageScore,
    required this.icon,
  });
}

class ConcubinageDecisionMatrix extends StatefulWidget {
  final List<ComparisonCriteria> criteria;

  /// Optional callback when a criteria row is tapped for detail.
  final ValueChanged<ComparisonCriteria>? onCriteriaTap;

  const ConcubinageDecisionMatrix({
    super.key,
    required this.criteria,
    this.onCriteriaTap,
  });

  @override
  State<ConcubinageDecisionMatrix> createState() =>
      _ConcubinageDecisionMatrixState();
}

class _ConcubinageDecisionMatrixState extends State<ConcubinageDecisionMatrix>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _staggerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 600 + widget.criteria.length * 100,
      ),
    );
    _staggerAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _marriageWins =>
      widget.criteria.where((c) => c.advantage == Advantage.marriage).length;

  int get _concubinageWins =>
      widget.criteria
          .where((c) => c.advantage == Advantage.concubinage)
          .length;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${S.of(context)!.concubinageDecisionMatrixTitle}. ${S.of(context)!.concubinageDecisionMatrixColumnMarriage}: $_marriageWins, ${S.of(context)!.concubinageDecisionMatrixColumnConcubinage}: $_concubinageWins.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.maxWidth,
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MintColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: MintColors.primary.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                _buildColumnLabels(),
                ..._buildCriteriaRows(),
                _buildScoreCounter(),
                _buildConclusion(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.compare_arrows,
              color: MintColors.info,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.concubinageDecisionMatrixTitle,
                  style: MintTextStyles.titleMedium(),
                ),
                Text(
                  S.of(context)!.concubinageDecisionMatrixSubtitle,
                  style: MintTextStyles.bodyMedium().copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnLabels() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          const SizedBox(width: 36),
          Expanded(
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: MintColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  S.of(context)!.concubinageDecisionMatrixColumnMarriage,
                  style: MintTextStyles.labelSmall(color: MintColors.info).copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: MintColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  S.of(context)!.concubinageDecisionMatrixColumnConcubinage,
                  style: MintTextStyles.labelSmall(color: MintColors.warning).copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCriteriaRows() {
    final rows = <Widget>[];
    for (var i = 0; i < widget.criteria.length; i++) {
      rows.add(_buildCriteriaRow(widget.criteria[i], i));
    }
    return rows;
  }

  Widget _buildCriteriaRow(ComparisonCriteria criteria, int index) {
    final totalItems = widget.criteria.length;
    // Stagger: each row appears 100ms apart
    final startFraction = index / (totalItems + 2);
    final endFraction = (index + 2) / (totalItems + 2);

    return AnimatedBuilder(
      animation: _staggerAnimation,
      builder: (context, _) {
        final rowProgress =
            ((_staggerAnimation.value - startFraction) /
                    (endFraction - startFraction))
                .clamp(0.0, 1.0);

        return Opacity(
          opacity: rowProgress,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - rowProgress)),
            child: GestureDetector(
              onTap: widget.onCriteriaTap != null
                  ? () => widget.onCriteriaTap!(criteria)
                  : null,
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    // Criteria label with icon
                    Row(
                      children: [
                        Icon(criteria.icon,
                            size: 16, color: MintColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            criteria.label,
                            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Comparison indicators
                    Row(
                      children: [
                        // Marriage side
                        Expanded(
                          child: _buildIndicator(
                            label: criteria.marriageLabel,
                            isAdvantage:
                                criteria.advantage == Advantage.marriage,
                            score: criteria.marriageScore,
                            color: MintColors.info,
                            progress: rowProgress,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Center divider with advantage icon
                        _buildAdvantageIcon(criteria.advantage, rowProgress),
                        const SizedBox(width: 8),
                        // Concubinage side
                        Expanded(
                          child: _buildIndicator(
                            label: criteria.concubinageLabel,
                            isAdvantage:
                                criteria.advantage == Advantage.concubinage,
                            score: criteria.concubinageScore,
                            color: MintColors.warning,
                            progress: rowProgress,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIndicator({
    required String label,
    required bool isAdvantage,
    required double? score,
    required Color color,
    required double progress,
  }) {
    return Column(
      children: [
        if (score != null)
          // Bar indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score * progress,
              backgroundColor: MintColors.lightBorder,
              color: isAdvantage ? color : MintColors.textMuted,
              minHeight: 6,
            ),
          )
        else
          // Check / cross indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isAdvantage
                  ? MintColors.success.withValues(alpha: 0.15)
                  : MintColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAdvantage ? Icons.check : Icons.close,
              size: 16,
              color: isAdvantage ? MintColors.success : MintColors.error,
            ),
          ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: MintTextStyles.micro().copyWith(
            fontStyle: FontStyle.normal,
            fontWeight: isAdvantage ? FontWeight.w600 : FontWeight.w400,
            color:
                isAdvantage ? MintColors.textPrimary : MintColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildAdvantageIcon(Advantage advantage, double progress) {
    final Color bgColor;
    final IconData iconData;
    switch (advantage) {
      case Advantage.marriage:
        bgColor = MintColors.info;
        iconData = Icons.arrow_back;
      case Advantage.concubinage:
        bgColor = MintColors.warning;
        iconData = Icons.arrow_forward;
      case Advantage.neutral:
        bgColor = MintColors.textMuted;
        iconData = Icons.drag_handle;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15 * progress),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 12, color: bgColor),
    );
  }

  Widget _buildScoreCounter() {
    return AnimatedBuilder(
      animation: _staggerAnimation,
      builder: (context, _) {
        final progress = _staggerAnimation.value;
        final mScore = (_marriageWins * progress).round();
        final cScore = (_concubinageWins * progress).round();

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: MintColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // Marriage score
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$mScore',
                      style: MintTextStyles.displayMedium(color: MintColors.white).copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      S.of(context)!.concubinageDecisionMatrixColumnMarriage,
                      style: MintTextStyles.labelSmall(color: MintColors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                width: 1,
                height: 40,
                color: MintColors.white.withValues(alpha: 0.2),
              ),
              // Concubinage score
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$cScore',
                      style: MintTextStyles.displayMedium(color: MintColors.white).copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      S.of(context)!.concubinageDecisionMatrixColumnConcubinage,
                      style: MintTextStyles.labelSmall(color: MintColors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConclusion() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: MintColors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.balance,
                size: 18,
                color: MintColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context)!.concubinageDecisionMatrixConclusionTitle,
                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    S.of(context)!.concubinageDecisionMatrixConclusionDesc,
                    style: MintTextStyles.bodyMedium().copyWith(
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
