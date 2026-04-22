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
import 'package:google_fonts/google_fonts.dart';

import 'package:mint_mobile/services/income_converter.dart';
import 'package:mint_mobile/theme/colors.dart';

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
    final r = _computePriceRange();
    final chargeMensuelleMax =
        IncomeConverter.netMonthlyToGrossAnnual(widget.netMonthly) *
            _kChargeMaxPct /
            12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCENE · CE QUE TU PEUX VISER',
          style: GoogleFonts.montserrat(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: MintColors.corailDiscret,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'C\u2019est ta marge réelle, avant l\u2019émotion de la visite.',
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
            fontSize: 34,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'prix du lieu que tu peux viser',
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
                'APPORT · CHF ${_fmt(_apport)}',
                style: GoogleFonts.montserrat(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: MintColors.corailDiscret,
                ),
              ),
              const SizedBox(height: 4),
              Slider(
                value: _apport,
                min: 20000,
                max: 500000,
                divisions: 48,
                label: 'CHF ${_fmt(_apport)}',
                activeColor: MintColors.textPrimary,
                inactiveColor:
                    MintColors.textSecondary.withValues(alpha: 0.25),
                onChanged: (v) {
                  setState(() => _apport = (v / 10000).round() * 10000);
                  HapticFeedback.selectionClick();
                },
              ),
              Text(
                'Charge mensuelle max\u00a0: environ CHF ${_fmt(chargeMensuelleMax)} '
                '(intérêts + amortissement + charges).',
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
          'Hypothèses\u00a0: règle des 33\u202f%, stress test 5\u202f%, apport '
          'minimum 20\u202f%. Source\u00a0: FINMA Circ. 2017/3, ORFP.',
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
