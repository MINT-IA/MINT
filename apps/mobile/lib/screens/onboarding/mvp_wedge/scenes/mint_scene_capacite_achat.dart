/// MintSceneCapaciteAchat — scène N2 intent ACHAT.
///
/// Capacité d'achat sur la règle suisse classique :
///   - charge mensuelle max = 33% du revenu brut (intérêts + amort + charges)
///   - apport min 20%, dont 10% hors 2e pilier
///   - taux théorique d'évaluation bancaire : 5% (stress test FINMA)
///
/// Prix cible visable = apport + (charge_max / taux_theorique) × 12.
/// Intervalle ±12% pour refléter la fourchette de revenu (confidence:medium).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/discrete_adjust_control.dart';
import 'package:mint_mobile/services/income_converter.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

const double _kChargeMaxPct = 0.33;
const double _kStressTestRate = 0.05;
const double _kApportMinPct = 0.20;

class MintSceneCapaciteAchat extends StatefulWidget {
  const MintSceneCapaciteAchat({
    super.key,
    required this.netMonthly,
    required this.isRange,
  });

  final double netMonthly;
  final bool isRange;

  @override
  State<MintSceneCapaciteAchat> createState() => _MintSceneCapaciteAchatState();
}

class _MintSceneCapaciteAchatState extends State<MintSceneCapaciteAchat> {
  double _apport = 80000;

  ({double low, double high}) _computePriceRange() {
    final grossAnnual =
        IncomeConverter.netMonthlyToGrossAnnual(widget.netMonthly);
    final chargeAnnualMax = grossAnnual * _kChargeMaxPct;
    final maxLoan = chargeAnnualMax / _kStressTestRate; // règle théorique
    final priceMid = _apport + maxLoan;

    // Contrainte apport 20% : si l'apport < 20% du priceMid, plafonne.
    final priceByApport = _apport / _kApportMinPct;
    final priceCapped = priceMid < priceByApport ? priceMid : priceByApport;

    final confFactor = widget.isRange ? 0.12 : 0.04;
    return (
      low: priceCapped * (1 - confFactor),
      high: priceCapped * (1 + confFactor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final r = _computePriceRange();
    final chargeMensuelleMax =
        IncomeConverter.netMonthlyToGrossAnnual(widget.netMonthly) *
            _kChargeMaxPct /
            12;
    final currentApportLabel = 'CHF ${_fmt(_apport)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.onboardingSceneEyebrowAchat,
          style: MintTextStyles.labelSmall(
            color: MintColors.corailDiscret,
          ).copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'C\u2019est ta marge réelle, avant l\u2019émotion de la visite.',
          style: MintTextStyles.titleMedium(
            color: MintColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 28),
        Text(
          'CHF ${_fmt(r.low)} \u2013 ${_fmt(r.high)}',
          style: MintTextStyles.displayMedium(color: MintColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'prix du lieu que tu peux viser',
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
                'APPORT · CHF ${_fmt(_apport)}',
                style: MintTextStyles.labelSmall(
                  color: MintColors.corailDiscret,
                ).copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              OnboardingDiscreteAdjustControl(
                decrementIdentifier: 'onboarding-scene-apport-decrease',
                incrementIdentifier: 'onboarding-scene-apport-increase',
                decrementLabel:
                    l10n.onboardingAdjustDecreaseStep('CHF 10\u2019000'),
                incrementLabel:
                    l10n.onboardingAdjustIncreaseStep('CHF 10\u2019000'),
                currentValueLabel:
                    l10n.onboardingAdjustCurrentValue(currentApportLabel),
                visualValue: currentApportLabel,
                canDecrement: _apport > 20000,
                canIncrement: _apport < 500000,
                onDecrement: () {
                  setState(() => _apport -= 10000);
                  HapticFeedback.selectionClick();
                },
                onIncrement: () {
                  setState(() => _apport += 10000);
                  HapticFeedback.selectionClick();
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Charge mensuelle max\u00a0: environ CHF ${_fmt(chargeMensuelleMax)} '
                '(intérêts + amortissement + charges).',
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Hypothèses\u00a0: règle des 33\u202f%, stress test 5\u202f%, apport '
          'minimum 20\u202f%. Source\u00a0: FINMA Circ. 2017/3, ORFP.',
          style: MintTextStyles.labelSmall(
            color: MintColors.textSecondary,
          ).copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  static String _fmt(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write("\u2019");
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
