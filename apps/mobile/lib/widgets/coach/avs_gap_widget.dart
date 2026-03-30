import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  P13-C  Le Trou AVS — rente réduite par années à l'étranger
//  Charte : L1 (CHF/mois) + L6 (Chiffre-choc)
//  Source : LAVS art. 29bis-29quater, avsDureeCotisationComplete = 44
// ────────────────────────────────────────────────────────────

class AvsGapWidget extends StatefulWidget {
  const AvsGapWidget({
    super.key,
    required this.currentContributionYears,
    required this.currentAge,
    this.initialYearsAbroad = 5,
    // Post-AVS 21 : hommes et femmes ont le même âge de référence (65 ans).
    // Paramétrisé pour permettre les cas concubins/frontaliers ou évolutions futures.
    this.referenceAge = avsAgeReferenceHomme,
  });

  final int currentContributionYears;
  final int currentAge;
  final int initialYearsAbroad;
  final int referenceAge;

  @override
  State<AvsGapWidget> createState() => _AvsGapWidgetState();
}

class _AvsGapWidgetState extends State<AvsGapWidget> {
  late int _yearsAbroad;

  @override
  void initState() {
    super.initState();
    _yearsAbroad = widget.initialYearsAbroad;
  }

  int get _yearsRemainingInCH =>
      (widget.referenceAge - widget.currentAge).clamp(0, avsDureeCotisationComplete);

  int get _totalYearsWithAbroad =>
      (widget.currentContributionYears + _yearsRemainingInCH - _yearsAbroad)
          .clamp(0, avsDureeCotisationComplete);

  int get _totalYearsWithoutAbroad =>
      (widget.currentContributionYears + _yearsRemainingInCH)
          .clamp(0, avsDureeCotisationComplete);

  double get _renteWithoutAbroad =>
      avsRenteMaxMensuelle * _totalYearsWithoutAbroad / avsDureeCotisationComplete;

  double get _renteWithAbroad =>
      avsRenteMaxMensuelle * _totalYearsWithAbroad / avsDureeCotisationComplete;

  double get _renteLoss => _renteWithoutAbroad - _renteWithAbroad;
  double get _perYearAbroad => _yearsAbroad > 0 ? _renteLoss / _yearsAbroad : 0;
  double get _lifetimeLoss => AvsCalculator.annualRente(_renteLoss) * 20; // avg 20 years retirement

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Trou AVS années étranger rente réduite LAVS cotisation',
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
                  _buildSlider(),
                  const SizedBox(height: 16),
                  _buildComparison(),
                  const SizedBox(height: 16),
                  _buildChiffreChoc(),
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
        color: MintColors.urgentBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🕳️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Le trou AVS',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Chaque année hors Suisse réduit ta rente. Pour toujours.',
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Années à l\'étranger',
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: MintColors.scoreCritique.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_yearsAbroad an${_yearsAbroad > 1 ? 's' : ''}',
                style: MintTextStyles.bodySmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        Slider(
          value: _yearsAbroad.toDouble(),
          min: 1,
          max: 20,
          divisions: 19,
          activeColor: MintColors.scoreCritique,
          onChanged: (v) => setState(() => _yearsAbroad = v.round()),
        ),
      ],
    );
  }

  Widget _buildComparison() {
    return Row(
      children: [
        Expanded(child: _buildRenteCard(
          label: 'Sans expatriation',
          years: _totalYearsWithoutAbroad,
          rente: _renteWithoutAbroad,
          color: MintColors.scoreExcellent,
          emoji: '🇨🇭',
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildRenteCard(
          label: 'Avec $_yearsAbroad an${_yearsAbroad > 1 ? 's' : ''} à l\'étranger',
          years: _totalYearsWithAbroad,
          rente: _renteWithAbroad,
          color: MintColors.scoreCritique,
          emoji: '✈️',
        )),
      ],
    );
  }

  Widget _buildRenteCard({
    required String label,
    required int years,
    required double rente,
    required Color color,
    required String emoji,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(
            label,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(height: 1.3),
          ),
          const SizedBox(height: 4),
          Text(
            '$years / $avsDureeCotisationComplete ans',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatChfWithPrefix(rente)}/mois',
            style: MintTextStyles.titleLarge(color: color).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChoc() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⚠️ ${formatChfWithPrefix(_perYearAbroad)}/mois de rente perdu par année à l\'étranger',
            style: MintTextStyles.bodySmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            S.of(context)!.avsGapLifetimeLoss(formatChfWithPrefix(_lifetimeLoss)),
            style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.avsGapCalculation,
            style: MintTextStyles.micro(color: MintColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            '💡 Possibilité de cotiser volontairement à l\'AVS si hors UE — voir LAVS art. 2.',
            style: MintTextStyles.labelSmall(color: MintColors.info).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : LAVS art. 29bis-29quater (années cotisation). '
      'Durée complète : $avsDureeCotisationComplete ans. Rente max : ${formatChfWithPrefix(avsRenteMaxMensuelle)}/mois.',
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
