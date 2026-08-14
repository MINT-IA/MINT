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
    this.isSalaried = true,
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

  /// La personne est salariée.
  ///
  /// LE DÉFAUT QUE CE CHAMP EXISTE POUR FERMER (2026-08-14)
  ///
  /// La scène ne recevait PAS le statut d'emploi, alors que le fournisseur
  /// l'écrit deux écrans plus tôt : `q_has_pension_fund = false` pour un
  /// indépendant ou une personne sans activité, en citant la règle « un
  /// non-salarié n'est PAS présumé avoir un 2e pilier ». La scène projetait
  /// donc un deuxième pilier que MINT savait non présumé. MINT savait, et
  /// l'écran ne consultait pas.
  ///
  /// Deux conséquences chiffrées :
  ///   · le facteur brut/net salarié était appliqué à un indépendant ;
  ///   · une composante LPP était projetée sans aucune base.
  ///
  /// ET CE QU'IL NE FAUT SURTOUT PAS EN CONCLURE
  ///
  /// `false` veut dire « non présumée », PAS « prouvée absente ». Un
  /// indépendant peut adhérer volontairement à la LPP (LPP art. 4), et il
  /// peut détenir un avoir de libre passage d'un emploi salarié antérieur.
  /// Mettre la composante à zéro affirmerait une absence — aussi faux que de
  /// la projeter. L'écran dit donc « inconnu », et ne compte rien.
  final bool isSalaried;

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

  /// Les deux piliers SÉPARÉMENT, et non fondus en un seul chiffre.
  ///
  /// POURQUOI LA SÉPARATION EST NÉCESSAIRE, ET PAS COSMÉTIQUE
  ///
  /// Elle ne sert pas la propreté du code : elle sert trois vérités que le
  /// total rendait indicibles.
  ///   · La 13e rente ne concerne QUE l'AVS (LAVS art. 34ter). Un cumul
  ///     calculé sur le total à douze mois amputait une mensualité par an.
  ///   · La fourchette 1,5–3,5 % concerne QUE la LPP. Annoncée sur le total,
  ///     elle laissait croire que l'AVS aussi dépend d'un rendement.
  ///   · Une composante peut être INCONNUE pendant que l'autre est estimée.
  ///     Fondues, une donnée manquante devient un zéro invisible.
  ///
  /// `lpp` vaut null quand la personne n'est pas salariée : inconnu, pas nul.
  ({double avsMonthly, double? lppMonthlyLow, double? lppMonthlyHigh})
      _computeRentePillars() {
    // Le facteur brut/net DIFFÈRE selon le statut. La scène l'appelait sans le
    // dire, donc toujours au facteur salarié — y compris pour un indépendant,
    // dont toute la rente découlait ensuite d'un brut faux.
    final grossAnnual = IncomeConverter.netMonthlyToGrossAnnual(
      widget.netMonthly,
      isSalaried: widget.isSalaried,
    );

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

    // Non salarié : on ne projette RIEN, et on n'affirme rien non plus.
    // `q_has_pension_fund = false` veut dire « non présumé », pas « prouvé
    // absent » — l'adhésion volontaire (LPP art. 4) et l'avoir de libre
    // passage d'un emploi antérieur restent possibles. Zéro serait une
    // affirmation ; null est un aveu.
    if (!widget.isSalaried) {
      return (
        avsMonthly: avsMonthly,
        lppMonthlyLow: null,
        lppMonthlyHigh: null,
      );
    }

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
    return (
      avsMonthly: avsMonthly,
      lppMonthlyLow: lppAnnualLow / 12,
      lppMonthlyHigh: lppAnnualHigh / 12,
    );
  }

  /// La fourchette affichée, marge de saisie comprise.
  ///
  /// RÉSERVE ASSUMÉE, notée le 2026-08-14 et NON corrigée dans ce lot.
  /// Le ±8 % est appliqué multiplicativement au total et mélange trois
  /// incertitudes distinctes : imprécision du revenu saisi, données
  /// manquantes, et projection à trente ans. Sur la LPP il se cumule à la
  /// fourchette 1,5–3,5 %, donc la compte deux fois ; sur l'AVS, plafonnée
  /// et déterminée une fois le RAMD fixé, il n'a pas de justification.
  /// Le corriger CHANGE le chiffre que tout le monde voit — c'est un choix
  /// de modèle, pas un correctif de mensonge, et il se traite séparément.
  ({double low, double high}) _computeRenteRange() {
    final p = _computeRentePillars();
    final confFactor = widget.isRange ? 0.08 : 0.02;
    final low = (p.avsMonthly + (p.lppMonthlyLow ?? 0)) * (1 - confFactor);
    final high = (p.avsMonthly + (p.lppMonthlyHigh ?? 0)) * (1 + confFactor);
    return (low: low, high: high);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final r = _computeRenteRange();
    final p = _computeRentePillars();
    final annees = _ageEsperance - 65;

    // LE CUMUL, PILIER PAR PILIER (corrigé le 2026-08-14).
    //
    // Il valait `total * 12 * années`. Or l'AVS verse TREIZE rentes par an
    // depuis 2026 (LAVS art. 34ter) et la LPP douze. Multiplier le total par
    // douze amputait donc une mensualité AVS chaque année — vingt mensualités
    // absentes sur une retraite de 65 à 85 ans. L'écran SOUS-estimait.
    //
    // `AvsCalculator.annualRente` connaissait déjà la treizième ; personne ne
    // l'appelait. C'est le même motif que le reste de cet écran : la capacité
    // existe, l'appel manque.
    final lppMoyenMensuel = p.lppMonthlyLow == null
        ? 0.0
        : (p.lppMonthlyLow! + p.lppMonthlyHigh!) / 2;
    final cumulTotal =
        (AvsCalculator.annualRente(p.avsMonthly) + lppMoyenMensuel * 12) *
            annees;
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
        // Ce que la personne DOIT lire quand une composante manque. Sans
        // cette ligne, un total amputé de son deuxième pilier ressemble à un
        // total complet — une donnée manquante devient un zéro invisible.
        if (p.lppMonthlyLow == null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.onboardingSceneSecondPillarUnknown,
            style: MintTextStyles.labelSmall(
              color: MintColors.corailDiscret,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
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
