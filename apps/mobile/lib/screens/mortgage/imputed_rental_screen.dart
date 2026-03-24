import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/mortgage_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
    });
  }

  void _initializeFromProfile() {
    try {
      final profile = context.read<CoachProfileProvider>().profile;
      if (profile == null) return;
      bool changed = false;
      final propertyValue = profile.patrimoine.propertyMarketValue;
      if (propertyValue != null && propertyValue > 0) {
        _valeurVenale = propertyValue.clamp(200000, 3000000);
        changed = true;
      }
      if (profile.canton.isNotEmpty) {
        _canton = profile.canton.toUpperCase();
        changed = true;
      }
      if (profile.revenuBrutAnnuel > 0) {
        _tauxMarginal = RetirementTaxCalculator.estimateMarginalRate(
          profile.revenuBrutAnnuel,
          profile.canton,
        ).clamp(0.15, 0.45);
        changed = true;
      }
      // Estimate annual interest from mortgage balance and rate
      final mortgage = profile.patrimoine.mortgageBalance;
      final rate = profile.patrimoine.mortgageRate;
      if (mortgage != null && mortgage > 0 && rate != null && rate > 0) {
        _interetsAnnuels = (mortgage * rate / 100).clamp(0, 80000);
        changed = true;
      }
      if (changed) setState(() {});
    } catch (_) {
      // Provider not available
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final result = _result;

    return Scaffold(
      backgroundColor: MintColors.surface,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        title: Text(
          s.imputedRentalAppBarTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MintSpacing.md),
        children: [
          // Intro
          _buildIntroCard(s),
          const SizedBox(height: MintSpacing.lg),

          // Chiffre choc
          _buildChiffreChocCard(result),
          const SizedBox(height: MintSpacing.lg),

          // Decomposition
          _buildDecompositionCard(s, result),
          const SizedBox(height: MintSpacing.lg),

          // Sliders
          _buildSlidersSection(s),
          const SizedBox(height: MintSpacing.lg),

          // Disclaimer
          _buildDisclaimer(result.disclaimer),
          const SizedBox(height: MintSpacing.sm),

          // Source legale
          Text(
            s.imputedRentalSource,
            style: MintTextStyles.micro(),
          ),
          const SizedBox(height: MintSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildIntroCard(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.imputedRentalIntroTitle,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            s.imputedRentalIntroBody,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
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

    return Semantics(
      label: 'CHF ${formatChf(result.impotSupplementaire.abs())}/an',
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: MintSpacing.sm + 4),
            Text(
              'CHF ${formatChf(result.impotSupplementaire.abs())}/an',
              style: MintTextStyles.displayMedium(color: color),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              result.chiffreChocTexte,
              textAlign: TextAlign.center,
              style: MintTextStyles.bodyMedium(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecompositionCard(S s, ImputedRentalResult result) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.imputedRentalDecomposition,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),

          // Visual bar
          _buildComparisonBar(s, result),
          const SizedBox(height: MintSpacing.md + 4),

          // Revenus ajoutes
          _buildSectionLabel(s.imputedRentalAddedIncome, MintColors.error),
          _buildInfoRow(
            s.imputedRentalLocativeValue,
            '+CHF ${formatChf(result.valeurLocative)}',
            color: MintColors.error,
          ),
          const Divider(height: MintSpacing.md + 4),

          // Deductions
          _buildSectionLabel(s.imputedRentalDeductionsLabel, MintColors.success),
          _buildInfoRow(
            s.imputedRentalMortgageInterest,
            '-CHF ${formatChf(result.deductionInterets)}',
            color: MintColors.success,
          ),
          _buildInfoRow(
            s.imputedRentalMaintenanceCosts,
            '-CHF ${formatChf(result.deductionFraisEntretien)}',
            color: MintColors.success,
          ),
          _buildInfoRow(
            s.imputedRentalBuildingInsurance,
            '-CHF ${formatChf(result.deductionAssurance)}',
            color: MintColors.success,
          ),
          _buildInfoRow(
            s.imputedRentalTotalDeductions,
            '-CHF ${formatChf(result.totalDeductions)}',
            isBold: true,
            color: MintColors.success,
          ),
          const Divider(height: MintSpacing.md + 4),

          // Impact net
          _buildInfoRow(
            s.imputedRentalNetImpact,
            '${result.impactNet >= 0 ? "+" : "-"}CHF ${formatChf(result.impactNet.abs())}',
            isBold: true,
            color: result.impactNet > 0 ? MintColors.error : MintColors.success,
          ),
          _buildInfoRow(
            s.imputedRentalFiscalImpact((_tauxMarginal * 100).toStringAsFixed(0)),
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

  Widget _buildComparisonBar(S s, ImputedRentalResult result) {
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
                  s.imputedRentalBarLocative,
                  style: MintTextStyles.micro(color: MintColors.error),
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
                  s.imputedRentalBarDeductions,
                  style: MintTextStyles.micro(color: MintColors.success),
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
      padding: const EdgeInsets.only(bottom: MintSpacing.sm),
      child: Text(
        text,
        style: MintTextStyles.labelSmall(color: color),
      ),
    );
  }

  Widget _buildSlidersSection(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.imputedRentalParameters,
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),

          // Canton
          Semantics(
            label: s.imputedRentalCanton,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.imputedRentalCanton,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm + 4),
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
                                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary)),
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
          ),
          const SizedBox(height: MintSpacing.md),

          // Valeur venale
          _buildSliderRow(
            label: s.imputedRentalPropertyValue,
            value: _valeurVenale,
            min: 200000,
            max: 3000000,
            divisions: 56,
            format: 'CHF ${formatChf(_valeurVenale)}',
            onChanged: (v) => setState(() => _valeurVenale = v),
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Interets annuels
          _buildSliderRow(
            label: s.imputedRentalAnnualInterest,
            value: _interetsAnnuels,
            min: 0,
            max: 80000,
            divisions: 80,
            format: 'CHF ${formatChf(_interetsAnnuels)}',
            onChanged: (v) => setState(() => _interetsAnnuels = v),
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Frais d'entretien
          _buildSliderRow(
            label: s.imputedRentalEffectiveMaintenance,
            value: _fraisEntretien,
            min: 0,
            max: 30000,
            divisions: 60,
            format: 'CHF ${formatChf(_fraisEntretien)}',
            onChanged: (v) => setState(() => _fraisEntretien = v),
          ),
          const SizedBox(height: MintSpacing.md),

          // Age du bien
          Semantics(
            label: s.imputedRentalOldProperty,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.imputedRentalOldProperty,
                        style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                      ),
                      Text(
                        _bienAncien
                            ? s.imputedRentalForfaitOld
                            : s.imputedRentalForfaitNew,
                        style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _bienAncien,
                  activeTrackColor: MintColors.primary,
                  onChanged: (v) => setState(() => _bienAncien = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Taux marginal
          _buildSliderRow(
            label: s.imputedRentalMarginalRate,
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
    return Semantics(
      label: '$label: $format',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
              ),
              Text(
                format,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
              ),
            ],
          ),
          MintPremiumSlider(
            label: label,
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            formatValue: (_) => format,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: isBold
                  ? MintTextStyles.bodySmall(color: MintColors.textPrimary)
                  : MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: isBold
                ? MintTextStyles.bodySmall(color: color ?? MintColors.textPrimary)
                : MintTextStyles.labelSmall(color: color ?? MintColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              disclaimer,
              style: MintTextStyles.micro(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
