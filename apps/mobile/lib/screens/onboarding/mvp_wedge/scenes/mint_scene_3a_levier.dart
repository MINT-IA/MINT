/// MintScene3aLevier — scène N2 intent IMPOTS.
///
/// Économie fiscale annuelle d'un versement 3a. Taux marginal estimé
/// par canton + revenu brut (approximation pragmatique — pour un
/// chiffrage précis le simulateur canvas N3 appelle tax_calculator).
///
/// Plafond 3a 2026 salarié LPP\u00a0: CHF 7\u2019258 (OPP3 art. 7 al. 1).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mint_mobile/services/income_converter.dart';
import 'package:mint_mobile/theme/colors.dart';

const double _kPlafond3aSalarie2026 = 7258;

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
    final tauxMarginal =
        _kTauxMarginalMoyen[widget.cantonCode] ?? 0.30;
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
    final r = _computeSavingsRange();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCENE · TON LEVIER DIRECT',
          style: GoogleFonts.montserrat(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: MintColors.corailDiscret,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Ce montant retombe sur ton compte\u00a0chaque année, si tu le fais.',
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
          'économie fiscale annuelle',
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
                'VERSEMENT 3A · CHF ${_fmt(_versement)}',
                style: GoogleFonts.montserrat(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: MintColors.corailDiscret,
                ),
              ),
              const SizedBox(height: 4),
              Slider(
                value: _versement,
                min: 0,
                max: _kPlafond3aSalarie2026,
                divisions: (_kPlafond3aSalarie2026 / 250).round(),
                label: 'CHF ${_fmt(_versement)}',
                activeColor: MintColors.textPrimary,
                inactiveColor:
                    MintColors.textSecondary.withValues(alpha: 0.25),
                onChanged: (v) {
                  setState(() => _versement = (v / 250).round() * 250.0);
                  HapticFeedback.selectionClick();
                },
              ),
              Text(
                'Plafond 2026 salarié\u202fLPP\u00a0: CHF 7\u2019258 '
                '(OPP3 art. 7 al. 1 lit. a).',
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
          'Hypothèse\u00a0: taux marginal moyen canton \u00b7 revenu.\u00a0'
          'Le chiffrage précis canton-par-canton sera donné dans le canvas.',
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
