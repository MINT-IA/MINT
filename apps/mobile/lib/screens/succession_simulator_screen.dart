import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
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

class SuccessionSimulatorScreen extends StatefulWidget {
  const SuccessionSimulatorScreen({super.key});

  @override
  State<SuccessionSimulatorScreen> createState() =>
      _SuccessionSimulatorScreenState();
}

class _SuccessionSimulatorScreenState extends State<SuccessionSimulatorScreen> {
  final _scrollController = ScrollController();
  final _resultsKey = GlobalKey();

  // ---- Input State ----
  // Section 1 — Situation personnelle
  CivilStatus _civilStatus = CivilStatus.marie;
  int _numberOfChildren = 2;
  bool _parentsVivants = false;
  bool _hasFratrie = true;
  bool _hasConcubin = false;

  // Section 2 — Fortune
  double _fortuneTotale = 500000;
  double _avoirs3a = 80000;
  double _capitalDecesLpp = 200000;
  String _canton = 'VD';

  // Section 3 — Testament
  bool _hasTestament = false;
  String _testamentBeneficiary = 'conjoint';

  // Result
  SuccessionResult? _result;

  // Checklist state
  List<bool> _checklistState = [];

  static List<String> get _cantons => sortedCantonCodes;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _simulate() {
    final input = SuccessionInput(
      civilStatus: _civilStatus,
      numberOfChildren: _numberOfChildren,
      parentsVivants: _parentsVivants,
      hasFratrie: _hasFratrie,
      hasConcubin: _hasConcubin,
      fortuneTotale: _fortuneTotale,
      avoirs3a: _avoirs3a,
      capitalDecesLpp: _capitalDecesLpp,
      canton: _canton,
      hasTestament: _hasTestament,
      testamentBeneficiary: _hasTestament ? _testamentBeneficiary : null,
    );

    setState(() {
      _result = SuccessionService.simulate(input: input);
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
        title: Text(S.of(context)!.successionAppBarTitle),
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
            _buildSituationPersonnelleSection(),
            const SizedBox(height: 12),
            _buildFortuneSection(),
            const SizedBox(height: 12),
            _buildTestamentSection(),
            const SizedBox(height: 24),
            _buildSimulateButton(),
            const SizedBox(height: 24),
            if (_result != null) ...[
              Container(key: _resultsKey),
              _buildLegalDistributionCard(),
              const SizedBox(height: 24),
              if (_result!.testamentDistribution != null) ...[
                _buildTestamentDistributionCard(),
                const SizedBox(height: 24),
              ],
              _buildReservesCard(),
              const SizedBox(height: 24),
              _buildQuotiteDisponibleCard(),
              const SizedBox(height: 24),
              _buildFiscaliteCard(),
              const SizedBox(height: 24),
              _build3aOpp3Card(),
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
              color: Colors.teal.shade600.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.volunteer_activism,
                color: Colors.teal.shade600, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.successionHeaderTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  S.of(context)!.successionHeaderSubtitle,
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
        color: Colors.teal.shade600.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.teal.shade600.withOpacity(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              size: 20, color: Colors.teal.shade600.withOpacity(0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.successionIntroText,
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

  // --- Section 1: Situation Personnelle ---
  Widget _buildSituationPersonnelleSection() {
    return SimulatorCard(
      title: S.of(context)!.successionSituationTitle,
      subtitle: S.of(context)!.successionSituationSubtitle2,
      icon: Icons.person_outline,
      accentColor: Colors.teal.shade600,
      child: Column(
        children: [
          _buildCivilStatusChips(),
          const SizedBox(height: 16),
          _buildSlider(
            label: S.of(context)!.successionChildrenLabel,
            value: _numberOfChildren.toDouble(),
            min: 0,
            max: 6,
            divisions: 6,
            format: (v) => '${v.toInt()}',
            onChanged: (v) =>
                setState(() => _numberOfChildren = v.toInt()),
          ),
          const SizedBox(height: 16),
          _buildSwitch(
            label: S.of(context)!.successionParentsAlive,
            value: _parentsVivants,
            onChanged: (v) => setState(() => _parentsVivants = v),
          ),
          const SizedBox(height: 8),
          _buildSwitch(
            label: S.of(context)!.successionSiblings,
            value: _hasFratrie,
            onChanged: (v) => setState(() => _hasFratrie = v),
          ),
          if (_civilStatus == CivilStatus.concubinage) ...[
            const SizedBox(height: 8),
            _buildSwitch(
              label: S.of(context)!.successionConcubin,
              value: _hasConcubin,
              onChanged: (v) => setState(() => _hasConcubin = v),
            ),
          ],
        ],
      ),
    );
  }

  // --- Civil Status Chips ---
  Widget _buildCivilStatusChips() {
    final options = <MapEntry<CivilStatus, String>>[
      MapEntry(CivilStatus.marie, S.of(context)!.successionCivilMarie),
      MapEntry(CivilStatus.celibataire, S.of(context)!.successionCivilCelibataire),
      MapEntry(CivilStatus.divorce, S.of(context)!.successionCivilDivorce),
      MapEntry(CivilStatus.veuf, S.of(context)!.successionCivilVeuf),
      MapEntry(CivilStatus.concubinage, S.of(context)!.successionCivilConcubinage),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.successionCivilStatusLabel,
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
            final selected = _civilStatus == opt.key;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _civilStatus = opt.key;
                  if (opt.key == CivilStatus.concubinage) {
                    _hasConcubin = true;
                  }
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.teal.shade600.withOpacity(0.1)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? Colors.teal.shade600
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
                        ? Colors.teal.shade600
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

  // --- Section 2: Fortune ---
  Widget _buildFortuneSection() {
    return SimulatorCard(
      title: S.of(context)!.successionFortuneTitle,
      subtitle: S.of(context)!.successionFortuneSubtitle2,
      icon: Icons.account_balance_wallet_outlined,
      accentColor: Colors.teal.shade600,
      child: Column(
        children: [
          _buildSlider(
            label: S.of(context)!.successionFortuneLabel,
            value: _fortuneTotale,
            min: 0,
            max: 5000000,
            divisions: 100,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _fortuneTotale = v),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: S.of(context)!.successionAvoirs3aLabel,
            value: _avoirs3a,
            min: 0,
            max: 500000,
            divisions: 100,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _avoirs3a = v),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: S.of(context)!.successionDeathCapitalLabel,
            value: _capitalDecesLpp,
            min: 0,
            max: 500000,
            divisions: 100,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _capitalDecesLpp = v),
          ),
          const SizedBox(height: 16),
          _buildCantonDropdown(),
        ],
      ),
    );
  }

  // --- Canton Dropdown ---
  Widget _buildCantonDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.successionCanton,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _canton,
              isExpanded: true,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textPrimary,
              ),
              dropdownColor: Colors.white,
              items: _cantons.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text('$c \u2014 ${cantonFullNames[c] ?? c}'),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _canton = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- Section 3: Testament ---
  Widget _buildTestamentSection() {
    return SimulatorCard(
      title: S.of(context)!.successionTestamentTitle,
      subtitle: S.of(context)!.successionTestamentSubtitle2,
      icon: Icons.description_outlined,
      accentColor: Colors.teal.shade600,
      child: Column(
        children: [
          _buildSwitch(
            label: S.of(context)!.successionTestamentSwitch,
            value: _hasTestament,
            onChanged: (v) => setState(() => _hasTestament = v),
          ),
          if (_hasTestament) ...[
            const SizedBox(height: 16),
            _buildBeneficiaryChips(),
          ],
        ],
      ),
    );
  }

  // --- Beneficiary Chips ---
  Widget _buildBeneficiaryChips() {
    final options = <MapEntry<String, String>>[
      MapEntry('conjoint', S.of(context)!.successionBeneficiaireConjoint),
      MapEntry('enfants', S.of(context)!.successionBeneficiaireEnfants),
      MapEntry('concubin', S.of(context)!.successionBeneficiaireConcubin),
      MapEntry('tiers', S.of(context)!.successionBeneficiaireTiers),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.successionBeneficiaryQuestion,
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
            final selected = _testamentBeneficiary == opt.key;
            return GestureDetector(
              onTap: () =>
                  setState(() => _testamentBeneficiary = opt.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.teal.shade600.withOpacity(0.1)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? Colors.teal.shade600
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
                        ? Colors.teal.shade600
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

  // --- Simulate Button ---
  Widget _buildSimulateButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _simulate,
        icon: const Icon(Icons.calculate_outlined, size: 20),
        label: Text(
          S.of(context)!.successionSimulateButton,
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

  // --- Legal Distribution Card ---
  Widget _buildLegalDistributionCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.teal.shade600.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.teal.shade600.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline,
                  color: Colors.teal.shade600, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.successionLegalDistribution,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.teal.shade600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Distribution bar
          _buildDistributionBar(r.legalDistribution),
          const SizedBox(height: 16),
          ...r.legalDistribution.map((heir) => _buildHeirRow(heir)),
        ],
      ),
    );
  }

  // --- Testament Distribution Card ---
  Widget _buildTestamentDistributionCard() {
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
              Icon(Icons.description_outlined,
                  color: MintColors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.successionTestamentDistribution,
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
          _buildDistributionBar(r.testamentDistribution!),
          const SizedBox(height: 16),
          ...r.testamentDistribution!.map((heir) => _buildHeirRow(heir)),
        ],
      ),
    );
  }

  // --- Distribution Bar ---
  Widget _buildDistributionBar(List<HeirShare> heirs) {
    final colors = [
      Colors.teal.shade600,
      Colors.teal.shade400,
      Colors.teal.shade300,
      Colors.teal.shade200,
      Colors.blue.shade400,
      Colors.blue.shade300,
      Colors.purple.shade300,
      Colors.amber.shade400,
    ];

    return Container(
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: List.generate(heirs.length, (i) {
            final pct = heirs[i].percentage;
            if (pct <= 0) return const SizedBox.shrink();
            return Flexible(
              flex: (pct * 100).toInt().clamp(1, 100),
              child: Container(
                color: colors[i % colors.length],
                alignment: Alignment.center,
                child: pct > 0.12
                    ? Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            );
          }),
        ),
      ),
    );
  }

  // --- Heir Row ---
  Widget _buildHeirRow(HeirShare heir) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              heir.heirLabel,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${_chfFmt(heir.amount)} (${(heir.percentage * 100).toStringAsFixed(0)}%)',
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

  // --- Reserves Card ---
  Widget _buildReservesCard() {
    final r = _result!;
    final heirsWithReserve =
        r.legalDistribution.where((h) => h.reserve > 0).toList();
    if (heirsWithReserve.isEmpty) {
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
              Icon(Icons.shield_outlined,
                  color: MintColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.successionReservesTitle,
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
            S.of(context)!.successionReservesSubtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          ...heirsWithReserve.map((heir) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      heir.heirLabel,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                      ),
                    ),
                    Text(
                      _chfFmt(heir.reserve),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MintColors.warning,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // --- Quotité Disponible Card ---
  Widget _buildQuotiteDisponibleCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.success.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.success.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: MintColors.success, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.successionQuotiteTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MintColors.success,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _chfFmt(r.quotiteDisponible),
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.successionQuotitePct((r.quotiteDisponiblePct * 100).toStringAsFixed(0)),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.successionQuotiteDesc,
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

  // --- Fiscalité Card ---
  Widget _buildFiscaliteCard() {
    final r = _result!;
    if (r.taxByHeir.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalTax = r.taxByHeir.values.fold(0.0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.purple.shade600, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.successionFiscaliteCanton(_canton),
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
          ...r.taxByHeir.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      entry.value > 0
                          ? _chfFmt(entry.value)
                          : S.of(context)!.successionExonereLabel,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: entry.value > 0
                            ? MintColors.error
                            : MintColors.success,
                      ),
                    ),
                  ],
                ),
              )),
          if (totalTax > 0) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context)!.successionTotalTax,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                Text(
                  _chfFmt(totalTax),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- 3a OPP3 Card ---
  Widget _build3aOpp3Card() {
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
              Icon(Icons.info_outline, color: MintColors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.successionBeneficiaries3aTitle,
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
            S.of(context)!.successionBeneficiaries3aDesc,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              r.pillar3aBeneficiaryOrder,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textPrimary,
                height: 1.6,
              ),
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
          S.of(context)!.lifeEventPointsAttention,
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
      title: S.of(context)!.successionChecklistTitle,
      subtitle: S.of(context)!.lifeEventChecklistSubtitle,
      icon: Icons.checklist,
      accentColor: Colors.teal.shade600,
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
          S.of(context)!.lifeEventComprendre,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableTile(
          S.of(context)!.successionEduQuotite,
          S.of(context)!.successionEduQuotiteBody2,
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          S.of(context)!.successionEdu3a,
          S.of(context)!.successionEdu3aBody2,
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          S.of(context)!.successionEduConcubin,
          S.of(context)!.successionEduConcubinBody2,
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
              S.of(context)!.successionDisclaimerText,
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

  // --- Switch Helper ---
  Widget _buildSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
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
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: MintColors.primary,
        ),
      ],
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
