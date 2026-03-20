import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P3-A  Bilan de match — Louer vs Acheter
//  Charte : L6 (chiffre-choc résultat en premier) + L2 (avant/après) + L4 (narration)
//  Source : FINMA/ASB (taux 5%, amort. 1%/an), CO art. 261ss, CC
// ────────────────────────────────────────────────────────────

class RentVsBuyScoreboardWidget extends StatelessWidget {
  const RentVsBuyScoreboardWidget({
    super.key,
    required this.propertyPrice,
    required this.equity,
    required this.monthlyRent,
    required this.mortgageMonthly,
    this.years = 20,
    this.appreciationRate = 0.02,
    this.investmentReturnRate = 0.04,
  });

  final double propertyPrice;
  final double equity;
  final double monthlyRent;
  final double mortgageMonthly;
  final int years;
  final double appreciationRate;
  final double investmentReturnRate;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000000) {
      final m = n ~/ 1000000;
      final r = (n % 1000000) ~/ 1000;
      return r == 0 ? "${m}M" : "$m'${r.toString().padLeft(3, '0')}'000";
    }
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  // ── Calculs patrimoniaux ──────────────────────────────────

  double get _buyerPatrimony {
    final propertyValue = propertyPrice * pow(1 + appreciationRate, years);
    final initialMortgage = propertyPrice - equity;
    final annualAmort = propertyPrice * 0.01; // FINMA 1%/an
    final amortized = min(initialMortgage, annualAmort * years);
    final remaining = initialMortgage - amortized;
    return propertyValue - remaining;
  }

  double get _renterPatrimony {
    // Equity invested at investmentReturnRate
    final equityFV = equity * pow(1 + investmentReturnRate, years);
    // Monthly savings: difference if mortgage > rent
    final monthlySavings = max(0.0, mortgageMonthly - monthlyRent);
    final r = investmentReturnRate / 12;
    final n = years * 12;
    final savingsFV = r > 0
        ? monthlySavings * (pow(1 + r, n) - 1) / r
        : monthlySavings * n.toDouble();
    return equityFV + savingsFV;
  }

  /// Break-even in years (buyer catches up with renter)
  int get _breakEvenYears {
    for (var y = 1; y <= 40; y++) {
      final bv = propertyPrice * pow(1 + appreciationRate, y);
      final initialMortgage = propertyPrice - equity;
      final amortized = min(initialMortgage, propertyPrice * 0.01 * y);
      final buyer = bv - (initialMortgage - amortized);

      final equityFV = equity * pow(1 + investmentReturnRate, y);
      final monthly = max(0.0, mortgageMonthly - monthlyRent);
      final r = investmentReturnRate / 12;
      final n = y * 12;
      final savingsFV = r > 0
          ? monthly * (pow(1 + r, n) - 1) / r
          : monthly * n.toDouble();
      final renter = equityFV + savingsFV;

      if (buyer >= renter) return y;
    }
    return 40;
  }

  bool get _buyerWins => _buyerPatrimony >= _renterPatrimony;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Bilan de match louer acheter patrimoine break-even FINMA amortissement',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScoreCards(),
                  const SizedBox(height: 16),
                  _buildBreakEven(),
                  const SizedBox(height: 16),
                  _buildMonthlyCosts(),
                  const SizedBox(height: 16),
                  _buildKeyInsight(),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚖️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Grand Match · Louer vs Acheter',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dans $years ans, voici ton patrimoine selon ton choix aujourd\'hui.',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCards() {
    const winnerColor = MintColors.scoreExcellent;
    const loserColor = MintColors.textSecondary;

    return Row(
      children: [
        Expanded(
          child: _buildPatrimonyCard(
            emoji: '🏠',
            label: 'PROPRIÉTAIRE',
            patrimony: _buyerPatrimony,
            color: _buyerWins ? winnerColor : loserColor,
            isWinner: _buyerWins,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'vs',
            style: MintTextStyles.titleMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: _buildPatrimonyCard(
            emoji: '🔑',
            label: 'LOCATAIRE',
            patrimony: _renterPatrimony,
            color: !_buyerWins ? winnerColor : loserColor,
            isWinner: !_buyerWins,
          ),
        ),
      ],
    );
  }

  Widget _buildPatrimonyCard({
    required String emoji,
    required String label,
    required double patrimony,
    required Color color,
    required bool isWinner,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isWinner ? 0.4 : 0.15),
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          if (isWinner)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '🏆 GAGNANT',
                style: MintTextStyles.micro(color: MintColors.white).copyWith(fontSize: 9, fontWeight: FontWeight.w800, fontStyle: FontStyle.normal),
              ),
            ),
          Text(
            'CHF ${_fmt(patrimony)}',
            style: MintTextStyles.bodyMedium(color: color).copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600, fontStyle: FontStyle.normal),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakEven() {
    final be = _breakEvenYears;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Text('📍', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Break-even à $be ans',
                  style: MintTextStyles.bodySmall(color: MintColors.info).copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Avant $be ans : louer est plus rentable. Après : acheter prend l\'avantage.',
                  style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCosts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coûts mensuels comparés',
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _buildCostRow('🏠 Mensualité hypothèque', mortgageMonthly,
            sub: 'dont intérêts + amortissement'),
        const SizedBox(height: 6),
        _buildCostRow('🔑 Loyer mensuel', monthlyRent,
            sub: 'sans charges locatives'),
        const SizedBox(height: 6),
        _buildCostRow(
          '➕ Différence mensuelle',
          (mortgageMonthly - monthlyRent).abs(),
          sub: mortgageMonthly > monthlyRent
              ? 'surcoût propriétaire (investissable par locataire)'
              : 'économie propriétaire',
          isHighlight: true,
        ),
      ],
    );
  }

  Widget _buildCostRow(String label, double value,
      {String? sub, bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: isHighlight
          ? BoxDecoration(
              color: MintColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: MintColors.primary.withValues(alpha: 0.15)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(fontSize: 12, fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
                  ),
              ],
            ),
          ),
          Text(
            'CHF ${_fmt(value)}',
            style: MintTextStyles.bodySmall(color: isHighlight ? MintColors.primary : MintColors.textPrimary).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyInsight() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreAttention.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: MintColors.scoreAttention.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 La vraie question',
            style: MintTextStyles.bodySmall(color: MintColors.scoreAttention).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'La question n\'est pas "louer ou acheter" — c\'est '
            '"Est-ce que je resterai $_breakEvenYears+ ans dans ce bien ?" '
            'Si oui, acheter a du sens financièrement. Sinon, louer et investir la différence.',
            style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Hypothèses : appréciation immobilière ${ (appreciationRate * 100).round()}%/an, '
      'rendement placement ${(investmentReturnRate * 100).round()}%/an, amortissement FINMA 1%/an. '
      'Source : FINMA/ASB (taux théorique 5%), CO art. 261ss.',
      style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
    );
  }
}
