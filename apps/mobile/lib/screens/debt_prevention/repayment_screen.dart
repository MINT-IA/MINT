import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/debt_prevention_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/widgets/coach/debt_survival_widget.dart';

/// Ecran de planification du remboursement de dettes.
///
/// Compare les strategies avalanche (taux haut d'abord) et
/// boule de neige (petit solde d'abord).
class RepaymentScreen extends StatefulWidget {
  const RepaymentScreen({super.key});

  @override
  State<RepaymentScreen> createState() => _RepaymentScreenState();
}

class _RepaymentScreenState extends State<RepaymentScreen> {
  final List<_DebtInput> _dettes = [
    _DebtInput(
      nom: 'Credit conso',
      montant: 15000,
      tauxAnnuel: 9.9,
      mensualiteMin: 300,
    ),
    _DebtInput(
      nom: 'Leasing auto',
      montant: 8000,
      tauxAnnuel: 4.5,
      mensualiteMin: 250,
    ),
  ];

  double _budgetMensuel = 800;

  RepaymentComparisonResult? get _result {
    if (_dettes.isEmpty) return null;
    final dettes = _dettes
        .where((d) => d.montant > 0)
        .map((d) => Debt(
              nom: d.nom,
              montant: d.montant,
              tauxAnnuel: d.tauxAnnuel / 100,
              mensualiteMin: d.mensualiteMin,
            ))
        .toList();
    if (dettes.isEmpty) return null;
    return RepaymentPlanner.plan(
      dettes: dettes,
      budgetMensuelRemboursement: _budgetMensuel,
    );
  }

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
            foregroundColor: MintColors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'PLAN DE REMBOURSEMENT',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: MintColors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── P10-F : Mode survie MINT ──────────────────────
                DebtSurvivalWidget(
                  totalDebt: _dettes.fold<double>(0, (s, d) => s + d.montant),
                  monthlyMargin: _budgetMensuel -
                      _dettes.fold<double>(0, (s, d) => s + d.mensualiteMin),
                  daysSinceLastLate: 0,
                  monthlyIncome: 6000,
                ),
                const SizedBox(height: 24),

                // Chiffre choc
                if (result != null) ...[
                  _buildChiffreChoc(result),
                  const SizedBox(height: 24),
                ],

                // Liste des dettes
                _buildDettesSection(),
                const SizedBox(height: 24),

                // Budget mensuel
                _buildBudgetSection(),
                const SizedBox(height: 24),

                // Comparaison strategies
                if (result != null) ...[
                  _buildComparisonSection(result),
                  const SizedBox(height: 24),

                  // Timeline
                  _buildTimelineSection(result),
                  const SizedBox(height: 24),

                  // Disclaimer
                  _buildDisclaimer(result.disclaimer),
                ] else
                  _buildEmptyState(),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChoc(RepaymentComparisonResult result) {
    final color = switch (result.chiffreChoc.niveau) {
      DebtRiskLevel.vert => MintColors.success,
      DebtRiskLevel.orange => MintColors.warning,
      DebtRiskLevel.rouge => MintColors.error,
    };

    final meilleur = result.avalanche.interetsTotaux <=
            result.bouleDeNeige.interetsTotaux
        ? result.avalanche
        : result.bouleDeNeige;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.2)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        children: [
          Text(
            'Libere dans',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${meilleur.moisJusquaLiberation} mois',
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          if (result.economieInterets > 0)
            Text(
              'CHF ${formatChf(result.economieInterets)} d\'interets economises avec avalanche',
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDettesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MES DETTES',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: MintColors.primary),
                onPressed: _addDebt,
                tooltip: 'Ajouter une dette',
              ),
            ],
          ),
          const SizedBox(height: 8),

          for (int i = 0; i < _dettes.length; i++) ...[
            _buildDebtCard(i),
            if (i < _dettes.length - 1) const SizedBox(height: 12),
          ],

          if (_dettes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Ajoutez vos dettes pour generer un plan de remboursement.',
                  style: TextStyle(
                    fontSize: 13,
                    color: MintColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(int index) {
    final dette = _dettes[index];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: dette.nom,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Nom de la dette',
                  ),
                  onChanged: (v) => setState(() => dette.nom = v),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: MintColors.redMaterial, size: 20),
                onPressed: () => setState(() => _dettes.removeAt(index)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Montant
          _buildMiniSlider(
            label: 'Montant',
            value: dette.montant,
            min: 500,
            max: 100000,
            divisions: 199,
            format: 'CHF ${formatChf(dette.montant)}',
            onChanged: (v) => setState(() => dette.montant = v),
          ),
          const SizedBox(height: 4),

          // Taux
          _buildMiniSlider(
            label: 'Taux annuel',
            value: dette.tauxAnnuel,
            min: 0.5,
            max: 20.0,
            divisions: 39,
            format: '${dette.tauxAnnuel.toStringAsFixed(1)}%',
            onChanged: (v) => setState(() => dette.tauxAnnuel = v),
          ),
          const SizedBox(height: 4),

          // Mensualite min
          _buildMiniSlider(
            label: 'Mensualite min',
            value: dette.mensualiteMin,
            min: 50,
            max: 3000,
            divisions: 59,
            format: 'CHF ${formatChf(dette.mensualiteMin)}',
            onChanged: (v) => setState(() => dette.mensualiteMin = v),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String format,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: MintColors.textMuted),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 80,
          child: Text(
            format,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _addDebt() {
    setState(() {
      _dettes.add(_DebtInput(
        nom: 'Nouvelle dette',
        montant: 5000,
        tauxAnnuel: 5.0,
        mensualiteMin: 100,
      ));
    });
  }

  Widget _buildBudgetSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BUDGET MENSUEL REMBOURSEMENT',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: 'Budget total / mois',
            value: _budgetMensuel,
            min: 200,
            max: 5000,
            divisions: 48,
            format: 'CHF ${formatChf(_budgetMensuel)}',
            onChanged: (v) => setState(() => _budgetMensuel = v),
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

  Widget _buildComparisonSection(RepaymentComparisonResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPARAISON DES STRATEGIES',
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
              child: _buildStrategyCard(
                title: 'AVALANCHE',
                subtitle: 'Taux haut d\'abord',
                mois: result.avalanche.moisJusquaLiberation,
                interets: result.avalanche.interetsTotaux,
                isWinner: result.avalanche.interetsTotaux <=
                    result.bouleDeNeige.interetsTotaux,
                icon: Icons.trending_down,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStrategyCard(
                title: 'BOULE DE NEIGE',
                subtitle: 'Petit solde d\'abord',
                mois: result.bouleDeNeige.moisJusquaLiberation,
                interets: result.bouleDeNeige.interetsTotaux,
                isWinner: result.bouleDeNeige.interetsTotaux <
                    result.avalanche.interetsTotaux,
                icon: Icons.ac_unit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildComparisonRow(
                'Date liberation',
                '${result.avalanche.moisJusquaLiberation} mois',
                '${result.bouleDeNeige.moisJusquaLiberation} mois',
              ),
              const SizedBox(height: 8),
              _buildComparisonRow(
                'Interets totaux',
                'CHF ${formatChf(result.avalanche.interetsTotaux)}',
                'CHF ${formatChf(result.bouleDeNeige.interetsTotaux)}',
              ),
              if (result.economieInterets > 0) ...[
                const Divider(height: 16),
                Text(
                  'Difference : CHF ${formatChf(result.economieInterets)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.success,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStrategyCard({
    required String title,
    required String subtitle,
    required int mois,
    required double interets,
    required bool isWinner,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner ? MintColors.success : MintColors.border,
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$mois mois',
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isWinner ? MintColors.success : MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'CHF ${formatChf(interets)} interets',
            style: TextStyle(
              fontSize: 11,
              color: MintColors.redDeep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
      String label, String valueA, String valueB) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: MintColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            valueA,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            valueB,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineSection(RepaymentComparisonResult result) {
    // Show avalanche timeline (generally better)
    final timeline = result.avalanche.timeline;
    if (timeline.isEmpty) return const SizedBox.shrink();

    // Sample: show every N months to avoid too many rows
    final step = timeline.length > 24 ? (timeline.length ~/ 12) : 1;
    final sampled = <RepaymentMonth>[];
    for (int i = 0; i < timeline.length; i += step) {
      sampled.add(timeline[i]);
    }
    // Always include last month
    if (sampled.last.mois != timeline.last.mois) {
      sampled.add(timeline.last);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TIMELINE (AVALANCHE)',
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
                width: 50,
                child: Text('Mois',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text('Paiement',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
              ),
              Expanded(
                child: Text('Solde restant',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
          const Divider(height: 16),

          // Scrollable rows
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sampled.length,
              itemBuilder: (context, index) {
                final month = sampled[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${month.mois}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'CHF ${formatChf(month.paiementTotal)}',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'CHF ${formatChf(month.soldeTotal)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: month.soldeTotal <= 0.01
                                ? MintColors.success
                                : MintColors.textPrimary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              color: MintColors.textMuted, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Ajoutez vos dettes et definissez votre budget mensuel '
            'de remboursement pour voir le plan.',
            style: TextStyle(
              fontSize: 14,
              color: MintColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: MintColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              disclaimer,
              style: TextStyle(
                fontSize: 11,
                color: MintColors.deepOrange,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modele mutable pour les inputs de dette
class _DebtInput {
  String nom;
  double montant;
  double tauxAnnuel; // en % (ex: 9.9)
  double mensualiteMin;

  _DebtInput({
    required this.nom,
    required this.montant,
    required this.tauxAnnuel,
    required this.mensualiteMin,
  });
}
