import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P1-J  Le Dashboard progressif — 3 vues selon la maturité
//  Charte : L3 (3 niveaux max)
//  Source : ADR-20260223-archetype-driven-retirement.md
//           (confidenceScore pilote la profondeur d'affichage)
// ────────────────────────────────────────────────────────────

/// Represents one metric visible in a given level.
class DashboardMetric {
  const DashboardMetric({
    required this.label,
    required this.emoji,
    required this.value,
    required this.unit,
    required this.minLevel,
    this.color,
    this.note,
  });

  final String label;
  final String emoji;
  final String value;
  final String unit;
  final int minLevel; // 1, 2 or 3
  final Color? color;
  final String? note;
}

class ProgressiveDashboardWidget extends StatefulWidget {
  const ProgressiveDashboardWidget({
    super.key,
    required this.confidenceScore,
    required this.metrics,
    required this.heroMonthlyRente,
    this.nextActionLabel,
    this.nextActionDetail,
  });

  final int confidenceScore; // 0-100
  final List<DashboardMetric> metrics;
  final double heroMonthlyRente;
  final String? nextActionLabel;
  final String? nextActionDetail;

  @override
  State<ProgressiveDashboardWidget> createState() =>
      _ProgressiveDashboardWidgetState();
}

class _ProgressiveDashboardWidgetState extends State<ProgressiveDashboardWidget> {
  late int _level;

  @override
  void initState() {
    super.initState();
    _level = _levelFromScore(widget.confidenceScore);
  }

  static int _levelFromScore(int score) {
    if (score >= 80) return 3;
    if (score >= 50) return 2;
    return 1;
  }

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  String get _levelLabel {
    switch (_level) {
      case 1:
        return 'Novice';
      case 2:
        return 'Intermédiaire';
      case 3:
        return 'Expert';
      default:
        return 'Novice';
    }
  }

  Color get _levelColor {
    switch (_level) {
      case 1:
        return MintColors.info;
      case 2:
        return MintColors.scoreAttention;
      case 3:
        return MintColors.scoreExcellent;
      default:
        return MintColors.info;
    }
  }

  List<DashboardMetric> get _visibleMetrics =>
      widget.metrics.where((m) => m.minLevel <= _level).toList();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Dashboard progressif retraite 3 niveaux confiance novice expert',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildLevelSelector(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(),
                  const SizedBox(height: 16),
                  if (_visibleMetrics.isNotEmpty) ...[
                    _buildMetricsGrid(),
                    const SizedBox(height: 16),
                  ],
                  if (widget.nextActionLabel != null) _buildNextAction(),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Text('📊', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ton tableau de bord retraite',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Confiance : ${widget.confidenceScore}% — Vue : $_levelLabel',
                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSelector() {
    final levels = ['Novice', 'Intermédiaire', 'Expert'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: MintColors.appleSurface,
        border: Border(bottom: BorderSide(color: MintColors.lightBorder)),
      ),
      child: Row(
        children: [
          Text(
            'Vue :',
            style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
          ),
          const SizedBox(width: 10),
          ...List.generate(3, (i) {
            final lvl = i + 1;
            final selected = _level == lvl;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => _level = lvl),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? _levelColor : MintColors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? _levelColor : MintColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    levels[i],
                    style: MintTextStyles.labelSmall(color: selected ? MintColors.white : MintColors.textSecondary).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ton salaire après 65',
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'CHF ${_fmt(widget.heroMonthlyRente)}/mois',
            style: MintTextStyles.displayMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'AVS + LPP · Projection scénario de base',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final metrics = _visibleMetrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${metrics.length} indicateurs — Vue $_levelLabel',
              style: MintTextStyles.labelMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
            ),
            if (_level < 3)
              GestureDetector(
                onTap: () => setState(() => _level = _level + 1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Plus de détails',
                      style: MintTextStyles.labelSmall(color: MintColors.primary),
                    ),
                    const Icon(Icons.chevron_right, color: MintColors.primary, size: 16),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ...metrics.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildMetricRow(m),
        )),
      ],
    );
  }

  Widget _buildMetricRow(DashboardMetric m) {
    final color = m.color ?? MintColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(m.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.label, style: MintTextStyles.labelMedium(color: MintColors.textPrimary)),
                if (m.note != null)
                  Text(m.note!, style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal)),
              ],
            ),
          ),
          Text(
            '${m.value} ${m.unit}',
            style: MintTextStyles.bodyMedium(color: color).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildNextAction() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreExcellent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreExcellent.withValues(alpha: 0.25)),
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
                  widget.nextActionLabel!,
                  style: MintTextStyles.bodySmall(color: MintColors.scoreExcellent).copyWith(fontWeight: FontWeight.w700),
                ),
                if (widget.nextActionDetail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.nextActionDetail!,
                    style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Niveaux basés sur le score de confiance du profil. Projection indicative.',
      style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
    );
  }
}
