/// MintSceneRenteTrouee — scène N2 intent RETRAITE.
///
/// Au tour 7 de l'onboarding MVP wedge. Appelle `AvsCalculator` (avec
/// arrivalAge/lacunes — la scène s'appelle « rente TROUÉE », elle DOIT
/// refléter le trou) + `LppCalculator.projectToRetirement` (plus de forfait
/// `gross*0.34/12` qui bypassait le moteur). Affiche un **intervalle**
/// CHF X – Y / mois, pas un point. Contrôle discret sur l'âge d'espérance de
/// vie pour ressentir l'effet longévité.
///
/// Pour un jeune (<30 ans) SANS lacune, le gapFactor vaut 1.0 (carrière
/// complète projetée) : le chiffre porte alors l'étiquette « hypothèse :
/// carrière complète » — le plus career-contingent ne reçoit plus
/// silencieusement le chiffre le plus career-certain (jeune_diplome-2).
///
/// Panel final 2026-04-22 — eyebrow « SCENE · ta retraite projetée »,
/// chiffre héros intervalle, phrase de recul Fraunces 17pt.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/discrete_adjust_control.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/income_converter.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class MintSceneRenteTrouee extends StatefulWidget {
  const MintSceneRenteTrouee({
    super.key,
    required this.currentAge,
    required this.netMonthly,
    required this.isRange,
    this.arrivalAge,
    this.lacunes = 0,
  });

  final int currentAge;
  final double netMonthly;
  final bool isRange;

  /// Age d'arrivée en Suisse (si Suisse de retour / expat). Plumbé à
  /// AvsCalculator pour démarrer les années de cotisation à l'arrivée, pas
  /// toujours à 21 (LAVS art. 29). Null ⇒ carrière depuis 21 ans.
  final int? arrivalAge;

  /// Années manquantes au sens AVS (lacunes — LAVS art. 29). Réduisent la
  /// composante AVS de la rente projetée.
  final int lacunes;

  @override
  State<MintSceneRenteTrouee> createState() => _MintSceneRenteTroueeState();
}

class _MintSceneRenteTroueeState extends State<MintSceneRenteTrouee> {
  double _ageEsperance = 85;

  /// gapFactor==1.0 (carrière complète projetée) ⇔ aucune lacune ET pas
  /// d'arrivée tardive. Tant que la personne n'a pas atteint l'âge de
  /// référence, elle n'a PAS cotisé 44 ans : le chiffre repose sur une
  /// hypothèse, et il est étiqueté.
  ///
  /// POURQUOI CE SEUIL A CHANGÉ (2026-08-14, trouvé en marchant l'app)
  ///
  /// La condition était `currentAge < 30`, pensée pour le jeune diplômé. Mais
  /// l'hypothèse ne se limite pas à lui : à 34 ans on a cotisé treize années
  /// sur quarante-quatre, à 45 ans vingt-quatre. L'étiquette disparaissait
  /// exactement là où le chiffre devenait crédible — donc là où il pesait le
  /// plus. Le seuil ne mesurait pas l'incertitude, il mesurait la jeunesse.
  bool get _isFullCareerAssumption =>
      widget.lacunes == 0 &&
      (widget.arrivalAge == null || widget.arrivalAge! <= 20) &&
      widget.currentAge < avsAgeReferenceHomme;

  ({double low, double high}) _computeRenteRange() {
    // Revenu brut annuel dérivé (salarié, facteur 1.17).
    final grossAnnual =
        IncomeConverter.netMonthlyToGrossAnnual(widget.netMonthly);

    // AVS brute mensuelle via la source canonique AVEC arrivalAge/lacunes :
    // la scène s'appelle « rente trouée », elle DOIT refléter le trou de
    // cotisation (LAVS art. 29). Plus de calcul « sur carrière complète »
    // forcé pour un profil à lacunes (matrice returning_swiss_gaps-2).
    final avsMonthly = AvsCalculator.computeMonthlyRente(
      currentAge: widget.currentAge,
      retirementAge: avsAgeReferenceHomme,
      arrivalAge: widget.arrivalAge,
      lacunes: widget.lacunes,
      grossAnnualSalary: grossAnnual,
    );

    // LPP estimation via la source canonique LppCalculator.projectToRetirement
    // (accumulation salaire-pondérée dès 25 ans, taux conv. min 6.8% LPP art.
    // 14 al. 2). Plus de forfait `gross*0.34/12` qui bypassait le moteur.
    // La fourchette reflète l'incertitude du rendement caisse (1.5%/3.5%).
    final lppAnnualLow = LppCalculator.projectToRetirement(
      currentBalance: 0,
      currentAge: widget.currentAge,
      retirementAge: avsAgeReferenceHomme,
      grossAnnualSalary: grossAnnual,
      caisseReturn: 0.015, // rendement bas 1.5%
      conversionRate: lppTauxConversionMinDecimal,
    );
    final lppAnnualHigh = LppCalculator.projectToRetirement(
      currentBalance: 0,
      currentAge: widget.currentAge,
      retirementAge: avsAgeReferenceHomme,
      grossAnnualSalary: grossAnnual,
      caisseReturn: 0.035, // rendement haut 3.5%
      conversionRate: lppTauxConversionMinDecimal,
    );
    final lppMonthlyLow = lppAnnualLow / 12;
    final lppMonthlyHigh = lppAnnualHigh / 12;

    // Total mensuel : AVS (peu de variance, fixée par LPP) + LPP range.
    // On applique aussi un facteur longévité : plus tu vis, plus le
    // capital se dilue (le panel demande un slider qui joue sur l'âge
    // d'espérance). Ici l'impact sur la rente mensuelle est nul
    // (rente = viagère), mais on renvoie le total cumulé dans la
    // phrase de recul. Pour le chiffre héros on reste sur le mensuel.
    //
    // Marge de confidence:medium sur revenu ±8% (doctrine fourchette).
    final confFactor = widget.isRange ? 0.08 : 0.02;
    final low = (avsMonthly + lppMonthlyLow) * (1 - confFactor);
    final high = (avsMonthly + lppMonthlyHigh) * (1 + confFactor);
    return (low: low, high: high);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final r = _computeRenteRange();
    final cumulTotal = ((r.low + r.high) / 2) * 12 * (_ageEsperance - 65);
    final currentAgeLabel = l10n.onboardingAdjustYearLabel(
      _ageEsperance.toInt(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCENE · TA RETRAITE PROJETEE',
          style: MintTextStyles.labelSmall(
            color: MintColors.corailDiscret,
          ).copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'À ton âge et ton revenu, voici ce qui arrive\u00a0si tu ne bouges rien.',
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
          '/ mois, dès 65 ans',
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        // Jeune (<30) sans lacune ⇒ gapFactor 1.0 = carrière complète
        // PROJETÉE, pas acquise. On l'étiquette pour ne pas vendre le chiffre
        // le plus career-certain au profil le plus career-contingent
        // (jeune_diplome-2). i18n : clé ARB ×6.
        if (_isFullCareerAssumption) ...[
          const SizedBox(height: 8),
          Text(
            l10n.onboardingSceneFullCareerAssumption,
            style: MintTextStyles.labelSmall(
              color: MintColors.corailDiscret,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
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
                'ÂGE D\u2019ESPÉRANCE DE VIE · ${_ageEsperance.toInt()} ans',
                style: MintTextStyles.labelSmall(
                  color: MintColors.corailDiscret,
                ).copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              OnboardingDiscreteAdjustControl(
                decrementIdentifier: 'onboarding-scene-life-decrease',
                incrementIdentifier: 'onboarding-scene-life-increase',
                decrementLabel: l10n.onboardingAdjustDecreaseStep(
                  l10n.onboardingAdjustYearLabel(1),
                ),
                incrementLabel: l10n.onboardingAdjustIncreaseStep(
                  l10n.onboardingAdjustYearLabel(1),
                ),
                currentValueLabel:
                    l10n.onboardingAdjustCurrentValue(currentAgeLabel),
                visualValue: currentAgeLabel,
                canDecrement: _ageEsperance > 70,
                canIncrement: _ageEsperance < 100,
                onDecrement: () {
                  setState(() => _ageEsperance -= 1);
                  HapticFeedback.selectionClick();
                },
                onIncrement: () {
                  setState(() => _ageEsperance += 1);
                  HapticFeedback.selectionClick();
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Cumulé entre 65 et ${_ageEsperance.toInt()} ans\u00a0: '
                'environ CHF ${_fmt(cumulTotal)}.',
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Hypothèse\u00a0: rendement moyen 1,5 à 3,5\u202f%. '
          'Source\u00a0: AVS art. 33ter LAVS, LPP art. 14-16.',
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
