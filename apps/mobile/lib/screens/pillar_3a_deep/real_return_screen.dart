import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/pillar_3a_deep_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/constants/social_insurance.dart';

/// Ecran de simulation du rendement reel 3a avec economie fiscale.
///
/// Compare le rendement d'un 3a fintech avec un compte epargne classique
/// en tenant compte de l'economie fiscale et de l'inflation.
/// Base legale : OPP3, LIFD art. 33 al. 1 let. e.
class RealReturnScreen extends StatefulWidget {
  const RealReturnScreen({super.key});

  @override
  State<RealReturnScreen> createState() => _RealReturnScreenState();
}

class _RealReturnScreenState extends State<RealReturnScreen> {
  double _versementAnnuel = 7258;
  double _tauxMarginal = 0.32;
  double _rendementBrut = 0.045;
  double _fraisGestion = 0.005;
  int _dureeAnnees = 30;

  RealReturnResult get _result => RealReturnCalculator.calculate(
        versementAnnuel: _versementAnnuel,
        tauxMarginal: _tauxMarginal,
        rendementBrut: _rendementBrut,
        fraisGestion: _fraisGestion,
        dureeAnnees: _dureeAnnees,
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
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'RENDEMENT REEL 3A',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Chiffre choc
                _buildChiffreChoc(result),
                const SizedBox(height: 24),

                // Sliders
                _buildSlidersSection(),
                const SizedBox(height: 24),

                // Resultat rendement
                _buildRendementSection(result),
                const SizedBox(height: 24),

                // Comparaison barres
                _buildComparisonBars(result),
                const SizedBox(height: 24),

                // Detail economie fiscale
                _buildFiscalDetail(result),
                const SizedBox(height: 24),

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChoc(RealReturnResult result) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300, width: 2),
      ),
      child: Column(
        children: [
          Text(
            'Rendement reel avec avantage fiscal',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.rendementReel.toStringAsFixed(1)}%',
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'vs ${result.rendementEpargne.toStringAsFixed(1)}% sans avantage fiscal',
            style: TextStyle(
              fontSize: 13,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidersSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PARAMETRES',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Versement annuel
          _buildSliderRow(
            label: 'Versement annuel',
            value: _versementAnnuel,
            min: 1000,
            max: pilier3aPlafondAvecLpp,
            divisions: 62,
            format: 'CHF ${formatChf(_versementAnnuel)}',
            onChanged: (v) => setState(() => _versementAnnuel = v),
          ),
          const SizedBox(height: 12),

          // Taux marginal
          _buildSliderRow(
            label: 'Taux marginal',
            value: _tauxMarginal,
            min: 0.10,
            max: 0.45,
            divisions: 35,
            format: '${(_tauxMarginal * 100).toStringAsFixed(0)}%',
            onChanged: (v) => setState(() => _tauxMarginal = v),
          ),
          const SizedBox(height: 12),

          // Rendement brut
          _buildSliderRow(
            label: 'Rendement brut',
            value: _rendementBrut,
            min: 0.01,
            max: 0.08,
            divisions: 14,
            format: '${(_rendementBrut * 100).toStringAsFixed(1)}%',
            onChanged: (v) => setState(() => _rendementBrut = v),
          ),
          const SizedBox(height: 12),

          // Frais de gestion
          _buildSliderRow(
            label: 'Frais de gestion',
            value: _fraisGestion,
            min: 0.0,
            max: 0.02,
            divisions: 20,
            format: '${(_fraisGestion * 100).toStringAsFixed(2)}%',
            onChanged: (v) => setState(() => _fraisGestion = v),
          ),
          const SizedBox(height: 12),

          // Duree
          _buildSliderRow(
            label: 'Duree de placement',
            value: _dureeAnnees.toDouble(),
            min: 5,
            max: 40,
            divisions: 35,
            format: '$_dureeAnnees ans',
            onChanged: (v) => setState(() => _dureeAnnees = v.round()),
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
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
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

  Widget _buildRendementSection(RealReturnResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RENDEMENTS COMPARES',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            'Rendement nominal 3a',
            '${result.rendementNominal.toStringAsFixed(1)}% / an',
          ),
          const Divider(height: 20),
          _buildResultRow(
            'Rendement reel (avec fiscal)',
            '${result.rendementReel.toStringAsFixed(1)}% / an',
            isBold: true,
            color: MintColors.success,
          ),
          const Divider(height: 20),
          _buildResultRow(
            'Rendement compte epargne',
            '${result.rendementEpargne.toStringAsFixed(1)}% / an',
            color: MintColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBars(RealReturnResult result) {
    // Normaliser les barres
    final maxVal = [
      result.capitalFinal3a + result.economieFiscaleTotale,
      result.capitalFinalEpargne,
    ].reduce((a, b) => a > b ? a : b);

    final ratio3a = maxVal > 0
        ? ((result.capitalFinal3a + result.economieFiscaleTotale) / maxVal)
        : 0.0;
    final ratioEpargne =
        maxVal > 0 ? (result.capitalFinalEpargne / maxVal) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CAPITAL FINAL APRES $_dureeAnnees ANS',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),

          // 3a Fintech bar
          _buildBar(
            label: '3a Fintech + fiscal',
            amount: result.capitalFinal3a + result.economieFiscaleTotale,
            ratio: ratio3a,
            color: MintColors.success,
          ),
          const SizedBox(height: 16),

          // Compte epargne bar
          _buildBar(
            label: 'Compte epargne 1.5%',
            amount: result.capitalFinalEpargne,
            ratio: ratioEpargne,
            color: MintColors.textMuted,
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up,
                    color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gain vs epargne classique : CHF ${formatChf(result.gainVsEpargne)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar({
    required String label,
    required double amount,
    required double ratio,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              'CHF ${formatChf(amount)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 12,
            backgroundColor: MintColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildFiscalDetail(RealReturnResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DETAIL ECONOMIE FISCALE',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            'Total versements',
            'CHF ${formatChf(result.totalVersements)}',
          ),
          const Divider(height: 20),
          _buildResultRow(
            'Capital final 3a (hors fiscal)',
            'CHF ${formatChf(result.capitalFinal3a)}',
          ),
          _buildResultRow(
            'Economie fiscale cumulee',
            'CHF ${formatChf(result.economieFiscaleTotale)}',
            color: MintColors.success,
          ),
          const Divider(height: 20),
          _buildResultRow(
            'Total avec avantage fiscal',
            'CHF ${formatChf(result.capitalFinal3a + result.economieFiscaleTotale)}',
            isBold: true,
            color: MintColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value,
      {bool isBold = false, Color? color}) {
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
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              disclaimer,
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
