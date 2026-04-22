/// MintSceneRenteTrouee — scène N2 intent RETRAITE.
///
/// Au tour 7 de l'onboarding MVP wedge. Appelle `AvsCalculator` +
/// une estimation LPP proportionnelle au revenu brut dérivé. Affiche
/// un **intervalle** CHF X – Y / mois, pas un point. Slider sur l'âge
/// d'espérance de vie pour ressentir l'effet longévité.
///
/// Panel final 2026-04-22 — eyebrow « SCENE · ta retraite projetée »,
/// chiffre héros intervalle, phrase de recul Fraunces 17pt.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/income_converter.dart';
import 'package:mint_mobile/theme/colors.dart';

class MintSceneRenteTrouee extends StatefulWidget {
  const MintSceneRenteTrouee({
    super.key,
    required this.currentAge,
    required this.netMonthly,
    required this.isRange,
  });

  final int currentAge;
  final double netMonthly;
  final bool isRange;

  @override
  State<MintSceneRenteTrouee> createState() => _MintSceneRenteTroueeState();
}

class _MintSceneRenteTroueeState extends State<MintSceneRenteTrouee> {
  double _ageEsperance = 85;

  ({double low, double high}) _computeRenteRange() {
    // Revenu brut annuel dérivé (salarié, facteur 1.17).
    final grossAnnual =
        IncomeConverter.netMonthlyToGrossAnnual(widget.netMonthly);

    // AVS brute mensuelle estimée sur carrière complète, retraite 65.
    final avsMonthly = AvsCalculator.computeMonthlyRente(
      currentAge: widget.currentAge,
      retirementAge: 65,
      grossAnnualSalary: grossAnnual,
    );

    // LPP estimation : taux de remplacement ~34% du salaire coordonné
    // (moyenne suisse salarié 40 ans de cotisation, rendement 2.5%).
    // Taux de conversion OPP2 art. 14 : 6.8% — on reste dans une
    // fourchette réaliste 30-38% selon rendement effectif (1.5 à 3.5%).
    final lppMonthlyMid = (grossAnnual * 0.34) / 12;
    final lppMonthlyLow = lppMonthlyMid * 0.88; // rendement 1.5% → -12%
    final lppMonthlyHigh = lppMonthlyMid * 1.12; // rendement 3.5% → +12%

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
    final r = _computeRenteRange();
    final cumulTotal =
        ((r.low + r.high) / 2) * 12 * (_ageEsperance - 65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCENE · TA RETRAITE PROJETEE',
          style: GoogleFonts.montserrat(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: MintColors.corailDiscret,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'À ton âge et ton revenu, voici ce qui arrive\u00a0si tu ne bouges rien.',
          style: GoogleFonts.montserrat(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: MintColors.textPrimary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'CHF ${_fmt(r.low)} \u2013 ${_fmt(r.high)}',
          style: GoogleFonts.montserrat(
            fontSize: 36,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '/ mois, dès 65 ans',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: MintColors.textSecondary,
          ),
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
                'ÂGE D\u2019ESPÉRANCE DE VIE · ${_ageEsperance.toInt()} ans',
                style: GoogleFonts.montserrat(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: MintColors.corailDiscret,
                ),
              ),
              const SizedBox(height: 4),
              Slider(
                value: _ageEsperance,
                min: 70,
                max: 100,
                divisions: 30,
                label: '${_ageEsperance.toInt()} ans',
                activeColor: MintColors.textPrimary,
                inactiveColor:
                    MintColors.textSecondary.withValues(alpha: 0.25),
                onChanged: (v) {
                  setState(() => _ageEsperance = v);
                  HapticFeedback.selectionClick();
                },
              ),
              Text(
                'Cumulé entre 65 et ${_ageEsperance.toInt()} ans\u00a0: '
                'environ CHF ${_fmt(cumulTotal)}.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Hypothèse\u00a0: rendement moyen 1,5 à 3,5\u202f%. '
          'Source\u00a0: AVS art. 33ter LAVS, LPP art. 14-16.',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textSecondary,
            fontStyle: FontStyle.italic,
            height: 1.4,
          ),
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
