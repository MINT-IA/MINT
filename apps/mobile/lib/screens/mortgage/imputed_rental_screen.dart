import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/mortgage_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;

/// Ecran de calcul de la valeur locative et de son impact fiscal.
///
/// Affiche la decomposition valeur locative vs deductions avec un chiffre choc.
/// Base legale : LIFD art. 21 al. 1 let. b (valeur locative).
class ImputedRentalScreen extends StatefulWidget {
  const ImputedRentalScreen({super.key});

  @override
  State<ImputedRentalScreen> createState() => _ImputedRentalScreenState();
}

class _ImputedRentalScreenState extends State<ImputedRentalScreen> {
  double _valeurVenale = 900000;
  double _interetsAnnuels = 15000;
  double _fraisEntretien = 3000;
  String _canton = 'VD';
  bool _bienAncien = true;
  double _tauxMarginal = 0.30;

  ImputedRentalResult get _result => ImputedRentalCalculator.calculate(
        valeurVenale: _valeurVenale,
        interetsAnnuels: _interetsAnnuels,
        fraisEntretien: _fraisEntretien,
        canton: _canton,
        bienAncien: _bienAncien,
        tauxMarginal: _tauxMarginal,
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      backgroundColor: MintColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.primary,
            foregroundColor: MintColors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                S.of(context)!.imputedRentalAppBarTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: MintColors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Intro
                _buildIntroCard(),
                const SizedBox(height: 24),

                // Chiffre choc
                _buildChiffreChocCard(result),
                const SizedBox(height: 24),

                // Decomposition
                _buildDecompositionCard(result),
                const SizedBox(height: 24),

                // Sliders
                _buildSlidersSection(),
                const SizedBox(height: 24),

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: 12),

                // Source legale
                Text(
                  S.of(context)!.imputedRentalSource,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: MintColors.textMuted,
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.imputedRentalIntroTitle,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context)!.imputedRentalIntroBody,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChocCard(ImputedRentalResult result) {
    final color = result.chiffreChocPositif
        ? MintColors.success
        : MintColors.error;
    final icon = result.chiffreChocPositif
        ? Icons.savings_outlined
        : Icons.trending_up;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 12),
          Text(
            'CHF ${formatChf(result.impotSupplementaire.abs())}/an',
            style: GoogleFonts.montserrat(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.chiffreChocTexte,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecompositionCard(ImputedRentalResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.imputedRentalDecomposition,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Visual bar
          _buildComparisonBar(result),
          const SizedBox(height: 20),

          // Revenus ajoutes
          _buildSectionLabel(S.of(context)!.imputedRentalAddedIncome, MintColors.error),
          _buildInfoRow(
            S.of(context)!.imputedRentalRentalValue,
            '+CHF ${formatChf(result.valeurLocative)}',
            color: MintColors.error,
          ),
          const Divider(height: 20),

          // Deductions
          _buildSectionLabel(S.of(context)!.imputedRentalDeductions, MintColors.success),
          _buildInfoRow(
            S.of(context)!.imputedRentalMortgageInterests,
            '-CHF ${formatChf(result.deductionInterets)}',
            color: MintColors.success,
          ),
          _buildInfoRow(
            S.of(context)!.imputedRentalMaintenanceCosts,
            '-CHF ${formatChf(result.deductionFraisEntretien)}',
            color: MintColors.success,
          ),
          _buildInfoRow(
            S.of(context)!.imputedRentalBuildingInsurance,
            '-CHF ${formatChf(result.deductionAssurance)}',
            color: MintColors.success,
          ),
          _buildInfoRow(
            S.of(context)!.imputedRentalTotalDeductions,
            '-CHF ${formatChf(result.totalDeductions)}',
            isBold: true,
            color: MintColors.success,
          ),
          const Divider(height: 20),

          // Impact net
          _buildInfoRow(
            S.of(context)!.imputedRentalNetImpact,
            '${result.impactNet >= 0 ? "+" : "-"}CHF ${formatChf(result.impactNet.abs())}',
            isBold: true,
            color: result.impactNet > 0 ? MintColors.error : MintColors.success,
          ),
          _buildInfoRow(
            S.of(context)!.imputedRentalTaxImpact((_tauxMarginal * 100).toStringAsFixed(0)),
            '${result.impotSupplementaire >= 0 ? "+" : "-"}CHF ${formatChf(result.impotSupplementaire.abs())}/an',
            isBold: true,
            color: result.impotSupplementaire > 0
                ? MintColors.error
                : MintColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBar(ImputedRentalResult result) {
    final total = result.valeurLocative + result.totalDeductions;
    if (total <= 0) return const SizedBox.shrink();

    final locativeFraction = result.valeurLocative / total;
    final deductionsFraction = result.totalDeductions / total;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: (locativeFraction * 100).round(),
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  color: MintColors.error.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(6),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  S.of(context)!.imputedRentalRentalValue,
                  style: const TextStyle(fontSize: 10, color: MintColors.error),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Expanded(
              flex: (deductionsFraction * 100).round(),
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  color: MintColors.success.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(6),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  S.of(context)!.imputedRentalDeductions,
                  style: const TextStyle(fontSize: 10, color: MintColors.success),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSlidersSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.imputedRentalParameters,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Canton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.imputedRentalCanton,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: MintColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _canton,
                    items: ImputedRentalCalculator.cantons
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _canton = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Valeur venale
          _buildSliderRow(
            label: S.of(context)!.imputedRentalMarketValue,
            value: _valeurVenale,
            min: 200000,
            max: 3000000,
            divisions: 56,
            format: 'CHF ${formatChf(_valeurVenale)}',
            onChanged: (v) => setState(() => _valeurVenale = v),
          ),
          const SizedBox(height: 12),

          // Interets annuels
          _buildSliderRow(
            label: S.of(context)!.imputedRentalAnnualInterests,
            value: _interetsAnnuels,
            min: 0,
            max: 80000,
            divisions: 80,
            format: 'CHF ${formatChf(_interetsAnnuels)}',
            onChanged: (v) => setState(() => _interetsAnnuels = v),
          ),
          const SizedBox(height: 12),

          // Frais d'entretien
          _buildSliderRow(
            label: S.of(context)!.imputedRentalEffectiveMaintenance,
            value: _fraisEntretien,
            min: 0,
            max: 30000,
            divisions: 60,
            format: 'CHF ${formatChf(_fraisEntretien)}',
            onChanged: (v) => setState(() => _fraisEntretien = v),
          ),
          const SizedBox(height: 16),

          // Age du bien
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context)!.imputedRentalOldProperty,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _bienAncien
                          ? S.of(context)!.imputedRentalMaintenanceFlatRate20
                          : S.of(context)!.imputedRentalMaintenanceFlatRate10,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _bienAncien,
                activeThumbColor: MintColors.primary,
                onChanged: (v) => setState(() => _bienAncien = v),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Taux marginal
          _buildSliderRow(
            label: S.of(context)!.imputedRentalMarginalRate,
            value: _tauxMarginal,
            min: 0.15,
            max: 0.45,
            divisions: 30,
            format: '${(_tauxMarginal * 100).toStringAsFixed(1)}%',
            onChanged: (v) => setState(() => _tauxMarginal = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String format,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Text(
              format,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: MintColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              disclaimer,
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: MintColors.deepOrange,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
