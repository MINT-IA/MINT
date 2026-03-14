import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
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
    final s = S.of(context)!;
    return Semantics(
      label: 'Surprises vente immobiliere impot gain capital EPL remploi',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildActs(s),
                  const SizedBox(height: 16),
                  _buildNetCascade(s),
                  const SizedBox(height: 16),
                  _buildDisclaimer(s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(S s) {
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
              const Text('\u{1F3E0}', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.saleSurprisesTitle,
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
            s.saleSurprisesSubtitle(
              formatChfWithPrefix(salePrice),
              formatChfWithPrefix(_netReal + _gainTax),
              formatChfWithPrefix(_netReal),
            ),
            style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildActs(S s) {
    final acts = [
      (
        number: s.saleSurprisesAct1,
        emoji: '\u{1F4CA}',
        title: s.saleSurprisesAct1Title,
        detail: s.saleSurprisesAct1Detail(
          formatChfWithPrefix(_capitalGain),
          (_gainTaxRate * 100).toStringAsFixed(0),
          holdingYears.toString(),
          canton,
        ),
        amount: _gainTax,
        color: MintColors.scoreAttention,
        ref: 'LIFD art. 12',
      ),
      (
        number: s.saleSurprisesAct2,
        emoji: '\u{1F3E6}',
        title: s.saleSurprisesAct2Title,
        detail: s.saleSurprisesAct2Detail(formatChfWithPrefix(eplWithdrawn)),
        amount: eplWithdrawn,
        color: MintColors.scoreCritique,
        ref: 'LPP art. 30c',
      ),
      (
        number: s.saleSurprisesAct3,
        emoji: '\u23F0',
        title: s.saleSurprisesAct3Title,
        detail: s.saleSurprisesAct3Detail(formatChfWithPrefix(_gainTax)),
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
                        color: MintColors.white,
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

  Widget _buildNetCascade(S s) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          _buildCascadeRow(s.saleSurprisesSalePrice, salePrice, isPositive: true),
          _buildCascadeRow(s.saleSurprisesMortgage, _mortgage, isPositive: false),
          _buildCascadeRow(s.saleSurprisesGainTax, _gainTax, isPositive: false),
          _buildCascadeRow(s.saleSurprisesEplRepaid, _eplReturn, isPositive: false),
          _buildCascadeRow(s.saleSurprisesNotaryFees, _notaryFees, isPositive: false),
          const Divider(height: 1, thickness: 2),
          _buildCascadeRow(s.saleSurprisesNetReal, _netReal, isPositive: true, isTotal: true),
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

  Widget _buildDisclaimer(S s) {
    return Text(
      s.saleSurprisesDisclaimer(canton, holdingYears.toString()),
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
