import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/life_events_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';

/// Swiss CHF formatter with apostrophe grouping.
String _formatChfSwiss(double value) {
  final intVal = value.round();
  final isNeg = intVal < 0;
  final str = intVal.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write("'");
    }
    buffer.write(str[i]);
  }
  return '${isNeg ? '-' : ''}${buffer.toString()}';
}

/// Swiss CHF formatter with prefix.
String _chfFmt(double value) {
  return 'CHF\u00A0${_formatChfSwiss(value)}';
}

class DivorceSimulatorScreen extends StatefulWidget {
  const DivorceSimulatorScreen({super.key});

  @override
  State<DivorceSimulatorScreen> createState() =>
      _DivorceSimulatorScreenState();
}

class _DivorceSimulatorScreenState extends State<DivorceSimulatorScreen> {
  final _scrollController = ScrollController();
  final _resultsKey = GlobalKey();

  // ---- Input State ----
  // Section 1 — Situation familiale
  int _marriageDuration = 10;
  int _numberOfChildren = 1;
  MatrimonialRegime _regime = MatrimonialRegime.participationAuxAcquets;

  // Section 2 — Revenus
  double _incomeConjoint1 = 90000;
  double _incomeConjoint2 = 50000;

  // Section 3 — Prévoyance
  double _lppConjoint1 = 180000;
  double _lppConjoint2 = 80000;
  double _pillar3aConjoint1 = 60000;
  double _pillar3aConjoint2 = 20000;

  // Section 4 — Patrimoine
  double _fortuneCommune = 200000;
  double _dettesCommunes = 0;

  // Result
  DivorceResult? _result;

  // Checklist state
  List<bool> _checklistState = [];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _simulate() {
    final input = DivorceInput(
      marriageDurationYears: _marriageDuration,
      numberOfChildren: _numberOfChildren,
      regime: _regime,
      incomeConjoint1: _incomeConjoint1,
      incomeConjoint2: _incomeConjoint2,
      lppConjoint1: _lppConjoint1,
      lppConjoint2: _lppConjoint2,
      pillar3aConjoint1: _pillar3aConjoint1,
      pillar3aConjoint2: _pillar3aConjoint2,
      fortuneCommune: _fortuneCommune,
      dettesCommunes: _dettesCommunes,
    );

    setState(() {
      _result = DivorceService.simulate(input: input);
      _checklistState = List.filled(_result!.checklist.length, false);
    });

    // Smooth scroll to results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resultsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _resultsKey.currentContext!,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: const Text('Divorce — Impact financier'),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildIntroCard(),
            const SizedBox(height: 24),
            _buildSituationFamilialeSection(),
            const SizedBox(height: 12),
            _buildRevenusSection(),
            const SizedBox(height: 12),
            _buildPrevoyanceSection(),
            const SizedBox(height: 12),
            _buildPatrimoineSection(),
            const SizedBox(height: 24),
            _buildSimulateButton(),
            const SizedBox(height: 24),
            if (_result != null) ...[
              Container(key: _resultsKey),
              _buildLppSplitCard(),
              const SizedBox(height: 24),
              _buildTaxImpactCard(),
              const SizedBox(height: 24),
              _buildPatrimoineSplitCard(),
              const SizedBox(height: 24),
              _buildPensionAlimentaireCard(),
              const SizedBox(height: 24),
              if (_result!.alerts.isNotEmpty) ...[
                _buildAlertsSection(),
                const SizedBox(height: 24),
              ],
              _buildChecklistSection(),
              const SizedBox(height: 24),
            ],
            _buildEducationalFooter(),
            const SizedBox(height: 24),
            _buildDisclaimer(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.shade600.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.family_restroom,
                color: Colors.purple.shade600, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impact financier d\'un divorce',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Anticipez les consequences financieres',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Intro Card ---
  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.shade600.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.purple.shade600.withOpacity(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              size: 20, color: Colors.purple.shade600.withOpacity(0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Un divorce a des consequences financieres souvent '
              'sous-estimees : partage du patrimoine, de la prevoyance '
              '(LPP/3a), impact fiscal et pension alimentaire. '
              'Cet outil vous aide a y voir plus clair.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Section 1: Situation Familiale ---
  Widget _buildSituationFamilialeSection() {
    return SimulatorCard(
      title: 'SITUATION FAMILIALE',
      subtitle: 'Duree du mariage, enfants, regime',
      icon: Icons.people_outline,
      accentColor: Colors.purple.shade600,
      child: Column(
        children: [
          _buildSlider(
            label: 'Duree du mariage',
            value: _marriageDuration.toDouble(),
            min: 1,
            max: 40,
            divisions: 39,
            format: (v) => '${v.toInt()} ans',
            onChanged: (v) => setState(() => _marriageDuration = v.toInt()),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Nombre d\'enfants',
            value: _numberOfChildren.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            format: (v) => '${v.toInt()}',
            onChanged: (v) =>
                setState(() => _numberOfChildren = v.toInt()),
          ),
          const SizedBox(height: 16),
          _buildRegimeChips(),
        ],
      ),
    );
  }

  // --- Regime Chips ---
  Widget _buildRegimeChips() {
    final options = <MapEntry<MatrimonialRegime, String>>[
      const MapEntry(
          MatrimonialRegime.participationAuxAcquets, 'Participation aux acquets (defaut)'),
      const MapEntry(
          MatrimonialRegime.communauteDeBiens, 'Communaute de biens'),
      const MapEntry(
          MatrimonialRegime.separationDeBiens, 'Separation de biens'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Regime matrimonial',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final selected = _regime == opt.key;
            return GestureDetector(
              onTap: () => setState(() => _regime = opt.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.purple.shade600.withOpacity(0.1)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? Colors.purple.shade600
                        : MintColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  opt.value,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? Colors.purple.shade600
                        : MintColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Section 2: Revenus ---
  Widget _buildRevenusSection() {
    return SimulatorCard(
      title: 'REVENUS',
      subtitle: 'Revenu annuel de chaque conjoint',
      icon: Icons.payments_outlined,
      accentColor: Colors.purple.shade600,
      child: Column(
        children: [
          _buildSlider(
            label: 'Conjoint 1 — revenu annuel',
            value: _incomeConjoint1,
            min: 0,
            max: 300000,
            divisions: 60,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _incomeConjoint1 = v),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Conjoint 2 — revenu annuel',
            value: _incomeConjoint2,
            min: 0,
            max: 300000,
            divisions: 60,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _incomeConjoint2 = v),
          ),
        ],
      ),
    );
  }

  // --- Section 3: Prévoyance ---
  Widget _buildPrevoyanceSection() {
    return SimulatorCard(
      title: 'PREVOYANCE',
      subtitle: 'LPP et 3a accumules pendant le mariage',
      icon: Icons.account_balance_outlined,
      accentColor: Colors.purple.shade600,
      child: Column(
        children: [
          _buildSlider(
            label: 'LPP Conjoint 1 (pendant le mariage)',
            value: _lppConjoint1,
            min: 0,
            max: 500000,
            divisions: 100,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _lppConjoint1 = v),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'LPP Conjoint 2 (pendant le mariage)',
            value: _lppConjoint2,
            min: 0,
            max: 500000,
            divisions: 100,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _lppConjoint2 = v),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: '3a Conjoint 1',
            value: _pillar3aConjoint1,
            min: 0,
            max: 200000,
            divisions: 40,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _pillar3aConjoint1 = v),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: '3a Conjoint 2',
            value: _pillar3aConjoint2,
            min: 0,
            max: 200000,
            divisions: 40,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _pillar3aConjoint2 = v),
          ),
        ],
      ),
    );
  }

  // --- Section 4: Patrimoine ---
  Widget _buildPatrimoineSection() {
    return SimulatorCard(
      title: 'PATRIMOINE',
      subtitle: 'Fortune et dettes communes',
      icon: Icons.home_outlined,
      accentColor: Colors.purple.shade600,
      child: Column(
        children: [
          _buildSlider(
            label: 'Fortune commune',
            value: _fortuneCommune,
            min: 0,
            max: 2000000,
            divisions: 200,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _fortuneCommune = v),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Dettes communes',
            value: _dettesCommunes,
            min: 0,
            max: 1000000,
            divisions: 100,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _dettesCommunes = v),
          ),
        ],
      ),
    );
  }

  // --- Simulate Button ---
  Widget _buildSimulateButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _simulate,
        icon: const Icon(Icons.calculate_outlined, size: 20),
        label: Text(
          'Simuler',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: MintColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // --- LPP Split Card ---
  Widget _buildLppSplitCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.info.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.info.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz, color: MintColors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                'PARTAGE LPP',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MintColors.info,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow('Total LPP (pendant le mariage)',
              _chfFmt(r.lppSplit.totalLpp)),
          const SizedBox(height: 8),
          _buildResultRow(
              'Part Conjoint 1', _chfFmt(r.lppSplit.shareConjoint1)),
          _buildResultRow(
              'Part Conjoint 2', _chfFmt(r.lppSplit.shareConjoint2)),
          const SizedBox(height: 12),
          if (r.lppSplit.transferAmount > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.arrow_forward,
                      size: 16, color: MintColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Transfert de ${_chfFmt(r.lppSplit.transferAmount)} '
                      '(${r.lppSplit.transferDirection})',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MintColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Tax Impact Card ---
  Widget _buildTaxImpactCard() {
    final r = _result!;
    final isIncrease = r.taxImpact.delta > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isIncrease ? MintColors.warning : MintColors.success)
            .withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isIncrease ? MintColors.warning : MintColors.success)
              .withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long,
                  color: isIncrease ? MintColors.warning : MintColors.success,
                  size: 18),
              const SizedBox(width: 8),
              Text(
                'IMPACT FISCAL',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      isIncrease ? MintColors.warning : MintColors.success,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow('Impot estime (marie)',
              _chfFmt(r.taxImpact.estimatedTaxMarried)),
          const SizedBox(height: 8),
          _buildResultRow('Impot Conjoint 1 (individuel)',
              _chfFmt(r.taxImpact.estimatedTaxConjoint1)),
          _buildResultRow('Impot Conjoint 2 (individuel)',
              _chfFmt(r.taxImpact.estimatedTaxConjoint2)),
          _buildResultRow(
              'Total apres divorce', _chfFmt(r.taxImpact.totalTaxAfter)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isIncrease ? MintColors.warning : MintColors.success)
                  .withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isIncrease ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color:
                      isIncrease ? MintColors.warning : MintColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Difference : ${isIncrease ? '+' : ''}${_chfFmt(r.taxImpact.delta)}/an',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isIncrease
                          ? MintColors.warning
                          : MintColors.success,
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

  // --- Patrimoine Split Card ---
  Widget _buildPatrimoineSplitCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.shade600.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.purple.shade600.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline,
                  color: Colors.purple.shade600, size: 18),
              const SizedBox(width: 8),
              Text(
                'PARTAGE DU PATRIMOINE',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.purple.shade600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResultRow('Fortune nette',
              _chfFmt(r.patrimoineSplit.fortuneNette)),
          const SizedBox(height: 8),
          // Visual bar for split
          _buildSplitBar(
            r.patrimoineSplit.shareConjoint1,
            r.patrimoineSplit.shareConjoint2,
          ),
          const SizedBox(height: 12),
          _buildResultRow(
              'Conjoint 1', _chfFmt(r.patrimoineSplit.shareConjoint1)),
          _buildResultRow(
              'Conjoint 2', _chfFmt(r.patrimoineSplit.shareConjoint2)),
        ],
      ),
    );
  }

  // --- Split Bar Visual ---
  Widget _buildSplitBar(double share1, double share2) {
    final total = share1.abs() + share2.abs();
    final pct1 = total > 0 ? share1.abs() / total : 0.5;
    return Container(
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Flexible(
              flex: (pct1 * 100).toInt().clamp(1, 99),
              child: Container(
                color: Colors.purple.shade400,
                alignment: Alignment.center,
                child: Text(
                  'C1',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Flexible(
              flex: ((1 - pct1) * 100).toInt().clamp(1, 99),
              child: Container(
                color: Colors.purple.shade200,
                alignment: Alignment.center,
                child: Text(
                  'C2',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Pension Alimentaire Card ---
  Widget _buildPensionAlimentaireCard() {
    final r = _result!;
    if (r.pensionAlimentaireMonthly <= 0) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.warning.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.warning.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.child_care, color: MintColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                'PENSION ALIMENTAIRE (ESTIMATION)',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MintColors.warning,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${_chfFmt(r.pensionAlimentaireMonthly)}/mois',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'soit ${_chfFmt(r.pensionAlimentaireMonthly * 12)}/an',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Estimation basee sur l\'ecart de revenus et le nombre '
            'd\'enfants. Le montant reel depend de nombreux facteurs '
            '(garde, besoins, train de vie).',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // --- Alerts Section ---
  Widget _buildAlertsSection() {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'POINTS D\'ATTENTION',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ...r.alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MintColors.warning.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: MintColors.warning.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: MintColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        alert,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // --- Checklist Section ---
  Widget _buildChecklistSection() {
    final r = _result!;
    return SimulatorCard(
      title: 'Actions a entreprendre',
      subtitle: 'Checklist de preparation',
      icon: Icons.checklist,
      accentColor: Colors.purple.shade600,
      child: Column(
        children: List.generate(r.checklist.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _checklistState[index] = !_checklistState[index];
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _checklistState[index]
                      ? MintColors.success.withOpacity(0.06)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _checklistState[index]
                        ? MintColors.success.withOpacity(0.3)
                        : MintColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _checklistState[index]
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                      color: _checklistState[index]
                          ? MintColors.success
                          : MintColors.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        r.checklist[index],
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _checklistState[index]
                              ? MintColors.textSecondary
                              : MintColors.textPrimary,
                          decoration: _checklistState[index]
                              ? TextDecoration.lineThrough
                              : null,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- Educational Footer ---
  Widget _buildEducationalFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPRENDRE',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableTile(
          'Qu\'est-ce que la participation aux acquets ?',
          'La participation aux acquets est le regime matrimonial par defaut en '
              'Suisse (CC art. 181 ss). Chaque conjoint conserve ses biens propres '
              '(ceux acquis avant le mariage ou par succession/donation). Les acquets '
              '(biens acquis pendant le mariage) sont partages a parts egales en cas '
              'de divorce. C\'est le regime le plus courant en Suisse.',
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          'Comment fonctionne le partage LPP ?',
          'Depuis le 1er janvier 2017 (CC art. 122), les avoirs de prevoyance '
              'professionnelle (2e pilier) accumules pendant le mariage sont partages '
              'a parts egales en cas de divorce. Le partage se fait directement entre '
              'les deux caisses de pension, sans passage par le compte personnel des '
              'conjoints. C\'est un droit imperieux auquel les conjoints ne peuvent '
              'renoncer que dans des conditions strictes.',
        ),
      ],
    );
  }

  // --- Expandable Tile ---
  Widget _buildExpandableTile(String title, String content) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
            ),
          ),
          children: [
            Text(
              content,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Disclaimer ---
  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les resultats presentes sont des estimations a titre indicatif '
              'et ne constituent pas un conseil juridique ou financier '
              'personnalise. Chaque situation est unique. Consultez un(e) '
              'avocat(e) specialise(e) en droit de la famille et un conseiller '
              'financier avant toute decision.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.orange.shade800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Result Row Helper ---
  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // --- Slider (reusable, follows existing simulator pattern) ---
  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required void Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Text(
              format(value),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: MintColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 8),
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.border,
            thumbColor: MintColors.primary,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) {
              setState(() {
                onChanged(v);
              });
            },
          ),
        ),
      ],
    );
  }
}
