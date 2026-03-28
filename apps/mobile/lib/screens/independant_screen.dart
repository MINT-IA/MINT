import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
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
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  INDEPENDANT SCREEN — Sprint S12 / Chantier 6
// ────────────────────────────────────────────────────────────
//
// Design System: Category C — Life Event.
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
  int _age = 42;
  bool _hasLpp = false;
  bool _hasIjm = false;
  bool _hasLaa = false;
  bool _has3a = false;
  String _canton = 'ZH';

  IndependantResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
    });
    _compute();
  }

  void _initializeFromProfile() {
    try {
      final provider = context.read<CoachProfileProvider>();
      if (!provider.hasProfile) return;
      final profile = provider.profile!;
      setState(() {
        // Age
        final age = profile.age;
        if (age >= 18 && age <= 70) _age = age;

        // Canton
        if (cantonFullNames.containsKey(profile.canton)) {
          _canton = profile.canton;
        }

        // Revenue
        final revenu = profile.revenuBrutAnnuel;
        if (revenu > 0) _revenuNet = revenu;
      });
      _compute();
    } catch (_) {
      // Provider not in tree (tests) — keep defaults
    }
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
      backgroundColor: MintColors.white,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                MintSpacing.lg, 0, MintSpacing.lg, MintSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                MintEntrance(child: _buildHeader()),
                const SizedBox(height: MintSpacing.lg),
                MintEntrance(delay: const Duration(milliseconds: 100), child: _buildIntro()),
                const SizedBox(height: MintSpacing.lg),

                // Revenue input
                MintEntrance(delay: const Duration(milliseconds: 200), child: _buildRevenueSection()),
                const SizedBox(height: MintSpacing.lg),

                // Coverage toggles
                MintEntrance(delay: const Duration(milliseconds: 300), child: _buildCoverageToggles()),
                const SizedBox(height: MintSpacing.lg),

                if (_result != null) ...[
                  // Jour J — protection before/after (P6-A / S42)
                  _buildJourJSection(),
                  const SizedBox(height: MintSpacing.lg),

                  // Critical alerts
                  if (_result!.alerts.isNotEmpty) ...[
                    _buildAlerts(),
                    const SizedBox(height: MintSpacing.lg),
                  ],

                  // Coverage gap analysis
                  _buildCoverageGapSection(),
                  const SizedBox(height: MintSpacing.lg),

                  // Protection cost calculator
                  _buildProtectionCost(),
                  const SizedBox(height: MintSpacing.lg),

                  // AVS info
                  _buildAvsInfo(),
                  const SizedBox(height: MintSpacing.lg),

                  // 3a info
                  _build3aInfo(),
                  const SizedBox(height: MintSpacing.lg),

                  // Recommendations
                  _buildRecommendations(),
                  const SizedBox(height: MintSpacing.lg),

                  // ── P7-D : Sauvetage LPP — libre passage (LFLP art. 3-4) ──
                  if (!_hasLpp)
                    LppRescueWidget(
                      lppBalance: _revenuNet * 0.15,
                      daysElapsed: 0,
                      options: const [
                        LppTransferOption(
                          label: 'Fondation de libre passage',
                          emoji: '\u{1F3E6}',
                          description:
                              'Place ton avoir en libre passage avec un rendement correct.',
                          fiveYearGain: 8500,
                          recommended: true,
                          legalRef: 'LFLP art. 4',
                        ),
                        LppTransferOption(
                          label: 'Institution suppl\u00e9tive',
                          emoji: '\u26A0\uFE0F',
                          description:
                              'Transfert automatique apr\u00e8s 6 mois \u2014 rendement minimal.',
                          fiveYearGain: 1200,
                          legalRef: 'OPP2 art. 10',
                        ),
                        LppTransferOption(
                          label: 'Nouvelle caisse LPP',
                          emoji: '\u{1F504}',
                          description:
                              'Tu t\'affilies volontairement \u00e0 une caisse LPP.',
                          fiveYearGain: 12000,
                          legalRef: 'LPP art. 44',
                        ),
                      ],
                    ),
                  if (!_hasLpp) const SizedBox(height: MintSpacing.lg),
                ],

                // Disclaimer
                MintEntrance(delay: const Duration(milliseconds: 400), child: _buildDisclaimer()),
                const SizedBox(height: MintSpacing.md),

                _buildMintIndependantSection(),
                const SizedBox(height: MintSpacing.lg),

                // Sources
                _buildSourcesFooter(),
                const SizedBox(height: MintSpacing.xxl),
              ]),
            ),
          ),
        ],
      ))),
    );
  }

  // ── App Bar ────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Semantics(
        header: true,
        child: Text(
          S.of(context)!.independantAppBarTitle,
          style: MintTextStyles.headlineMedium(),
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
          child: const Icon(
            Icons.business_center,
            color: MintColors.warningText,
            size: 28,
          ),
        ),
        const SizedBox(width: MintSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  S.of(context)!.independantTitle,
                  style: MintTextStyles.headlineLarge(),
                ),
              ),
              const SizedBox(height: MintSpacing.xs),
              Text(
                S.of(context)!.independantSubtitle,
                style: MintTextStyles.bodyMedium(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Intro ──────────────────────────────────────────────────

  Widget _buildIntro() {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              S.of(context)!.independantIntroDesc,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Jour J section (P6-A / S42) ───────────────────────────

  List<(String, String, String)> _protections(S s) => [
    ('AVS', '\ud83e\uddf1', s.indepProtAvs),
    ('LPP', '\ud83c\udfe6', s.indepProtLpp),
    ('LAA', '\ud83c\udfe5', s.indepProtLaa),
    ('IJM', '\ud83e\ude7a', s.indepProtIjm),
    ('APG', '\ud83d\udc76', s.indepProtApg),
  ];

  Widget _buildJourJSection() {
    final avsMonth = _revenuNet * avsCotisationSalarie / 12;
    final lppMonth = _result?.protectionCost.avsMensuel ??
        _revenuNet * getLppBonificationRate(_age) / 12;
    const double kLaaIndepMensuel = 150.0;
    const double kIjmIndepMensuel = 100.0;
    final totalLoss =
        (avsMonth + lppMonth + kLaaIndepMensuel + kIjmIndepMensuel)
            .roundToDouble();

    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
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
          Row(
            children: [
              const Text('\ud83d\udd04', style: TextStyle(fontSize: 20)),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  S.of(context)!.independantJourJTitle,
                  style: MintTextStyles.titleMedium(),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.independantJourJSubtitle,
            style: MintTextStyles.labelSmall(),
          ),
          const SizedBox(height: MintSpacing.md),

          // Column headers
          Row(
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              Expanded(
                child: Text(
                  S.of(context)!.independantJourJEmployee,
                  textAlign: TextAlign.center,
                  style: MintTextStyles.labelSmall(color: MintColors.success),
                ),
              ),
              Expanded(
                child: Text(
                  S.of(context)!.independantJourJSelfEmployed,
                  textAlign: TextAlign.center,
                  style: MintTextStyles.labelSmall(color: MintColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),

          ..._protections(S.of(context)!).map((p) => _buildProtectionRow(p.$1, p.$2, p.$3)),

          const SizedBox(height: MintSpacing.sm),

          // Chiffre-choc
          Semantics(
            label: S.of(context)!.independantJourJChiffreChoc(
                IndependantService.formatChf(totalLoss)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(MintSpacing.sm),
              decoration: BoxDecoration(
                color: MintColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                S.of(context)!.independantJourJChiffreChoc(
                    IndependantService.formatChf(totalLoss)),
                style: MintTextStyles.labelSmall(color: MintColors.error),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionRow(String label, String emoji, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.xs),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: MintSpacing.xs),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          ),
          const Expanded(
            child:
                Icon(Icons.check_circle, color: MintColors.success, size: 18),
          ),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.cancel, color: MintColors.error, size: 18),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: MintTextStyles.micro(color: MintColors.textMuted),
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
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.independantRevenueTitle,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            S.of(context)!.independantAgeLabel(_age),
            style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.sm),
          MintPremiumSlider(
            label: S.of(context)!.independantRevenueTitle,
            value: _revenuNet,
            min: 20000,
            max: 200000,
            divisions: 36,
            formatValue: (v) => IndependantService.formatChf(v),
            onChanged: (value) {
              _revenuNet = value;
              _compute();
            },
          ),
        ],
      ),
    );
  }

  // ── Coverage toggles ───────────────────────────────────────

  Widget _buildCoverageToggles() {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.independantCoverageTitle,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.md),
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

  Widget _buildToggleRow(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          Semantics(
            toggled: value,
            label: label,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: MintColors.success,
            ),
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
          padding: const EdgeInsets.only(bottom: MintSpacing.sm),
          child: Container(
            padding: const EdgeInsets.all(MintSpacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
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
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    alert,
                    style: MintTextStyles.bodySmall(color: color),
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
    final l = S.of(context)!;
    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_outlined,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: MintSpacing.sm),
            Text(
              l.independantCoverageAnalysis,
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm),
        ...result.coverageGaps.map((gap) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm),
              child: _buildCoverageCard(gap),
            )),
      ],
    );
  }

  Widget _buildCoverageCard(CoverageGapItem gap) {
    final l = S.of(context)!;
    final statusColor = gap.isCovered
        ? MintColors.success
        : gap.urgency == 'critique'
            ? MintColors.error
            : gap.urgency == 'haute'
                ? MintColors.warning
                : MintColors.info;

    final statusLabel = gap.isCovered
        ? l.independantCoveredLabel
        : gap.urgency == 'critique'
            ? l.independantCriticalLabel
            : gap.urgency == 'haute'
                ? l.independantHighLabel
                : l.independantLowLabel;

    return Semantics(
      label: '${gap.label}: $statusLabel',
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 16,
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
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gap.label,
                        style: MintTextStyles.titleMedium(),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: MintSpacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusLabel,
                          style:
                              MintTextStyles.labelSmall(color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              gap.recommendation,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              gap.source,
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Protection cost calculator ─────────────────────────────

  Widget _buildProtectionCost() {
    final result = _result!;
    final cost = result.protectionCost;

    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.independantProtectionCostTitle,
            style: MintTextStyles.headlineMedium(),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.independantProtectionCostSubtitle,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.lg),

          _buildCostRow(S.of(context)!.independantCostAvs, cost.avsMensuel,
              MintColors.tealLight),
          const SizedBox(height: MintSpacing.sm),
          if (!_hasIjm)
            _buildCostRow(S.of(context)!.independantCostIjm, cost.ijmMensuel,
                MintColors.error),
          if (!_hasIjm) const SizedBox(height: MintSpacing.sm),
          if (!_hasLaa)
            _buildCostRow(S.of(context)!.independantCostLaa, cost.laaMensuel,
                MintColors.warning),
          if (!_hasLaa) const SizedBox(height: MintSpacing.sm),
          _buildCostRow(S.of(context)!.independantCost3a, cost.pillar3aMensuel,
              MintColors.indigo),
          const SizedBox(height: MintSpacing.md),

          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: MintSpacing.sm),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.independantTotalMonthly,
                style: MintTextStyles.titleMedium(),
              ),
              Text(
                IndependantService.formatChf(cost.totalMensuel),
                style: MintTextStyles.displayMedium(color: MintColors.primary),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${IndependantService.formatChf(cost.totalAnnuel)} ${S.of(context)!.independantPerYear}',
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
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
        const SizedBox(width: MintSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: MintTextStyles.bodyMedium(),
          ),
        ),
        Text(
          IndependantService.formatChf(amount),
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
        ),
        Text(
          S.of(context)!.independantPerMonth,
          style: MintTextStyles.labelSmall(),
        ),
      ],
    );
  }

  // ── AVS info ───────────────────────────────────────────────

  Widget _buildAvsInfo() {
    final result = _result!;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.accentPastel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline,
                  color: MintColors.tealLight, size: 20),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.independantAvsTitle,
                style: MintTextStyles.titleMedium(color: MintColors.tealDark),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            S.of(context)!.independantAvsBody(
                IndependantService.formatChf(result.cotisationAvsAnnuelle)),
            style: MintTextStyles.bodySmall(color: MintColors.tealDark),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.independantAvsSource,
            style: MintTextStyles.labelSmall(color: MintColors.teal),
          ),
        ],
      ),
    );
  }

  // ── 3a info ────────────────────────────────────────────────

  Widget _build3aInfo() {
    final result = _result!;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.indigo.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined,
                  color: MintColors.indigo, size: 20),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.independant3aTitle,
                style: MintTextStyles.titleMedium(color: MintColors.indigoDark),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            _hasLpp
                ? S.of(context)!.independant3aWithLpp
                : S.of(context)!.independant3aWithoutLpp(
                    IndependantService.formatChf(result.plafond3a)),
            style: MintTextStyles.bodySmall(color: MintColors.indigoDeep),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.independant3aSource,
            style: MintTextStyles.labelSmall(color: MintColors.pillarLpp),
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
            const Icon(Icons.lightbulb_outline,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: MintSpacing.sm),
            Text(
              S.of(context)!.independantRecommendationsHeader,
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm),
        ...result.recommendations.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: MintSpacing.sm),
            child: MintSurface(
              padding: const EdgeInsets.all(14),
              radius: 14,
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
                        style: MintTextStyles.labelSmall(
                            color: MintColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary),
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

  // ── MINT Ind\u00e9pendant section (S42) ────────────────────────

  Widget _buildMintIndependantSection() {
    final desiredNet = _revenuNet;
    final taxes = desiredNet * 0.22;
    final socialCharges = desiredNet * 0.10;
    final businessExp = desiredNet * 0.15;
    final unpaidDays = desiredNet * 0.05;
    final requiredRevenue =
        desiredNet + taxes + socialCharges + businessExp + unpaidDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.only(bottom: MintSpacing.md),
          child: Text(
            S.of(context)!.independantAnalysisHeader,
            style: MintTextStyles.headlineMedium(),
          ),
        ),

        // LPP vs 3a decision tree
        LppVs3aDecisionTree(
          expectedIncome: _revenuNet,
          lppOption: DecisionOption(
            title: S.of(context)!.indepCaisseLpp,
            emoji: '\u{1F3DB}\uFE0F',
            subtitle: S.of(context)!.indepCaisseLppSub,
            pros: [
              S.of(context)!.indepLppProInvalidite,
              S.of(context)!.indepLppProDeductible,
              S.of(context)!.indepLppProRente,
            ],
            cons: [
              S.of(context)!.indepLppConCotisations,
              S.of(context)!.indepLppConFlexible,
            ],
            annualTaxSavings: _revenuNet * 0.08,
          ),
          grand3aOption: DecisionOption(
            title: S.of(context)!.indepGrand3a,
            emoji: '\u{1F3E6}',
            subtitle: S.of(context)!.indepGrand3aSub,
            pros: [
              S.of(context)!.indepGrand3aProFlexibilite,
              S.of(context)!.indepGrand3aProDeduction,
              S.of(context)!.indepGrand3aProCapital,
            ],
            cons: [
              S.of(context)!.indepGrand3aConInvalidite,
              S.of(context)!.indepGrand3aConRente,
            ],
            annualTaxSavings:
                (_revenuNet * pilier3aTauxRevenuSansLpp).clamp(0, pilier3aPlafondSansLpp) *
                    0.25,
          ),
        ),
        const SizedBox(height: MintSpacing.lg),

        // True hourly rate
        TrueHourlyRateWidget(
          desiredNetAnnual: desiredNet,
          layers: [
            RateLayer(
                label: S.of(context)!.indepLayerImpots,
                amount: taxes,
                emoji: '\u{1F3DB}\uFE0F'),
            RateLayer(
                label: S.of(context)!.indepLayerChargesSociales,
                amount: socialCharges,
                emoji: '\u{1F6E1}\uFE0F'),
            RateLayer(
                label: S.of(context)!.indepLayerFraisPro,
                amount: businessExp,
                emoji: '\u{1F4BC}'),
            RateLayer(
                label: S.of(context)!.indepLayerJoursNonFact,
                amount: unpaidDays,
                emoji: '\u{1F4C5}'),
          ],
          requiredRevenue: requiredRevenue,
        ),
        const SizedBox(height: MintSpacing.lg),

        // ── Super-pouvoir fiscal ind\u00e9pendant (d\u00e9ductions) ──
        FiscalSuperpowerWidget(
          taxRate: 0.25,
          superpowers: [
            FiscalSuperpower(
              label: S.of(context)!.indepFiscal3a,
              emoji: '\u{1F3E6}',
              annualDeduction: 20000,
              taxSaving: 20000 * 0.25,
              legalRef: 'OPP3 art. 1',
              note: S.of(context)!.indepFiscal3aNote,
            ),
            FiscalSuperpower(
              label: S.of(context)!.indepFiscalFraisPro,
              emoji: '\u{1F4BC}',
              annualDeduction: desiredNet * 0.15,
              taxSaving: desiredNet * 0.15 * 0.25,
              legalRef: 'LIFD art. 27 al. 2',
              note: S.of(context)!.indepFiscalFraisProNote,
            ),
            FiscalSuperpower(
              label: S.of(context)!.indepFiscalPrimesLpp,
              emoji: '\u{1F6E1}\uFE0F',
              annualDeduction: 3600,
              taxSaving: 3600 * 0.25,
              legalRef: 'LIFD art. 33 al. 1 lit. g',
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.lg),

        // Double prix de la libert\u00e9
        DoublePriceFreedomWidget(
          grossIncome: _revenuNet,
          charges: [
            ChargeLine(
              label: S.of(context)!.indepChargeAvs,
              employeeAmount: _revenuNet * avsCotisationSalarie,
              selfEmployedAmount: _revenuNet * avsCotisationTotal,
              note: 'LAVS art. 8',
            ),
            ChargeLine(
              label: S.of(context)!.indepChargeLpp,
              employeeAmount: _revenuNet * getLppBonificationRate(_age),
              selfEmployedAmount: 0,
              note: S.of(context)!.indepChargeLppNote,
            ),
            ChargeLine(
              label: S.of(context)!.indepChargeAc,
              employeeAmount: _revenuNet * acCotisationSalarie,
              selfEmployedAmount: 0,
              note: S.of(context)!.indepChargeAcNote,
            ),
            ChargeLine(
              label: S.of(context)!.indepChargePro,
              employeeAmount: _revenuNet * 0.020,
              selfEmployedAmount: _revenuNet * 0.040,
              note: S.of(context)!.indepChargeProNote,
            ),
          ],
          totalEmployee: _revenuNet * (avsCotisationSalarie + getLppBonificationRate(_age) + acCotisationSalarie + 0.020),
          totalSelfEmployed: _revenuNet * (avsCotisationTotal + 0 + 0 + 0.040),
        ),
        const SizedBox(height: MintSpacing.lg),

        // 90-day plan
        NinetyDayPlanWidget(
          phases: [
            PlanPhase(
              title: S.of(context)!.indepAdminUrgent,
              emoji: '\u{1F4CB}',
              deadline: 'J+30',
              urgencyColor: MintColors.scoreCritique,
              actions: [
                PlanAction(
                  label: S.of(context)!.indepPlanInscriptionAvs,
                  consequence: S.of(context)!.indepPlanInscriptionAvsConseq,
                  legalRef: 'LAVS art. 12',
                ),
                PlanAction(
                  label: S.of(context)!.indepPlanLaa,
                  consequence: S.of(context)!.indepPlanLaaConseq,
                  legalRef: 'LAA art. 4',
                ),
              ],
            ),
            PlanPhase(
              title: S.of(context)!.indepPrevoyance,
              emoji: '\u{1F3E6}',
              deadline: 'J+60',
              urgencyColor: MintColors.scoreAttention,
              actions: [
                PlanAction(
                  label: S.of(context)!.indepPlanOuvrir3a,
                  legalRef: 'OPP3',
                ),
                PlanAction(
                  label: S.of(context)!.indepPlanIjm,
                  consequence: S.of(context)!.indepPlanIjmConseq,
                ),
              ],
            ),
            PlanPhase(
              title: S.of(context)!.indepOptiFiscale,
              emoji: '\u{1F4A1}',
              deadline: 'J+90',
              urgencyColor: MintColors.primary,
              actions: [
                PlanAction(
                    label: S.of(context)!.indepPlanFraisPro),
                PlanAction(
                    label: S.of(context)!.indepPlanAcomptes),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Semantics(
      label: S.of(context)!.independantDisclaimer,
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: MintColors.textMuted, size: 18),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Text(
                S.of(context)!.independantDisclaimer,
                style: MintTextStyles.micro(),
              ),
            ),
          ],
        ),
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
          style: MintTextStyles.labelSmall(),
        ),
        const SizedBox(height: MintSpacing.xs),
        Text(
          S.of(context)!.independantSourcesBody,
          style: MintTextStyles.micro(),
        ),
      ],
    );
  }
}
