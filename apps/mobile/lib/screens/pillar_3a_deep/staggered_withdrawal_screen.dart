import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/pillar_3a_deep_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;

/// Ecran de simulation du retrait 3a echelonne multi-comptes.
///
/// Permet de comparer l'impot en bloc vs echelonne et d'identifier
/// le nombre optimal de comptes 3a.
/// Base legale : OPP3, LIFD art. 38.
class StaggeredWithdrawalScreen extends StatefulWidget {
  const StaggeredWithdrawalScreen({super.key});

  @override
  State<StaggeredWithdrawalScreen> createState() =>
      _StaggeredWithdrawalScreenState();
}

class _StaggeredWithdrawalScreenState extends State<StaggeredWithdrawalScreen> {
  double _avoirTotal = 300000;
  int _nbComptes = 3;
  String _canton = 'VD';
  double _revenuImposable = 120000;
  int _ageRetraitDebut = 60;
  int _ageRetraitFin = 64;

  StaggeredWithdrawalResult get _result =>
      StaggeredWithdrawalSimulator.simulate(
        avoirTotal: _avoirTotal,
        nbComptes: _nbComptes,
        canton: _canton,
        revenuImposable: _revenuImposable,
        ageRetraitDebut: _ageRetraitDebut,
        ageRetraitFin: _ageRetraitFin,
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
                'RETRAIT 3A ECHELONNE',
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

                // Introduction
                _buildIntroCard(),
                const SizedBox(height: 24),

                // Sliders
                _buildSlidersSection(),
                const SizedBox(height: 24),

                // Resultat comparaison
                _buildComparisonSection(result),
                const SizedBox(height: 24),

                // Plan annuel
                if (result.planAnnuel.isNotEmpty) ...[
                  _buildYearlyPlanTable(result),
                  const SizedBox(height: 24),
                ],

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

  Widget _buildChiffreChoc(StaggeredWithdrawalResult result) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: result.economie > 0
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.orange.shade50, Colors.orange.shade100],
        ),
        borderRadius: const BorderRadius.circular(16),
        border: Border.all(
          color: result.economie > 0
              ? Colors.green.shade300
              : Colors.orange.shade300,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Economie estimee',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: result.economie > 0
                  ? Colors.green.shade800
                  : Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'CHF ${formatChf(result.economie)}',
            style: GoogleFonts.montserrat(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: result.economie > 0
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'en echelonnant sur $_nbComptes comptes',
            style: TextStyle(
              fontSize: 12,
              color: result.economie > 0
                  ? Colors.green.shade600
                  : Colors.orange.shade600,
            ),
          ),
          if (result.nbComptesOptimal != _nbComptes) ...[
            const SizedBox(height: 8),
            Text(
              'Nombre optimal : ${result.nbComptesOptimal} comptes',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MintColors.info,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pourquoi echelonner les retraits 3a ?',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'L\'impot sur le retrait en capital de prevoyance est progressif. '
            'En repartissant tes avoirs 3a sur plusieurs comptes et en les '
            'retirant sur differentes annees fiscales, tu reduis le taux '
            'moyen d\'imposition. La loi autorise jusqu\'a 5 comptes 3a par '
            'personne (OPP3). Les retraits peuvent commencer des 5 ans avant '
            'l\'age de la retraite.',
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
        borderRadius: const BorderRadius.circular(16),
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

          // Avoir total
          _buildSliderRow(
            label: 'Avoir 3a total',
            value: _avoirTotal,
            min: 0,
            max: 1000000,
            divisions: 200,
            format: 'CHF ${formatChf(_avoirTotal)}',
            onChanged: (v) => setState(() => _avoirTotal = v),
          ),
          const SizedBox(height: 12),

          // Nombre de comptes
          _buildSliderRow(
            label: 'Nombre de comptes 3a',
            value: _nbComptes.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            format: '$_nbComptes',
            onChanged: (v) => setState(() => _nbComptes = v.round()),
          ),
          const SizedBox(height: 12),

          // Canton
          _buildCantonDropdown(),
          const SizedBox(height: 12),

          // Revenu imposable
          _buildSliderRow(
            label: 'Revenu imposable',
            value: _revenuImposable,
            min: 30000,
            max: 300000,
            divisions: 54,
            format: 'CHF ${formatChf(_revenuImposable)}',
            onChanged: (v) => setState(() => _revenuImposable = v),
          ),
          const SizedBox(height: 12),

          // Age retrait debut
          _buildSliderRow(
            label: 'Age debut retraits',
            value: _ageRetraitDebut.toDouble(),
            min: 59,
            max: 65,
            divisions: 6,
            format: '$_ageRetraitDebut ans',
            onChanged: (v) => setState(() {
              _ageRetraitDebut = v.round();
              if (_ageRetraitFin < _ageRetraitDebut) {
                _ageRetraitFin = _ageRetraitDebut;
              }
            }),
          ),
          const SizedBox(height: 12),

          // Age retrait fin
          _buildSliderRow(
            label: 'Age dernier retrait',
            value: _ageRetraitFin.toDouble(),
            min: _ageRetraitDebut.toDouble(),
            max: 65,
            divisions: (65 - _ageRetraitDebut).clamp(1, 6),
            format: '$_ageRetraitFin ans',
            onChanged: (v) => setState(() => _ageRetraitFin = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildCantonDropdown() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Canton',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: MintColors.textPrimary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: MintColors.border),
            borderRadius: const BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _canton,
              isDense: true,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
              items: StaggeredWithdrawalSimulator.cantons
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _canton = v);
              },
            ),
          ),
        ),
      ],
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
          activeThumbColor: MintColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildComparisonSection(StaggeredWithdrawalResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESULTAT',
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
                title: 'EN BLOC',
                subtitle: 'Retrait unique',
                amount: result.impotBloc,
                color: Colors.orange,
                isWinner: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildComparisonCard(
                title: 'ECHELONNE',
                subtitle: '$_nbComptes retraits',
                amount: result.impotEchelonne,
                color: MintColors.success,
                isWinner: result.economie > 0,
              ),
            ),
          ],
        ),
        if (result.economie > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.savings, color: Colors.green.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'En echelonnant, tu paies CHF ${formatChf(result.economie)} '
                    'de moins en impots.',
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
        borderRadius: const BorderRadius.circular(16),
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
            'Impot estime',
            style: TextStyle(
              fontSize: 11,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyPlanTable(StaggeredWithdrawalResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.circular(16),
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
            children: const [
              SizedBox(
                width: 40,
                child: Text('Age',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text('Retrait',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
              ),
              Expanded(
                child: Text('Impot',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
              ),
              Expanded(
                child: Text('Net',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
          const Divider(height: 16),

          // Rows
          for (final year in result.planAnnuel)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${year.ageRetrait}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'CHF ${formatChf(year.montantRetire)}',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'CHF ${formatChf(year.impotEstime)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'CHF ${formatChf(year.montantNet)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
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
                width: 40,
                child: Text('Total',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text(
                  'CHF ${formatChf(_avoirTotal)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                child: Text(
                  'CHF ${formatChf(result.impotEchelonne)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                child: Text(
                  'CHF ${formatChf(_avoirTotal - result.impotEchelonne)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
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
        borderRadius: const BorderRadius.circular(12),
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
