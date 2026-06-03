/// MintScene3aLevier — scène N2 intent IMPOTS.
///
/// Impact fiscal indicatif d'un versement 3a. Taux marginal estimé
/// par canton + revenu brut (approximation pragmatique — pour un
/// chiffrage précis le simulateur canvas N3 appelle tax_calculator).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/discrete_adjust_control.dart';
import 'package:mint_mobile/services/income_converter.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Approximation du taux marginal moyen par canton (source : barèmes
/// cantonaux harmonisés 2024, moyenne pour un célibataire sans enfant
/// gagnant 80-120k brut). Ces valeurs servent UNIQUEMENT pour
/// l'estimation d'onboarding. Le canvas N3 appelle `tax_calculator`
/// pour le chiffrage précis.
const Map<String, double> _kTauxMarginalMoyen = {
  'VD': 0.31,
  'GE': 0.34,
  'VS': 0.27,
  'FR': 0.29,
  'NE': 0.33,
  'JU': 0.31,
  'BE': 0.30,
  'ZH': 0.28,
  'BS': 0.28,
  'BL': 0.27,
  'SO': 0.29,
  'AG': 0.26,
  'LU': 0.25,
  'ZG': 0.19,
  'SZ': 0.22,
  'OW': 0.24,
  'NW': 0.21,
  'UR': 0.23,
  'GL': 0.26,
  'SH': 0.26,
  'AR': 0.25,
  'AI': 0.22,
  'SG': 0.27,
  'GR': 0.27,
  'TG': 0.26,
  'TI': 0.30,
};

const double _kVersementStep = 250;

double get _versementMaxDiscrete =>
    (pilier3aPlafondAvecLpp / _kVersementStep).floor() * _kVersementStep;

class MintScene3aLevier extends StatefulWidget {
  const MintScene3aLevier({
    super.key,
    required this.netMonthly,
    required this.cantonCode,
    required this.isRange,
  });

  final double netMonthly;
  final String cantonCode;
  final bool isRange;

  @override
  State<MintScene3aLevier> createState() => _MintScene3aLevierState();
}

class _MintScene3aLevierState extends State<MintScene3aLevier> {
  double _versement = 3000;

  ({double low, double high}) _computeSavingsRange() {
    final tauxMarginal = _kTauxMarginalMoyen[widget.cantonCode] ?? 0.30;
    // Modulation par revenu : sous 60k brut tauxMarg -15%, sur 180k +10%.
    final grossAnnual =
        IncomeConverter.netMonthlyToGrossAnnual(widget.netMonthly);
    double adj;
    if (grossAnnual < 60000) {
      adj = -0.15;
    } else if (grossAnnual > 180000) {
      adj = 0.10;
    } else {
      adj = 0.0;
    }
    final effectiveMarg = (tauxMarginal * (1 + adj)).clamp(0.10, 0.45);

    final savingsMid = _versement * effectiveMarg;
    // Fourchette ±6% pour confidence:medium sur canton+revenu.
    final confFactor = widget.isRange ? 0.06 : 0.02;
    return (
      low: savingsMid * (1 - confFactor),
      high: savingsMid * (1 + confFactor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final r = _computeSavingsRange();
    final versementMax = _versementMaxDiscrete;
    final currentVersementLabel = formatChfWithPrefix(_versement);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCENE · TON LEVIER DIRECT',
          style: MintTextStyles.labelSmall(color: MintColors.corailDiscret)
              .copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.4),
        ),
        const SizedBox(height: 14),
        Text(
          'Ce versement peut diminuer ton revenu imposable. '
          'L’impact réel dépend du canton, du revenu et de ton statut LPP.',
          style: MintTextStyles.titleMedium(color: MintColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w500, height: 1.35),
        ),
        const SizedBox(height: 28),
        Text(
          'CHF ${formatChf(r.low)} \u2013 ${formatChf(r.high)}',
          style: MintTextStyles.displayMedium(color: MintColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w600, height: 1.1),
        ),
        const SizedBox(height: 4),
        Text(
          'impact fiscal indicatif',
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.porcelaine,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VERSEMENT 3A · CHF ${formatChf(_versement)}',
                style:
                    MintTextStyles.labelSmall(color: MintColors.corailDiscret)
                        .copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              OnboardingDiscreteAdjustControl(
                decrementIdentifier: 'onboarding-scene-3a-decrease',
                incrementIdentifier: 'onboarding-scene-3a-increase',
                decrementLabel: l10n.onboardingAdjustDecreaseStep(
                  formatChfWithPrefix(_kVersementStep),
                ),
                incrementLabel: l10n.onboardingAdjustIncreaseStep(
                  formatChfWithPrefix(_kVersementStep),
                ),
                currentValueLabel:
                    l10n.onboardingAdjustCurrentValue(currentVersementLabel),
                visualValue: currentVersementLabel,
                canDecrement: _versement > 0,
                canIncrement: _versement < versementMax,
                onDecrement: () {
                  setState(() => _versement = (_versement - _kVersementStep)
                      .clamp(0, versementMax)
                      .toDouble());
                  HapticFeedback.selectionClick();
                },
                onIncrement: () {
                  setState(() => _versement = (_versement + _kVersementStep)
                      .clamp(0, versementMax)
                      .toDouble());
                  HapticFeedback.selectionClick();
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Marge maximale salarié\u202fLPP\u00a0: '
                '${formatChfWithPrefix(pilier3aPlafondAvecLpp)} '
                '(OPP3 art. 7 al. 1 lit. a).',
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                    .copyWith(height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Hypothèse\u00a0: taux marginal moyen canton \u00b7 revenu.\u00a0'
          'Le chiffrage précis canton-par-canton sera donné dans le canvas.',
          style: MintTextStyles.labelSmall(color: MintColors.textSecondary)
              .copyWith(fontStyle: FontStyle.italic, height: 1.4),
        ),
      ],
    );
  }
}
