import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P4-D  Le vrai coût de ta franchise LAMal
//  Charte : L1 (CHF/mois) + L2 (Avant/Après)
//  Source : LAMal art. 64-64a, OAMal art. 93
// ────────────────────────────────────────────────────────────

class FranchiseOption {
  const FranchiseOption({
    required this.franchiseAmount,
    required this.monthlyPremiumSavings,
  });

  final double franchiseAmount;
  final double monthlyPremiumSavings;
}

class FranchiseCostWidget extends StatefulWidget {
  const FranchiseCostWidget({
    super.key,
    required this.options,
    this.initialConsultationsPerYear = 3,
  });

  final List<FranchiseOption> options;
  final int initialConsultationsPerYear;

  @override
  State<FranchiseCostWidget> createState() => _FranchiseCostWidgetState();
}

class _FranchiseCostWidgetState extends State<FranchiseCostWidget> {
  late int _consultationsPerYear;

  static const double _consultationCost = 150.0;
  // Wire to social_insurance.dart (LAMal art. 64 al. 2)
  static const double _quotePartMax = lamalQuotePartMax;
  static const double _longIllnessDuration = 2.0; // years

  @override
  void initState() {
    super.initState();
    _consultationsPerYear = widget.initialConsultationsPerYear;
  }

  // Annual out-of-pocket for a given franchise (normal year)
  double _annualCostNormal(FranchiseOption opt) {
    final used = (_consultationsPerYear * _consultationCost).clamp(0, opt.franchiseAmount);
    final quotePart = (used * 0.10).clamp(0, _quotePartMax);
    return used + quotePart - opt.monthlyPremiumSavings * 12;
  }

  // Annual out-of-pocket for a long illness (2-year scenario)
  double _annualCostLongIllness(FranchiseOption opt) {
    return (opt.franchiseAmount + _quotePartMax) * _longIllnessDuration / _longIllnessDuration;
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Franchise LAMal coût pépin long terme',
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
                  _buildSlider(),
                  const SizedBox(height: 20),
                  _buildComparisonTable(),
                  const SizedBox(height: 16),
                  _buildLongIllnessScenario(),
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
        color: Color(0xFFE8F5E9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏥', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ta franchise en cas de pépin long',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Scénario : maladie ou accident nécessitant 2 ans de soins',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Combien de fois vas-tu chez le médecin/an ?',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
        Slider(
          value: _consultationsPerYear.toDouble(),
          min: 0,
          max: 20,
          divisions: 20,
          label: '$_consultationsPerYear× / an',
          activeColor: MintColors.primary,
          onChanged: (v) => setState(() => _consultationsPerYear = v.round()),
        ),
        Text(
          '$_consultationsPerYear consultation${_consultationsPerYear > 1 ? 's' : ''} / an',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MintColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonTable() {
    if (widget.options.isEmpty) return const SizedBox.shrink();
    final baseOption = widget.options.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comparaison des franchises',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Column(
            children: [
              _buildTableHeader(),
              const Divider(height: 1),
              ...widget.options.map((opt) {
                final normalCost = _annualCostNormal(opt);
                final isLowest = widget.options.fold(
                  widget.options.first,
                  (best, o) => _annualCostNormal(o) < _annualCostNormal(best) ? o : best,
                ) == opt;
                return _buildTableRow(opt, normalCost, isLowest, baseOption);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text('Franchise', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MintColors.textSecondary)),
          ),
          SizedBox(
            width: 90,
            child: Text('Éco. prime', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MintColors.textSecondary), textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 90,
            child: Text('Coût net/an', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MintColors.textSecondary), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(FranchiseOption opt, double normalCost, bool isLowest, FranchiseOption base) {
    final savings = opt.monthlyPremiumSavings * 12;
    return Container(
      color: isLowest ? MintColors.scoreExcellent.withValues(alpha: 0.07) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (isLowest) ...[
                  const Icon(Icons.star, color: MintColors.scoreExcellent, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(
                  'CHF ${_fmt(opt.franchiseAmount)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isLowest ? FontWeight.w700 : FontWeight.w400,
                    color: isLowest ? MintColors.scoreExcellent : MintColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              '-${_fmt(savings)}/an',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.scoreExcellent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              normalCost >= 0 ? '+${_fmt(normalCost)}' : '-${_fmt(normalCost.abs())}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: normalCost <= 0 ? MintColors.scoreExcellent : MintColors.scoreAttention,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLongIllnessScenario() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreAttention.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreAttention.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Si maladie longue (2 ans de soins) :',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...widget.options.map((opt) {
            final cost = _annualCostLongIllness(opt);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Franchise CHF ${_fmt(opt.franchiseAmount)}',
                      style: GoogleFonts.inter(fontSize: 13, color: MintColors.textPrimary),
                    ),
                  ),
                  Text(
                    'CHF ${_fmt(cost)}/an',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MintColors.scoreAttention,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 16),
          Text(
            'Règle : si tu vas chez le médecin plus de 2× par an,\n'
            'la franchise basse te coûte moins cher.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : LAMal art. 64-64a. Changement de franchise : avant le 30.11.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
