import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/segments_service.dart';
import 'package:mint_mobile/widgets/coach/ninety_day_plan_widget.dart';
import 'package:mint_mobile/widgets/coach/true_hourly_rate_widget.dart';
import 'package:mint_mobile/widgets/coach/lpp_vs_3a_decision_tree.dart';
import 'package:mint_mobile/widgets/coach/fiscal_superpower_widget.dart';
import 'package:mint_mobile/widgets/coach/double_price_freedom_widget.dart';
import 'package:mint_mobile/widgets/coach/lpp_rescue_widget.dart';

// ────────────────────────────────────────────────────────────
//  INDEPENDANT SCREEN — Sprint S12 / Chantier 6
// ────────────────────────────────────────────────────────────
//
// Coverage gap analysis for self-employed workers.
// Visual indicators for LPP/IJM/LAA/3a coverage.
// Protection cost calculator with monthly breakdown.
// Critical alerts for missing IJM.
// ────────────────────────────────────────────────────────────

class IndependantScreen extends StatefulWidget {
  const IndependantScreen({super.key});

  @override
  State<IndependantScreen> createState() => _IndependantScreenState();
}

class _IndependantScreenState extends State<IndependantScreen> {
  // ── State ──────────────────────────────────────────────────
  double _revenuNet = 80000;
  final int _age = 42;
  bool _hasLpp = false;
  bool _hasIjm = false;
  bool _hasLaa = false;
  bool _has3a = false;
  final String _canton = 'VD';

  IndependantResult? _result;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  void _compute() {
    final input = IndependantInput(
      revenuNet: _revenuNet,
      age: _age,
      hasLpp: _hasLpp,
      hasIjm: _hasIjm,
      hasLaa: _hasLaa,
      has3a: _has3a,
      canton: _canton,
    );
    setState(() {
      _result = IndependantService.analyse(input: input);
    });
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(),
                const SizedBox(height: 20),
                _buildIntro(),
                const SizedBox(height: 24),

                // Revenue input
                _buildRevenueSection(),
                const SizedBox(height: 24),

                // Coverage toggles
                _buildCoverageToggles(),
                const SizedBox(height: 24),

                if (_result != null) ...[
                  // Jour J — protection before/after (P6-A / S42)
                  _buildJourJSection(),
                  const SizedBox(height: 20),

                  // Critical alerts
                  if (_result!.alerts.isNotEmpty) ...[
                    _buildAlerts(),
                    const SizedBox(height: 20),
                  ],

                  // Coverage gap analysis
                  _buildCoverageGapSection(),
                  const SizedBox(height: 20),

                  // Protection cost calculator
                  _buildProtectionCost(),
                  const SizedBox(height: 20),

                  // AVS info
                  _buildAvsInfo(),
                  const SizedBox(height: 20),

                  // 3a info
                  _build3aInfo(),
                  const SizedBox(height: 20),

                  // Recommendations
                  _buildRecommendations(),
                  const SizedBox(height: 20),

                  // ── P7-D : Sauvetage LPP — libre passage (LFLP art. 3-4) ──
                  if (!_hasLpp)
                    LppRescueWidget(
                      lppBalance: _revenuNet * 0.15,
                      daysElapsed: 0,
                      options: const [
                        LppTransferOption(
                          label: 'Fondation de libre passage',
                          emoji: '🏦',
                          description: 'Place ton avoir en libre passage avec un rendement correct.',
                          fiveYearGain: 8500,
                          recommended: true,
                          legalRef: 'LFLP art. 4',
                        ),
                        LppTransferOption(
                          label: 'Institution suppletive',
                          emoji: '⚠️',
                          description: 'Transfert automatique apres 6 mois — rendement minimal.',
                          fiveYearGain: 1200,
                          legalRef: 'OPP2 art. 10',
                        ),
                        LppTransferOption(
                          label: 'Nouvelle caisse LPP',
                          emoji: '🔄',
                          description: 'Tu t\'affilies volontairement a une caisse LPP.',
                          fiveYearGain: 12000,
                          legalRef: 'LPP art. 44',
                        ),
                      ],
                    ),
                  if (!_hasLpp) const SizedBox(height: 20),
                ],

                // Disclaimer
                _buildDisclaimer(),
                const SizedBox(height: 16),

                _buildMintIndependantSection(),
                const SizedBox(height: 20),

                // Sources
                _buildSourcesFooter(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        S.of(context)!.independantAppBarTitle,
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.disclaimerBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.business_center,
            color: MintColors.warningText,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context)!.independantTitle,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                S.of(context)!.independantSubtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Intro ──────────────────────────────────────────────────

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.independantIntroDesc,
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

  // ── Jour J section (P6-A / S42) ───────────────────────────
  //  Dramatic before/after: every protection ON vs OFF.
  //  Computed from result or estimated from revenuNet.

  static const _protections = [
    ('AVS', '\ud83e\uddf1', 'Double ta cotisation'),
    ('LPP', '\ud83c\udfe6', 'Dispara\u00eet \u2014 choix volontaire'),
    ('LAA', '\ud83c\udfe5', 'Dispara\u00eet \u2014 accident hors travail'),
    ('IJM', '\ud83e\ude7a', 'Dispara\u00eet \u2014 maladie 0 CHF'),
    ('APG', '\ud83d\udc76', 'Dispara\u00eet \u2014 cong\u00e9 parental'),
  ];

  Widget _buildJourJSection() {
    // Estimate protection monthly loss when switching to self-employment.
    // AVS: employee share doubles (indep. pays both sides — LAVS art. 8).
    final avsMonth = _revenuNet * avsCotisationSalarie / 12;
    // LPP: voluntary caisse bonification (age-dependent — LPP art. 16).
    // Falls back to result's avsMensuel when a full calculation is available.
    final lppMonth = _result?.protectionCost.avsMensuel ??
        _revenuNet * getLppBonificationRate(_age) / 12;
    // LAA non-professionnelle: indicative market premium (~150 CHF/mois).
    // IJM maladie: indicative market premium (~100 CHF/mois).
    // These are educational estimates — real premiums depend on caisse & coverage.
    const double kLaaIndepMensuel = 150.0;
    const double kIjmIndepMensuel = 100.0;
    final totalLoss = (avsMonth + lppMonth + kLaaIndepMensuel + kIjmIndepMensuel)
        .roundToDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.error.withValues(alpha: 0.04),
            MintColors.warning.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text('\ud83d\udd04', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  S.of(context)!.independantJourJTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.independantJourJSubtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),

          // Column headers
          Row(
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              Expanded(
                child: Text(
                  S.of(context)!.independantJourJEmployee,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MintColors.success,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  S.of(context)!.independantJourJSelfEmployed,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MintColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Protection rows
          ..._protections.map((p) => _buildProtectionRow(p.$1, p.$2, p.$3)),

          const SizedBox(height: 10),

          // Chiffre-choc
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              S.of(context)!.independantJourJChiffreChoc(IndependantService.formatChf(totalLoss)),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: MintColors.error,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionRow(String label, String emoji, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Icon(Icons.check_circle, color: MintColors.success, size: 18),
          ),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.cancel, color: MintColors.error, size: 18),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Revenue section ────────────────────────────────────────

  Widget _buildRevenueSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.independantRevenueTitle,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                IndependantService.formatChf(_revenuNet),
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                S.of(context)!.independantAgeLabel(_age),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withValues(alpha: 0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: _revenuNet,
              min: 20000,
              max: 200000,
              divisions: 36,
              onChanged: (value) {
                _revenuNet = value;
                _compute();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CHF\u00A020k', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text('CHF\u00A0200k', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Coverage toggles ───────────────────────────────────────

  Widget _buildCoverageToggles() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.independantCoverageTitle,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildToggleRow(S.of(context)!.independantToggleLpp, _hasLpp, (v) {
            _hasLpp = v;
            _compute();
          }),
          _buildToggleRow(S.of(context)!.independantToggleIjm, _hasIjm, (v) {
            _hasIjm = v;
            _compute();
          }),
          _buildToggleRow(S.of(context)!.independantToggleLaa, _hasLaa, (v) {
            _hasLaa = v;
            _compute();
          }),
          _buildToggleRow(S.of(context)!.independantToggle3a, _has3a, (v) {
            _has3a = v;
            _compute();
          }),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: MintColors.success,
          ),
        ],
      ),
    );
  }

  // ── Alerts ─────────────────────────────────────────────────

  Widget _buildAlerts() {
    final result = _result!;
    return Column(
      children: result.alerts.map((alert) {
        final isCritique = alert.startsWith('CRITIQUE');
        final isImportant = alert.startsWith('IMPORTANT');
        final color = isCritique
            ? MintColors.error
            : isImportant
                ? MintColors.warning
                : MintColors.info;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isCritique ? Icons.error : Icons.warning_amber_rounded,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    alert,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: color,
                      height: 1.5,
                      fontWeight: isCritique ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Coverage gap section ───────────────────────────────────

  Widget _buildCoverageGapSection() {
    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_outlined, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.independantCoverageAnalysis,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...result.coverageGaps.map((gap) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildCoverageCard(gap),
        )),
      ],
    );
  }

  Widget _buildCoverageCard(CoverageGapItem gap) {
    final statusColor = gap.isCovered
        ? MintColors.success
        : gap.urgency == 'critique'
            ? MintColors.error
            : gap.urgency == 'haute'
                ? MintColors.warning
                : MintColors.info;

    final statusLabel = gap.isCovered
        ? 'Couvert'
        : gap.urgency == 'critique'
            ? 'NON COUVERT — Critique'
            : gap.urgency == 'haute'
                ? 'NON COUVERT'
                : 'Non couvert';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: gap.isCovered ? 0.8 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  gap.isCovered ? Icons.check_circle : Icons.cancel,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gap.label,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            gap.recommendation,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            gap.source,
            style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Protection cost calculator ─────────────────────────────

  Widget _buildProtectionCost() {
    final result = _result!;
    final cost = result.protectionCost;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.independantProtectionCostTitle,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.independantProtectionCostSubtitle,
            style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary),
          ),
          const SizedBox(height: 20),

          _buildCostRow(S.of(context)!.independantCostAvs, cost.avsMensuel, MintColors.tealLight),
          const SizedBox(height: 10),
          if (!_hasIjm)
            _buildCostRow(S.of(context)!.independantCostIjm, cost.ijmMensuel, MintColors.error),
          if (!_hasIjm) const SizedBox(height: 10),
          if (!_hasLaa)
            _buildCostRow(S.of(context)!.independantCostLaa, cost.laaMensuel, MintColors.warning),
          if (!_hasLaa) const SizedBox(height: 10),
          _buildCostRow(S.of(context)!.independantCost3a, cost.pillar3aMensuel, MintColors.indigo),
          const SizedBox(height: 16),

          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.independantTotalMonthly,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                IndependantService.formatChf(cost.totalMensuel),
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${IndependantService.formatChf(cost.totalAnnuel)} ${S.of(context)!.independantPerYear}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, double amount, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
            ),
          ),
        ),
        Text(
          IndependantService.formatChf(amount),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
        Text(
          S.of(context)!.independantPerMonth,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: MintColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ── AVS info ───────────────────────────────────────────────

  Widget _buildAvsInfo() {
    final result = _result!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.accentPastel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, color: MintColors.tealLight, size: 20),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.independantAvsTitle,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MintColors.tealDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context)!.independantAvsBody(IndependantService.formatChf(result.cotisationAvsAnnuelle)),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.tealDark,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            S.of(context)!.independantAvsSource,
            style: GoogleFonts.inter(fontSize: 11, color: MintColors.teal),
          ),
        ],
      ),
    );
  }

  // ── 3a info ────────────────────────────────────────────────

  Widget _build3aInfo() {
    final result = _result!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.indigo.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined, color: MintColors.indigo, size: 20),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.independant3aTitle,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MintColors.indigoDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _hasLpp
                ? S.of(context)!.independant3aWithLpp
                : S.of(context)!.independant3aWithoutLpp(IndependantService.formatChf(result.plafond3a)),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.indigoDeep,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            S.of(context)!.independant3aSource,
            style: GoogleFonts.inter(fontSize: 11, color: MintColors.pillarLpp),
          ),
        ],
      ),
    );
  }

  // ── Recommendations ────────────────────────────────────────

  Widget _buildRecommendations() {
    final result = _result!;
    if (result.recommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.independantRecommendationsHeader,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...result.recommendations.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MintColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: MintColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MintColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── MINT Indépendant section (S42) ────────────────────────

  Widget _buildMintIndependantSection() {
    final desiredNet = _revenuNet;
    final taxes = desiredNet * 0.22;
    final socialCharges = desiredNet * 0.10;
    final businessExp = desiredNet * 0.15;
    final unpaidDays = desiredNet * 0.05;
    final requiredRevenue = desiredNet + taxes + socialCharges + businessExp + unpaidDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            S.of(context)!.independantAnalysisHeader,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
            ),
          ),
        ),

        // LPP vs 3a decision tree
        LppVs3aDecisionTree(
          expectedIncome: _revenuNet,
          lppOption: DecisionOption(
            title: 'Caisse LPP facultative',
            emoji: '🏛️',
            subtitle: 'Protection rente invalidité + retraite',
            pros: const [
              'Couverture invalidité incluse',
              'Cotisations déductibles',
              'Rente prévue à la retraite',
            ],
            cons: const [
              'Cotisations obligatoires élevées',
              'Moins flexible',
            ],
            annualTaxSavings: _revenuNet * 0.08,
          ),
          grand3aOption: DecisionOption(
            title: 'Grand 3a (sans LPP)',
            emoji: '🏦',
            subtitle: '20% du revenu net, max CHF 36\'288/an',
            pros: const [
              'Flexibilité totale',
              'Déduction fiscale maximale',
              'Capital disponible à 60 ans',
            ],
            cons: const [
              'Pas de couverture invalidité',
              'Pas de rente prévue',
            ],
            annualTaxSavings: (_revenuNet * pilier3aTauxRevenuSansLpp).clamp(0, pilier3aPlafondSansLpp) * 0.25,
          ),
        ),
        const SizedBox(height: 20),

        // True hourly rate
        TrueHourlyRateWidget(
          desiredNetAnnual: desiredNet,
          layers: [
            RateLayer(label: 'Impôts (estimation)', amount: taxes, emoji: '🏛️'),
            RateLayer(label: 'Charges sociales AVS/AI', amount: socialCharges, emoji: '🛡️'),
            RateLayer(label: 'Frais professionnels', amount: businessExp, emoji: '💼'),
            RateLayer(label: 'Jours non facturables', amount: unpaidDays, emoji: '📅'),
          ],
          requiredRevenue: requiredRevenue,
        ),
        const SizedBox(height: 20),

        // ── Super-pouvoir fiscal indépendant (déductions) ──
        FiscalSuperpowerWidget(
          taxRate: 0.25,
          superpowers: [
            FiscalSuperpower(
              label: 'Pilier 3a grand versement',
              emoji: '🏦',
              annualDeduction: 20000,
              taxSaving: 20000 * 0.25,
              legalRef: 'OPP3 art. 1',
              note: 'Max 20% du revenu net, plafonné à CHF 36\'288/an sans LPP',
            ),
            FiscalSuperpower(
              label: 'Frais professionnels effectifs',
              emoji: '💼',
              annualDeduction: desiredNet * 0.15,
              taxSaving: desiredNet * 0.15 * 0.25,
              legalRef: 'LIFD art. 27 al. 2',
              note: 'Loyer bureau, matériel, formation — déductibles au réel',
            ),
            FiscalSuperpower(
              label: 'Primes assurance maladie (LPP vol.)',
              emoji: '🛡️',
              annualDeduction: 3600,
              taxSaving: 3600 * 0.25,
              legalRef: 'LIFD art. 33 al. 1 lit. g',
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Double prix de la liberté — comparaison charges salarié vs indépendant
        DoublePriceFreedomWidget(
          grossIncome: _revenuNet,
          charges: [
            ChargeLine(
              label: 'AVS / AI / APG',
              employeeAmount: _revenuNet * 0.0530,
              selfEmployedAmount: _revenuNet * 0.1010,
              note: 'LAVS art. 8 — indép. paie les 2 parts',
            ),
            ChargeLine(
              label: 'LPP (2e pilier)',
              employeeAmount: _revenuNet * 0.070,
              selfEmployedAmount: 0,
              note: 'Facultatif pour indépendant (LPP art. 4)',
            ),
            ChargeLine(
              label: 'Chômage (AC)',
              employeeAmount: _revenuNet * 0.011,
              selfEmployedAmount: 0,
              note: 'Pas d\'AC pour indépendant (LACI art. 2)',
            ),
            ChargeLine(
              label: 'Cotisations pro (IJM/LAA)',
              employeeAmount: _revenuNet * 0.020,
              selfEmployedAmount: _revenuNet * 0.040,
              note: 'À charge entière de l\'indépendant',
            ),
          ],
          totalEmployee: _revenuNet * (0.0530 + 0.070 + 0.011 + 0.020),
          totalSelfEmployed: _revenuNet * (0.1010 + 0 + 0 + 0.040),
        ),
        const SizedBox(height: 20),

        // 90-day plan
        NinetyDayPlanWidget(
          phases: [
            PlanPhase(
              title: 'Administratif urgent',
              emoji: '📋',
              deadline: 'J+30',
              urgencyColor: MintColors.scoreCritique,
              actions: const [
                PlanAction(
                  label: 'Inscription caisse AVS indépendants',
                  consequence: 'Amendes rétroactives si délai dépassé',
                  legalRef: 'LAVS art. 12',
                ),
                PlanAction(
                  label: 'Assurance accidents LAA (si pas LPP)',
                  consequence: 'Pas de couverture accident professionnel',
                  legalRef: 'LAA art. 4',
                ),
              ],
            ),
            PlanPhase(
              title: 'Prévoyance',
              emoji: '🏦',
              deadline: 'J+60',
              urgencyColor: MintColors.scoreAttention,
              actions: const [
                PlanAction(
                  label: 'Ouvrir compte 3a (déduction jusqu\'à CHF 36\'288)',
                  legalRef: 'OPP3',
                ),
                PlanAction(
                  label: 'Évaluer IJM (indemnité journalière maladie)',
                  consequence: 'Perte de revenus dès J+3 en cas de maladie',
                ),
              ],
            ),
            PlanPhase(
              title: 'Optimisation fiscale',
              emoji: '💡',
              deadline: 'J+90',
              urgencyColor: MintColors.primary,
              actions: const [
                PlanAction(label: 'Frais professionnels déductibles — tenir registre'),
                PlanAction(label: 'Acomptes impôts cantonaux — éviter les intérêts'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.independantDisclaimer,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.deepOrange,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sources footer ─────────────────────────────────────────

  Widget _buildSourcesFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.independantSourcesTitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          S.of(context)!.independantSourcesBody,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
