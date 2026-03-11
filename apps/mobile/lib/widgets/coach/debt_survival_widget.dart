import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P10-F  Le Mode survie MINT — dashboard crise dette
//  Charte : L3 (3 KPIs) + L5 (1 action)
//  Source : LP art. 93 (minimum vital), LPP OPP3 (suspension 3a)
// ────────────────────────────────────────────────────────────

class DebtSurvivalWidget extends StatelessWidget {
  const DebtSurvivalWidget({
    super.key,
    required this.totalDebt,
    required this.monthlyMargin,
    required this.daysSinceLastLate,
    required this.monthlyIncome,
  });

  final double totalDebt;
  final double monthlyMargin;
  final int daysSinceLastLate;
  final double monthlyIncome;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  // Debt-to-annual-income ratio
  double get _debtRatio => monthlyIncome > 0 ? totalDebt / (monthlyIncome * 12) : 0;
  bool get _isCritical => _debtRatio > 0.30 || monthlyMargin < 0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mode survie dette ratio KPIs actions urgentes Dettes Conseils',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isCritical
                ? MintColors.scoreCritique.withValues(alpha: 0.5)
                : MintColors.lightBorder,
            width: _isCritical ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKpis(),
                  const SizedBox(height: 16),
                  _buildActions(),
                  const SizedBox(height: 16),
                  _buildHelpLine(),
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
        color: _isCritical
            ? MintColors.scoreCritique.withValues(alpha: 0.1)
            : MintColors.scoreAttention.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _isCritical ? '🆘' : '⚠️',
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mode survie MINT',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              if (_isCritical)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MintColors.scoreCritique,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ACTIVÉ',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isCritical
                ? 'Ton ratio dette/revenu est critique. 3 actions pour stabiliser.'
                : 'Surveille ces 3 indicateurs. Agis avant que la situation empire.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final ratioPercent = (_debtRatio * 100).round();
    final ratioStatus = _debtRatio > 0.30
        ? MintColors.scoreCritique
        : _debtRatio > 0.15
            ? MintColors.scoreAttention
            : MintColors.scoreExcellent;

    final marginStatus = monthlyMargin < 0
        ? MintColors.scoreCritique
        : monthlyMargin < 200
            ? MintColors.scoreAttention
            : MintColors.scoreExcellent;

    final lateStatus = daysSinceLastLate == 0
        ? MintColors.scoreExcellent
        : daysSinceLastLate < 30
            ? MintColors.scoreAttention
            : MintColors.scoreCritique;

    return Row(
      children: [
        Expanded(child: _buildKpiCard(
          label: 'Dette totale',
          value: 'CHF ${_fmt(totalDebt)}',
          sub: '$ratioPercent% du revenu annuel',
          color: ratioStatus,
          emoji: '💳',
        )),
        const SizedBox(width: 8),
        Expanded(child: _buildKpiCard(
          label: 'Marge mensuelle',
          value: 'CHF ${_fmt(monthlyMargin.abs())}',
          sub: monthlyMargin < 0 ? 'déficit' : 'disponible',
          color: marginStatus,
          emoji: '📈',
        )),
        const SizedBox(width: 8),
        Expanded(child: _buildKpiCard(
          label: 'Dernier retard',
          value: daysSinceLastLate == 0 ? 'Aucun' : '$daysSinceLastLate j',
          sub: daysSinceLastLate == 0 ? 'à jour' : 'depuis',
          color: lateStatus,
          emoji: '⏰',
        )),
      ],
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required String sub,
    required Color color,
    required String emoji,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            sub,
            style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final actions = [
      (
        emoji: '✂️',
        title: 'Couper les loisirs',
        detail: 'Streaming, sorties, abonnements — libère CHF 200-400/mois immédiatement.',
        urgency: CrisisUrgency.high,
      ),
      (
        emoji: '⏸️',
        title: 'Suspendre le versement 3a',
        detail: 'Légal. Reprends dès que possible — chaque mois compte, mais pas plus que manger.',
        urgency: CrisisUrgency.medium,
      ),
      (
        emoji: '📞',
        title: 'Appeler Dettes Conseils',
        detail: '0800 40 40 40 — gratuit, confidentiel, sans jugement. 1 appel change tout.',
        urgency: CrisisUrgency.critical,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tes 3 actions maintenant',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...actions.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildActionCard(a.emoji, a.title, a.detail, a.urgency),
        )),
      ],
    );
  }

  Widget _buildActionCard(String emoji, String title, String detail, CrisisUrgency urgency) {
    final color = urgency == CrisisUrgency.critical
        ? MintColors.scoreCritique
        : urgency == CrisisUrgency.high
            ? MintColors.scoreAttention
            : MintColors.info;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpLine() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Text('📞', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dettes Conseils Suisse',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: MintColors.info,
                  ),
                ),
                Text(
                  '0800 40 40 40 · Gratuit · Confidentiel · Sans jugement',
                  style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
                ),
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
      'Source : LP art. 93 (minimum vital insaisissable). '
      'Ratio critique : dette > 30% du revenu annuel.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

enum CrisisUrgency { critical, high, medium }
