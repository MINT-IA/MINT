import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart';

/// Ecran de simulation du rachat LPP echelonne vs bloc.
///
/// Permet de comparer l'economie fiscale entre un rachat en une fois
/// et un rachat reparti sur plusieurs annees.
/// Base legale : LPP art. 79b al. 3.
class RachatEchelonneScreen extends StatefulWidget {
  const RachatEchelonneScreen({super.key});

  @override
  State<RachatEchelonneScreen> createState() => _RachatEchelonneScreenState();
}

class _RachatEchelonneScreenState extends State<RachatEchelonneScreen> {
  double _avoirActuel = 200000;
  double _rachatMax = 80000;
  double _revenu = 120000;
  double _tauxMarginal = 0.32;
  int _horizon = 3;

  RachatEchelonneResult get _result => RachatEchelonneSimulator.compare(
        avoirActuel: _avoirActuel,
        rachatMax: _rachatMax,
        revenuImposable: _revenu,
        tauxMarginalEstime: _tauxMarginal,
        horizon: _horizon,
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
                'RACHAT LPP ECHELONNE',
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
                // Introduction
                _buildIntroCard(),
                const SizedBox(height: 24),

                // Sliders
                _buildSlidersSection(),
                const SizedBox(height: 24),

                // Comparison cards
                _buildComparisonSection(result),
                const SizedBox(height: 24),

                // Yearly plan table
                _buildYearlyPlanTable(result),
                const SizedBox(height: 24),

                // Alert LPP art. 79b
                _buildBlockageAlert(),
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

  Widget _buildIntroCard() {
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
            'Pourquoi echelonner ses rachats ?',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'L\'impot suisse etant progressif, repartir un rachat LPP sur '
            'plusieurs annees permet de rester dans des tranches marginales '
            'plus elevees chaque annee, maximisant ainsi l\'economie fiscale '
            'totale. Ce simulateur compare les deux approches.',
            style: TextStyle(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
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

          // Avoir actuel
          _buildSliderRow(
            label: 'Avoir actuel LPP',
            value: _avoirActuel,
            min: 0,
            max: 500000,
            divisions: 100,
            format: 'CHF ${formatChf(_avoirActuel)}',
            onChanged: (v) => setState(() => _avoirActuel = v),
          ),
          const SizedBox(height: 12),

          // Rachat max
          _buildSliderRow(
            label: 'Rachat maximum',
            value: _rachatMax,
            min: 0,
            max: 200000,
            divisions: 40,
            format: 'CHF ${formatChf(_rachatMax)}',
            onChanged: (v) => setState(() => _rachatMax = v),
          ),
          const SizedBox(height: 12),

          // Revenu imposable
          _buildSliderRow(
            label: 'Revenu imposable',
            value: _revenu,
            min: 50000,
            max: 300000,
            divisions: 50,
            format: 'CHF ${formatChf(_revenu)}',
            onChanged: (v) => setState(() => _revenu = v),
          ),
          const SizedBox(height: 12),

          // Taux marginal
          _buildSliderRow(
            label: 'Taux marginal estime',
            value: _tauxMarginal,
            min: 0.25,
            max: 0.45,
            divisions: 20,
            format: '${(_tauxMarginal * 100).toStringAsFixed(1)}%',
            onChanged: (v) => setState(() => _tauxMarginal = v),
          ),
          const SizedBox(height: 12),

          // Horizon
          _buildSliderRow(
            label: 'Horizon (annees)',
            value: _horizon.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            format: '$_horizon an${_horizon > 1 ? 's' : ''}',
            onChanged: (v) => setState(() => _horizon = v.round()),
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

  Widget _buildComparisonSection(RachatEchelonneResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPARAISON',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildComparisonCard(
                title: 'TOUT EN 1 AN',
                subtitle: 'Rachat bloc',
                amount: result.economieBlocTotal,
                color: Colors.orange,
                isWinner: result.delta <= 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildComparisonCard(
                title: 'ECHELONNE SUR $_horizon ANS',
                subtitle: 'Rachat reparti',
                amount: result.economieEchelonneTotal,
                color: MintColors.success,
                isWinner: result.delta > 0,
              ),
            ),
          ],
        ),
        if (result.delta > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.savings, color: Colors.green.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'En echelonnant, vous economisez CHF ${formatChf(result.delta)} '
                    'de plus en impots.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required String subtitle,
    required double amount,
    required Color color,
    required bool isWinner,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner ? color : MintColors.border,
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'CHF ${formatChf(amount)}',
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Economie fiscale',
            style: TextStyle(
              fontSize: 11,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyPlanTable(RachatEchelonneResult result) {
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
            'PLAN ANNUEL',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              const SizedBox(
                width: 50,
                child: Text('Annee',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const Expanded(
                child: Text('Rachat',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
              ),
              const Expanded(
                child: Text('Economie',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
              ),
              const Expanded(
                child: Text('Cout net',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
          const Divider(height: 16),

          // Rows
          for (final year in result.yearlyPlan)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${year.annee}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'CHF ${formatChf(year.montantRachat)}',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'CHF ${formatChf(year.economieFiscale)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'CHF ${formatChf(year.coutNet)}',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 16),

          // Total
          Row(
            children: [
              const SizedBox(
                width: 50,
                child: Text('Total',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text(
                  'CHF ${formatChf(_rachatMax)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                child: Text(
                  'CHF ${formatChf(result.economieEchelonneTotal)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                child: Text(
                  'CHF ${formatChf(_rachatMax - result.economieEchelonneTotal)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockageAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel, color: Colors.red.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LPP art. 79b al. 3 — Blocage EPL',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Apres chaque rachat, tout retrait EPL (encouragement a la '
                  'propriete du logement) est bloque pendant 3 ans. '
                  'Planifiez en consequence si un achat immobilier est prevu.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                    height: 1.4,
                  ),
                ),
              ],
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
