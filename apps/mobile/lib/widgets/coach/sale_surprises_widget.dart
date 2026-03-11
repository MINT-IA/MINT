import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  P15-A  Les 3 surprises de la vente immobilière
//  Charte : L6 (Chiffre-choc) + L4 (Raconte)
//  Source : LIFD art. 12 (impôt gain immobilier), LPP art. 30c (EPL)
// ────────────────────────────────────────────────────────────

class SaleSurprisesWidget extends StatelessWidget {
  const SaleSurprisesWidget({
    super.key,
    required this.salePrice,
    required this.purchasePrice,
    required this.eplWithdrawn,
    required this.holdingYears,
    this.canton = 'Vaud',
  });

  final double salePrice;
  final double purchasePrice;
  final double eplWithdrawn;
  final int holdingYears;
  final String canton;

  double get _capitalGain => (salePrice - purchasePrice).clamp(0, double.infinity);

  // Approximate: gain tax decreases with holding years, roughly 0.5% per year after 5 years
  double get _gainTaxRate {
    if (holdingYears < 2) return 0.35;
    if (holdingYears < 5) return 0.30;
    if (holdingYears < 10) return 0.25;
    if (holdingYears < 15) return 0.18;
    if (holdingYears < 20) return 0.12;
    return 0.08;
  }

  double get _gainTax => _capitalGain * _gainTaxRate;
  double get _eplReturn => eplWithdrawn; // must reimburse 3a/LPP withdrawn
  double get _notaryFees => salePrice * 0.015;
  // Hypothèse illustrative : solde hypothécaire = 60 % du prix de vente.
  // En réalité varie selon l'ancienneté du crédit. Remplacer par le solde réel.
  double get _mortgage => salePrice * 0.60;
  double get _netReal =>
      salePrice - _mortgage - _gainTax - _eplReturn - _notaryFees;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Surprises vente immobilière impôt gain capital EPL remploi',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
                  _buildActs(),
                  const SizedBox(height: 16),
                  _buildNetCascade(),
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
      decoration: const BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏠', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Les 3 surprises de la vente',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tu vends ${formatChfWithPrefix(salePrice)}. Tu penses toucher ${formatChfWithPrefix(_netReal + _gainTax)}. '
            'Tu reçois ${formatChfWithPrefix(_netReal)}.',
            style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildActs() {
    final acts = [
      (
        number: 'Acte 1',
        emoji: '📊',
        title: 'Impôt sur le gain en capital',
        detail:
            'Plus-value de ${formatChfWithPrefix(_capitalGain)} × ${(_gainTaxRate * 100).toStringAsFixed(0)}% ($holdingYears ans de détention à $canton).',
        amount: _gainTax,
        color: MintColors.scoreAttention,
        ref: 'LIFD art. 12',
      ),
      (
        number: 'Acte 2',
        emoji: '🏦',
        title: 'Remboursement EPL obligatoire',
        detail:
            'Tu as retiré ${formatChfWithPrefix(eplWithdrawn)} de ton LPP via l\'EPL. '
            'La vente oblige le remboursement intégral.',
        amount: eplWithdrawn,
        color: MintColors.scoreCritique,
        ref: 'LPP art. 30c',
      ),
      (
        number: 'Acte 3',
        emoji: '⏰',
        title: 'Remploi — 2 ans pour racheter',
        detail:
            'Si tu ne rachètes pas dans les 2 ans, l\'impôt sur le gain n\'est pas différé. '
            'Tu dois ${formatChfWithPrefix(_gainTax)}.',
        amount: _gainTax,
        color: MintColors.scoreCritique,
        ref: 'LIFD art. 12 al. 3',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: acts.map((act) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: act.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: act.color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: act.color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      act.number,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(act.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      act.title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '− ${formatChfWithPrefix(act.amount)}',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: act.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                act.detail,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                act.ref,
                style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildNetCascade() {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          _buildCascadeRow('Prix de vente', salePrice, isPositive: true),
          _buildCascadeRow('− Hypothèque', _mortgage, isPositive: false),
          _buildCascadeRow('− Impôt gain', _gainTax, isPositive: false),
          _buildCascadeRow('− EPL remboursé', _eplReturn, isPositive: false),
          _buildCascadeRow('− Frais notaire', _notaryFees, isPositive: false),
          const Divider(height: 1, thickness: 2),
          _buildCascadeRow('= Net réel', _netReal, isPositive: true, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildCascadeRow(String label, double amount, {
    required bool isPositive,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w400,
              color: MintColors.textPrimary,
            ),
          ),
          Text(
            formatChfWithPrefix(amount),
            style: GoogleFonts.montserrat(
              fontSize: isTotal ? 18 : 13,
              fontWeight: FontWeight.w800,
              color: isTotal
                  ? (_netReal > 0 ? MintColors.scoreExcellent : MintColors.scoreCritique)
                  : (isPositive ? MintColors.scoreExcellent : MintColors.scoreCritique),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil fiscal au sens de la LSFin. '
      'Source : LIFD art. 12 (impôt gain immobilier), LPP art. 30c (EPL). '
      'Taux gain indicatif pour $canton, $holdingYears ans de détention.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
