import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/job_comparison_service.dart';
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

/// Delta formatted with sign.
String _deltaFmt(double value) {
  final prefix = value >= 0 ? '+' : '';
  return '$prefix${_formatChfSwiss(value)}';
}

class JobComparisonScreen extends StatefulWidget {
  const JobComparisonScreen({super.key});

  @override
  State<JobComparisonScreen> createState() => _JobComparisonScreenState();
}

class _JobComparisonScreenState extends State<JobComparisonScreen> {
  // Scroll controller for smooth scroll to results
  final _scrollController = ScrollController();
  final _resultsKey = GlobalKey();

  // Shared
  int _age = 35;

  // Current job inputs
  double _currentSalaireBrut = 85000;
  double _currentPartEmployeur = 50;
  double _currentTauxConversion = 5.2;
  double _currentAvoirVieillesse = 120000;
  double _currentCouvertureInvalidite = 40;
  double _currentCapitalDeces = 200000;
  double _currentRachatMax = 80000;
  bool _currentHasIjm = true;

  // New job inputs
  double _newSalaireBrut = 95000;
  double _newPartEmployeur = 50;
  double _newTauxConversion = 5.2;
  double _newAvoirVieillesse = 120000;
  double _newCouvertureInvalidite = 40;
  double _newCapitalDeces = 150000;
  double _newRachatMax = 40000;
  bool _newHasIjm = true;

  // Collapsible state
  bool _currentJobExpanded = true;
  bool _newJobExpanded = true;

  // Result
  JobComparisonResult? _result;

  // Checklist state (local only)
  List<bool> _checklistState = [];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _compare() {
    final current = LPPPlanInput(
      salaireBrut: _currentSalaireBrut,
      partEmployeurPct: _currentPartEmployeur,
      tauxConversionSurobligatoire: _currentTauxConversion,
      avoirVieillesse: _currentAvoirVieillesse,
      renteInvaliditePct: _currentCouvertureInvalidite,
      capitalDeces: _currentCapitalDeces,
      rachatMaximum: _currentRachatMax,
      hasIjm: _currentHasIjm,
    );

    final newJob = LPPPlanInput(
      salaireBrut: _newSalaireBrut,
      partEmployeurPct: _newPartEmployeur,
      tauxConversionSurobligatoire: _newTauxConversion,
      avoirVieillesse: _newAvoirVieillesse,
      renteInvaliditePct: _newCouvertureInvalidite,
      capitalDeces: _newCapitalDeces,
      rachatMaximum: _newRachatMax,
      hasIjm: _newHasIjm,
    );

    setState(() {
      _result = JobComparisonService.compare(
        current: current,
        newJob: newJob,
        age: _age,
      );
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
        title: const Text('Comparer deux emplois'),
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
            _buildAgeSlider(),
            const SizedBox(height: 24),
            _buildJobSection(
              title: 'EMPLOI ACTUEL',
              expanded: _currentJobExpanded,
              onToggle: () =>
                  setState(() => _currentJobExpanded = !_currentJobExpanded),
              salaireBrut: _currentSalaireBrut,
              onSalaireBrutChanged: (v) =>
                  setState(() => _currentSalaireBrut = v),
              partEmployeur: _currentPartEmployeur,
              onPartEmployeurChanged: (v) =>
                  setState(() => _currentPartEmployeur = v),
              tauxConversion: _currentTauxConversion,
              onTauxConversionChanged: (v) =>
                  setState(() => _currentTauxConversion = v),
              avoirVieillesse: _currentAvoirVieillesse,
              onAvoirVieillesseChanged: (v) =>
                  setState(() => _currentAvoirVieillesse = v),
              couvertureInvalidite: _currentCouvertureInvalidite,
              onCouvertureInvaliditeChanged: (v) =>
                  setState(() => _currentCouvertureInvalidite = v),
              capitalDeces: _currentCapitalDeces,
              onCapitalDecesChanged: (v) =>
                  setState(() => _currentCapitalDeces = v),
              rachatMax: _currentRachatMax,
              onRachatMaxChanged: (v) =>
                  setState(() => _currentRachatMax = v),
              hasIjm: _currentHasIjm,
              onIjmChanged: (v) => setState(() => _currentHasIjm = v),
              accentColor: MintColors.primary,
              icon: Icons.business,
            ),
            const SizedBox(height: 24),
            _buildJobSection(
              title: 'EMPLOI ENVISAGE',
              expanded: _newJobExpanded,
              onToggle: () =>
                  setState(() => _newJobExpanded = !_newJobExpanded),
              salaireBrut: _newSalaireBrut,
              onSalaireBrutChanged: (v) =>
                  setState(() => _newSalaireBrut = v),
              partEmployeur: _newPartEmployeur,
              onPartEmployeurChanged: (v) =>
                  setState(() => _newPartEmployeur = v),
              tauxConversion: _newTauxConversion,
              onTauxConversionChanged: (v) =>
                  setState(() => _newTauxConversion = v),
              avoirVieillesse: _newAvoirVieillesse,
              onAvoirVieillesseChanged: (v) =>
                  setState(() => _newAvoirVieillesse = v),
              couvertureInvalidite: _newCouvertureInvalidite,
              onCouvertureInvaliditeChanged: (v) =>
                  setState(() => _newCouvertureInvalidite = v),
              capitalDeces: _newCapitalDeces,
              onCapitalDecesChanged: (v) =>
                  setState(() => _newCapitalDeces = v),
              rachatMax: _newRachatMax,
              onRachatMaxChanged: (v) =>
                  setState(() => _newRachatMax = v),
              hasIjm: _newHasIjm,
              onIjmChanged: (v) => setState(() => _newHasIjm = v),
              accentColor: const Color(0xFFEA580C), // orange accent
              icon: Icons.work_outline,
            ),
            const SizedBox(height: 24),
            _buildCompareButton(),
            const SizedBox(height: 24),
            if (_result != null) ...[
              Container(key: _resultsKey),
              _buildVerdictCard(),
              const SizedBox(height: 24),
              _buildComparisonTable(),
              const SizedBox(height: 24),
              _buildLifetimeImpactCard(),
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
              color: const Color(0xFFEA580C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.swap_horiz,
                color: Color(0xFFEA580C), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comparer deux emplois',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Decouvre le salaire invisible',
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

  // --- Introduction Card ---
  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEA580C).withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEA580C).withOpacity(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              size: 20, color: const Color(0xFFEA580C).withOpacity(0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Le salaire brut ne dit pas tout. Compare le salaire invisible '
              '(prevoyance, assurances) entre deux postes.',
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

  // --- Age Slider ---
  Widget _buildAgeSlider() {
    return SimulatorCard(
      title: 'Ton age',
      subtitle: 'Utilise pour projeter le capital retraite',
      icon: Icons.person_outline,
      child: _buildSlider(
        label: 'Age',
        value: _age.toDouble(),
        min: 25,
        max: 64,
        divisions: 39,
        format: (v) => '${v.toInt()} ans',
        onChanged: (v) => setState(() => _age = v.toInt()),
      ),
    );
  }

  // --- Job Section (Collapsible) ---
  Widget _buildJobSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required double salaireBrut,
    required ValueChanged<double> onSalaireBrutChanged,
    required double partEmployeur,
    required ValueChanged<double> onPartEmployeurChanged,
    required double tauxConversion,
    required ValueChanged<double> onTauxConversionChanged,
    required double avoirVieillesse,
    required ValueChanged<double> onAvoirVieillesseChanged,
    required double couvertureInvalidite,
    required ValueChanged<double> onCouvertureInvaliditeChanged,
    required double capitalDeces,
    required ValueChanged<double> onCapitalDecesChanged,
    required double rachatMax,
    required ValueChanged<double> onRachatMaxChanged,
    required bool hasIjm,
    required ValueChanged<bool> onIjmChanged,
    required Color accentColor,
    required IconData icon,
  }) {
    return SimulatorCard(
      title: title,
      subtitle: _chfFmt(salaireBrut),
      icon: icon,
      accentColor: accentColor,
      child: Column(
        children: [
          // Collapse toggle
          InkWell(
            onTap: onToggle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  expanded ? 'Reduire' : 'Voir les details',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: accentColor,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 16),
            _buildSlider(
              label: 'Salaire brut annuel',
              value: salaireBrut,
              min: 40000,
              max: 250000,
              divisions: 42,
              format: (v) => _chfFmt(v),
              onChanged: onSalaireBrutChanged,
            ),
            const SizedBox(height: 16),
            _buildPartEmployeurChips(
              value: partEmployeur,
              onChanged: onPartEmployeurChanged,
              accentColor: accentColor,
            ),
            const SizedBox(height: 16),
            _buildSlider(
              label: 'Taux de conversion',
              value: tauxConversion,
              min: 4.0,
              max: 6.8,
              divisions: 28,
              format: (v) => '${v.toStringAsFixed(1)}%',
              onChanged: onTauxConversionChanged,
            ),
            const SizedBox(height: 16),
            _buildSlider(
              label: 'Avoir de vieillesse actuel',
              value: avoirVieillesse,
              min: 0,
              max: 1000000,
              divisions: 100,
              format: (v) => _chfFmt(v),
              onChanged: onAvoirVieillesseChanged,
            ),
            const SizedBox(height: 16),
            _buildSlider(
              label: 'Couverture invalidite',
              value: couvertureInvalidite,
              min: 0,
              max: 80,
              divisions: 16,
              format: (v) => '${v.toInt()}%',
              onChanged: onCouvertureInvaliditeChanged,
            ),
            const SizedBox(height: 16),
            _buildSlider(
              label: 'Capital-deces',
              value: capitalDeces,
              min: 0,
              max: 500000,
              divisions: 50,
              format: (v) => _chfFmt(v),
              onChanged: onCapitalDecesChanged,
            ),
            const SizedBox(height: 16),
            _buildSlider(
              label: 'Rachat maximum',
              value: rachatMax,
              min: 0,
              max: 500000,
              divisions: 50,
              format: (v) => _chfFmt(v),
              onChanged: onRachatMaxChanged,
            ),
            const SizedBox(height: 16),
            _buildIjmSwitch(
              value: hasIjm,
              onChanged: onIjmChanged,
            ),
          ],
        ],
      ),
    );
  }

  // --- Part Employeur Chips ---
  Widget _buildPartEmployeurChips({
    required double value,
    required ValueChanged<double> onChanged,
    required Color accentColor,
  }) {
    final options = [50.0, 55.0, 60.0, 65.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Part employeur LPP',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textPrimary,
              ),
            ),
            Text(
              '${value.toInt()}%',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final selected = value == opt;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: opt != options.last ? 8 : 0,
                ),
                child: GestureDetector(
                  onTap: () => onChanged(opt),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? accentColor.withOpacity(0.1)
                          : MintColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? accentColor
                            : MintColors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${opt.toInt()}%',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected
                              ? accentColor
                              : MintColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- IJM Switch ---
  Widget _buildIjmSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'IJM collective incluse',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: MintColors.primary,
        ),
      ],
    );
  }

  // --- Compare Button ---
  Widget _buildCompareButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _compare,
        icon: const Icon(Icons.compare_arrows, size: 20),
        label: Text(
          'Comparer',
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

  // --- Verdict Card ---
  Widget _buildVerdictCard() {
    final r = _result!;
    Color verdictColor;
    IconData verdictIcon;

    switch (r.verdict) {
      case ComparisonVerdict.nouveauMeilleur:
        verdictColor = MintColors.success;
        verdictIcon = Icons.thumb_up_outlined;
      case ComparisonVerdict.actuelMeilleur:
        verdictColor = MintColors.error;
        verdictIcon = Icons.warning_amber_rounded;
      case ComparisonVerdict.comparable:
        verdictColor = MintColors.warning;
        verdictIcon = Icons.balance;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            verdictColor.withOpacity(0.08),
            verdictColor.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: verdictColor.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: verdictColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(verdictIcon, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'VERDICT',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            r.verdictDetail,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${r.axes.where((a) => a.isPositive).length} axes favorables '
            'sur ${r.axes.length}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // --- 7-Axis Comparison Table ---
  Widget _buildComparisonTable() {
    final r = _result!;
    return SimulatorCard(
      title: 'Comparaison detaillee',
      subtitle: '7 axes de prevoyance',
      icon: Icons.table_chart_outlined,
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Axe',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Actuel',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Nouveau',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Delta',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Data rows
          ...List.generate(r.axes.length, (index) {
            final axis = r.axes[index];
            final isEven = index % 2 == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: isEven
                    ? Colors.transparent
                    : MintColors.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Icon(
                          axis.isPositive
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          size: 14,
                          color: axis.isPositive
                              ? MintColors.success
                              : MintColors.error,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            axis.name,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: MintColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatChfSwiss(axis.currentValue),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatChfSwiss(axis.newValue),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _deltaFmt(axis.delta),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: axis.isPositive
                            ? MintColors.success
                            : MintColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- Lifetime Impact Card ---
  Widget _buildLifetimeImpactCard() {
    final r = _result!;
    final annualDelta = r.annualPensionDelta;
    final monthlyDelta = annualDelta / 12;
    final isPositive = annualDelta >= 0;
    final betterJob = isPositive ? 'Le nouveau poste' : 'Le poste actuel';

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
              Icon(Icons.timeline, color: MintColors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                'IMPACT SUR TOUTE LA RETRAITE',
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
          Text(
            '$betterJob vaut ${_chfFmt(annualDelta.abs())}/an de plus '
            'en rente viagere, soit ${_chfFmt(monthlyDelta.abs())}/mois '
            'A VIE apres la retraite.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sur 20 ans de retraite : ${_chfFmt(r.lifetimePensionDelta.abs())}',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MintColors.info,
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
      title: 'Avant de signer',
      subtitle: 'Checklist de verification',
      icon: Icons.checklist,
      accentColor: MintColors.primary,
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
          'Qu\'est-ce que le salaire invisible ?',
          'Le "salaire invisible" represente 10-30% de ta remuneration totale. '
              'Il inclut la part employeur a la caisse de pension (LPP), les assurances '
              '(IJM, accident), et parfois des avantages complementaires. Deux postes '
              'au meme salaire brut peuvent offrir des protections tres differentes.',
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          'Comment lire mon certificat de prevoyance ?',
          'Ton certificat de prevoyance (LPP) contient toutes les informations '
              'necessaires : salaire assure, deduction de coordination, taux de '
              'cotisation, avoir de vieillesse, taux de conversion, prestations '
              'de risque (invalidite et deces), et rachat possible. Demande-le '
              'a ton RH ou a ta caisse de pension.',
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              'Les resultats presentes sont des estimations a titre indicatif. '
              'Ils ne constituent pas un conseil financier personnalise. '
              'Consultez votre caisse de pension et un conseiller qualifie '
              'avant toute decision.',
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
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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
