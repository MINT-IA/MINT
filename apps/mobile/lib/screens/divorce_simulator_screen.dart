import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/life_events_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/coach/divorce_film_widget.dart';
import 'package:mint_mobile/widgets/coach/prix_du_silence_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_signal_row.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/models/screen_return.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeFromProfile() {
    try {
      final provider = context.read<CoachProfileProvider>();
      if (!provider.hasProfile) return;
      final profile = provider.profile!;
      setState(() {
        // Conjoint 1 income from profile
        final revenu1 = profile.revenuBrutAnnuel;
        if (revenu1 > 0) _incomeConjoint1 = revenu1;

        // Conjoint 2 income from conjoint profile
        final conjoint = profile.conjoint;
        if (conjoint != null) {
          final revenu2 = conjoint.revenuBrutAnnuel;
          if (revenu2 > 0) _incomeConjoint2 = revenu2;

          // Conjoint 2 LPP
          final lpp2 = conjoint.prevoyance?.avoirLppTotal;
          if (lpp2 != null && lpp2 > 0) _lppConjoint2 = lpp2;

          // Conjoint 2 3a
          final epargne3a2 = conjoint.prevoyance?.totalEpargne3a;
          if (epargne3a2 != null && epargne3a2 > 0) {
            _pillar3aConjoint2 = epargne3a2;
          }
        }

        // Conjoint 1 LPP
        final lpp1 = profile.prevoyance.avoirLppTotal;
        if (lpp1 != null && lpp1 > 0) _lppConjoint1 = lpp1;

        // Conjoint 1 3a
        final epargne3a1 = profile.prevoyance.totalEpargne3a;
        if (epargne3a1 > 0) _pillar3aConjoint1 = epargne3a1;

        // Children
        if (profile.nombreEnfants > 0) {
          _numberOfChildren = profile.nombreEnfants;
        }

        // Fortune commune = epargne liquide + investissements
        final fortune = profile.patrimoine.epargneLiquide +
            profile.patrimoine.investissements;
        if (fortune > 0) _fortuneCommune = fortune;
      });
    } catch (_) {
      // Provider not in tree (tests) — keep defaults
    }
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
    ScreenCompletionTracker.markCompletedWithReturn(
      'divorce_simulator',
      ScreenReturn.completed(
        route: '/divorce',
        updatedFields: {
          'divorceLppSplit': _result!.lppSplit.transferAmount,
          'divorcePensionAlimentaire': _result!.pensionAlimentaireMonthly,
        },
        confidenceDelta: 0.02,
        nextCapSuggestion: 'budget_post_divorce',
      ),
    );

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
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.porcelaine,
        surfaceTintColor: MintColors.porcelaine,
        foregroundColor: MintColors.textPrimary,
        title: Text(
          S.of(context)!.divorceAppBarTitle,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.lg,
          vertical: MintSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero: partage LPP impact (shown when results exist)
            if (_result != null) ...[
              Container(key: _resultsKey),
              _buildDivorceHeroCard(),
              const SizedBox(height: MintSpacing.xl),
            ] else ...[
              _buildIntroCard(),
              const SizedBox(height: MintSpacing.xl),
            ],
            MintEntrance(child: _buildSituationFamilialeSection()),
            const SizedBox(height: MintSpacing.md),
            MintEntrance(delay: const Duration(milliseconds: 100), child: _buildRevenusSection()),
            const SizedBox(height: MintSpacing.md),
            MintEntrance(delay: const Duration(milliseconds: 200), child: _buildPrevoyanceSection()),
            const SizedBox(height: MintSpacing.md),
            MintEntrance(delay: const Duration(milliseconds: 300), child: _buildPatrimoineSection()),
            const SizedBox(height: MintSpacing.xl),
            MintEntrance(delay: const Duration(milliseconds: 400), child: _buildSimulateButton()),
            const SizedBox(height: MintSpacing.xl),
            if (_result != null) ...[
              _buildLppSplitCard(),
              const SizedBox(height: MintSpacing.xl),
              _buildTaxImpactCard(),
              const SizedBox(height: MintSpacing.xl),
              _buildPatrimoineSplitCard(),
              const SizedBox(height: MintSpacing.xl),
              _buildPensionAlimentaireCard(),
              const SizedBox(height: MintSpacing.xl),
              if (_result!.alerts.isNotEmpty) ...[
                _buildAlertsSection(),
                const SizedBox(height: MintSpacing.xl),
              ],
              _buildChecklistSection(),
              const SizedBox(height: MintSpacing.xl),
            ],
            _buildEducationalFooter(),
            const SizedBox(height: MintSpacing.xl),
            _buildMintDivorceSection(),
            const SizedBox(height: MintSpacing.xl),
            PrixDuSilenceWidget(
              patrimoine: _fortuneCommune > 0 ? _fortuneCommune : 200000,
              marriedTaxRate: 0,
              concubinTaxRate: 24,
            ),
            const SizedBox(height: MintSpacing.xl),
            _buildDisclaimer(),
            const SizedBox(height: MintSpacing.xl + MintSpacing.sm),
          ],
        ),
      ),
    );
  }

  // --- Hero Card (shown after simulation) ---
  Widget _buildDivorceHeroCard() {
    final r = _result!;
    return MintResultHeroCard(
      eyebrow: S.of(context)!.divorcePartageLpp,
      primaryValue: _chfFmt(r.lppSplit.transferAmount),
      primaryLabel: S.of(context)!.divorceTransfertAmount(
        _chfFmt(r.lppSplit.transferAmount),
        r.lppSplit.transferDirection,
      ),
      secondaryValue: _chfFmt(r.taxImpact.delta.abs()),
      secondaryLabel: S.of(context)!.divorceImpactFiscal,
      narrative: S.of(context)!.divorceHeaderSubtitle,
      accentColor: MintColors.error,
      tone: MintSurfaceTone.peche,
    );
  }

  // --- Intro Card (shown before simulation) ---
  Widget _buildIntroCard() {
    return MintSurface(
      tone: MintSurfaceTone.bleu,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline,
              size: 20, color: MintColors.info),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.divorceIntroText,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // --- Section 1: Situation Familiale ---
  Widget _buildSituationFamilialeSection() {
    return SimulatorCard(
      title: S.of(context)!.divorceSituationFamiliale,
      subtitle: S.of(context)!.divorceSituationSubtitle,
      icon: Icons.people_outline,
      accentColor: MintColors.purple,
      child: Column(
        children: [
          _buildSlider(
            label: S.of(context)!.divorceDureeMariage,
            value: _marriageDuration.toDouble(),
            min: 1,
            max: 40,
            divisions: 39,
            format: (v) => S.of(context)!.divorceYears(v.toInt()),
            onChanged: (v) => setState(() => _marriageDuration = v.toInt()),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildSlider(
            label: S.of(context)!.divorceNbEnfants,
            value: _numberOfChildren.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            format: (v) => '${v.toInt()}',
            onChanged: (v) =>
                setState(() => _numberOfChildren = v.toInt()),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildRegimeChips(),
        ],
      ),
    );
  }

  // --- Regime Chips ---
  Widget _buildRegimeChips() {
    final options = <MapEntry<MatrimonialRegime, String>>[
      MapEntry(
          MatrimonialRegime.participationAuxAcquets, S.of(context)!.divorceParticipationDefault),
      MapEntry(
          MatrimonialRegime.communauteDeBiens, S.of(context)!.divorceCommunaute),
      MapEntry(
          MatrimonialRegime.separationDeBiens, S.of(context)!.divorceSeparation),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.divorceRegimeMatrimonial,
          style: MintTextStyles.bodySmall(
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: MintSpacing.sm),
        Wrap(
          spacing: MintSpacing.sm,
          runSpacing: MintSpacing.sm,
          children: options.map((opt) {
            final selected = _regime == opt.key;
            return Semantics(
              label: '${S.of(context)!.divorceRegimeMatrimonial}\u00a0: ${opt.value}',
              button: true,
              selected: selected,
              child: GestureDetector(
              onTap: () => setState(() => _regime = opt.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? MintColors.purple.withValues(alpha: 0.1)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? MintColors.purple
                        : MintColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  opt.value,
                  style: MintTextStyles.labelSmall(
                    color: selected
                        ? MintColors.purple
                        : MintColors.textSecondary,
                  ).copyWith(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

  // --- Section 2: Revenus ---
  Widget _buildRevenusSection() {
    return SimulatorCard(
      title: S.of(context)!.divorceRevenus,
      subtitle: S.of(context)!.divorceRevenusSubtitle,
      icon: Icons.payments_outlined,
      accentColor: MintColors.purple,
      child: Column(
        children: [
          _buildSlider(
            label: S.of(context)!.divorceConjoint1Revenu,
            value: _incomeConjoint1,
            min: 0,
            max: 300000,
            divisions: 60,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _incomeConjoint1 = v),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildSlider(
            label: S.of(context)!.divorceConjoint2Revenu,
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
      title: S.of(context)!.divorcePrevoyance,
      subtitle: S.of(context)!.divorcePrevoyanceSubtitle,
      icon: Icons.account_balance_outlined,
      accentColor: MintColors.purple,
      child: Column(
        children: [
          _buildSlider(
            label: S.of(context)!.divorceLppConjoint1,
            value: _lppConjoint1,
            min: 0,
            max: 500000,
            divisions: 100,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _lppConjoint1 = v),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildSlider(
            label: S.of(context)!.divorceLppConjoint2,
            value: _lppConjoint2,
            min: 0,
            max: 500000,
            divisions: 100,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _lppConjoint2 = v),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildSlider(
            label: S.of(context)!.divorce3aConjoint1,
            value: _pillar3aConjoint1,
            min: 0,
            max: 200000,
            divisions: 40,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _pillar3aConjoint1 = v),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildSlider(
            label: S.of(context)!.divorce3aConjoint2,
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
      title: S.of(context)!.divorcePatrimoine,
      subtitle: S.of(context)!.divorcePatrimoineSubtitle,
      icon: Icons.home_outlined,
      accentColor: MintColors.purple,
      child: Column(
        children: [
          _buildSlider(
            label: S.of(context)!.divorceFortune,
            value: _fortuneCommune,
            min: 0,
            max: 2000000,
            divisions: 200,
            format: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _fortuneCommune = v),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildSlider(
            label: S.of(context)!.divorceDettes,
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
      child: Semantics(
        button: true,
        label: S.of(context)!.divorceSimuler,
        child: FilledButton.icon(
          onPressed: _simulate,
          icon: const Icon(Icons.calculate_outlined, size: 20),
          label: Text(
            S.of(context)!.divorceSimuler,
            style: MintTextStyles.titleMedium(color: MintColors.white),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: MintColors.primary,
            foregroundColor: MintColors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  // --- LPP Split Card ---
  Widget _buildLppSplitCard() {
    final r = _result!;
    return MintSurface(
      tone: MintSurfaceTone.bleu,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.divorcePartageLpp,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: MintSpacing.md),
          MintSignalRow(
            label: S.of(context)!.divorceTotalLpp,
            value: _chfFmt(r.lppSplit.totalLpp),
          ),
          MintSignalRow(
            label: S.of(context)!.divorcePartConjoint1,
            value: _chfFmt(r.lppSplit.shareConjoint1),
          ),
          MintSignalRow(
            label: S.of(context)!.divorcePartConjoint2,
            value: _chfFmt(r.lppSplit.shareConjoint2),
          ),
          if (r.lppSplit.transferAmount > 0) ...[
            const SizedBox(height: MintSpacing.sm),
            MintSurface(
              tone: MintSurfaceTone.blanc,
              padding: const EdgeInsets.all(MintSpacing.sm + 4),
              radius: 12,
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward,
                      size: 16, color: MintColors.info),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Semantics(
                      label: S.of(context)!.divorceTransfertAmount(
                        _chfFmt(r.lppSplit.transferAmount),
                        r.lppSplit.transferDirection,
                      ),
                      child: Text(
                        S.of(context)!.divorceTransfertAmount(
                          _chfFmt(r.lppSplit.transferAmount),
                          r.lppSplit.transferDirection,
                        ),
                        style: MintTextStyles.bodyMedium(
                          color: MintColors.info,
                        ).copyWith(fontWeight: FontWeight.w600),
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
    final accentColor = isIncrease ? MintColors.warning : MintColors.success;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.divorceImpactFiscal,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: MintSpacing.md),
          MintSignalRow(
            label: S.of(context)!.divorceImpotMarie,
            value: _chfFmt(r.taxImpact.estimatedTaxMarried),
          ),
          MintSignalRow(
            label: S.of(context)!.divorceImpotConjoint1,
            value: _chfFmt(r.taxImpact.estimatedTaxConjoint1),
          ),
          MintSignalRow(
            label: S.of(context)!.divorceImpotConjoint2,
            value: _chfFmt(r.taxImpact.estimatedTaxConjoint2),
          ),
          Divider(color: MintColors.border.withValues(alpha: 0.3)),
          MintSignalRow(
            label: S.of(context)!.divorceTotalApresDivorce,
            value: _chfFmt(r.taxImpact.totalTaxAfter),
            valueColor: accentColor,
          ),
          const SizedBox(height: MintSpacing.sm),
          MintSurface(
            tone: isIncrease ? MintSurfaceTone.peche : MintSurfaceTone.sauge,
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            radius: 12,
            child: Row(
              children: [
                Icon(
                  isIncrease ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: accentColor,
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Semantics(
                    label: S.of(context)!.divorceFiscalDelta(
                      isIncrease ? '+' : '',
                      _chfFmt(r.taxImpact.delta),
                    ),
                    child: Text(
                      S.of(context)!.divorceFiscalDelta(
                        isIncrease ? '+' : '',
                        _chfFmt(r.taxImpact.delta),
                      ),
                      style: MintTextStyles.bodyMedium(
                        color: accentColor,
                      ).copyWith(fontWeight: FontWeight.w600),
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
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.divorcePartagePatrimoine,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: MintSpacing.md),
          MintSignalRow(
            label: S.of(context)!.divorceFortuneNette,
            value: _chfFmt(r.patrimoineSplit.fortuneNette),
          ),
          const SizedBox(height: MintSpacing.sm),
          // Visual bar for split
          Semantics(
            label: S.of(context)!.divorcePartagePatrimoine,
            child: _buildSplitBar(
              r.patrimoineSplit.shareConjoint1,
              r.patrimoineSplit.shareConjoint2,
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          MintSignalRow(
            label: S.of(context)!.divorceConjoint1Label,
            value: _chfFmt(r.patrimoineSplit.shareConjoint1),
          ),
          MintSignalRow(
            label: S.of(context)!.divorceConjoint2Label,
            value: _chfFmt(r.patrimoineSplit.shareConjoint2),
          ),
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
                color: MintColors.purple,
                alignment: Alignment.center,
                child: Text(
                  S.of(context)!.divorceSplitC1,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.white,
                  ).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Flexible(
              flex: ((1 - pct1) * 100).toInt().clamp(1, 99),
              child: Container(
                color: MintColors.purple.withValues(alpha: 0.15),
                alignment: Alignment.center,
                child: Text(
                  S.of(context)!.divorceSplitC2,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.purple,
                  ).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
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
    return MintSurface(
      tone: MintSurfaceTone.peche,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.divorcePensionAlimentaire,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: MintSpacing.md),
          Semantics(
            label: S.of(context)!.divorcePensionMois(
              _chfFmt(r.pensionAlimentaireMonthly),
            ),
            child: Text(
              S.of(context)!.divorcePensionMois(
                _chfFmt(r.pensionAlimentaireMonthly),
              ),
              style: MintTextStyles.displayMedium(
                color: MintColors.textPrimary,
              ).copyWith(fontSize: 28),
            ),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.divorcePensionAnnuel(
              _chfFmt(r.pensionAlimentaireMonthly * 12),
            ),
            style: MintTextStyles.bodyMedium(
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            S.of(context)!.divorcePensionDescription,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontSize: 12, height: 1.5),
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
          S.of(context)!.divorcePointsAttention,
          style: MintTextStyles.labelSmall(
            color: MintColors.textMuted,
          ).copyWith(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        ...r.alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm),
              child: MintSurface(
                tone: MintSurfaceTone.peche,
                padding: const EdgeInsets.all(14),
                radius: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: MintColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        alert,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary,
                        ).copyWith(height: 1.4),
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
      title: S.of(context)!.divorceActionsTitle,
      subtitle: S.of(context)!.divorceActionsSubtitle,
      icon: Icons.checklist,
      accentColor: MintColors.purple,
      child: Column(
        children: List.generate(r.checklist.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: MintSpacing.sm),
            child: Semantics(
              label: r.checklist[index],
              toggled: _checklistState[index],
              child: InkWell(
              onTap: () {
                setState(() {
                  _checklistState[index] = !_checklistState[index];
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.sm + 4,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _checklistState[index]
                      ? MintColors.success.withValues(alpha: 0.06)
                      : MintColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _checklistState[index]
                        ? MintColors.success.withValues(alpha: 0.3)
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
                    const SizedBox(width: MintSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        r.checklist[index],
                        style: MintTextStyles.bodySmall(
                          color: _checklistState[index]
                              ? MintColors.textSecondary
                              : MintColors.textPrimary,
                        ).copyWith(
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
          S.of(context)!.divorceComprendre,
          style: MintTextStyles.labelSmall(
            color: MintColors.textMuted,
          ).copyWith(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildExpandableTile(
          S.of(context)!.divorceEduParticipationTitle,
          S.of(context)!.divorceEduParticipationContent,
        ),
        const SizedBox(height: MintSpacing.sm),
        _buildExpandableTile(
          S.of(context)!.divorceEduLppTitle,
          S.of(context)!.divorceEduLppContent,
        ),
      ],
    );
  }

  // --- Expandable Tile ---
  Widget _buildExpandableTile(String title, String content) {
    return MintSurface(
      tone: MintSurfaceTone.craie,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: MintColors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: MintSpacing.md, vertical: MintSpacing.xs),
          childrenPadding: const EdgeInsets.fromLTRB(MintSpacing.md, 0, MintSpacing.md, MintSpacing.md),
          title: Text(
            title,
            style: MintTextStyles.bodyMedium(
              color: MintColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
          children: [
            Text(
              content,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ).copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // --- Disclaimer ---
  Widget _buildDisclaimer() {
    return Semantics(
      label: S.of(context)!.divorceDisclaimer,
      child: MintSurface(
        tone: MintSurfaceTone.peche,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: MintColors.corailDiscret),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Text(
                S.of(context)!.divorceDisclaimer,
                style: MintTextStyles.micro(
                  color: MintColors.textMuted,
                ).copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MINT Coach Widget: Divorce Film ---
  Widget _buildMintDivorceSection() {
    final taxMarried = _result?.taxImpact.estimatedTaxMarried ??
        (_incomeConjoint1 + _incomeConjoint2) * 0.18;
    final taxSingle = _result != null
        ? _result!.taxImpact.estimatedTaxConjoint1 +
            _result!.taxImpact.estimatedTaxConjoint2
        : _incomeConjoint1 * 0.20 + _incomeConjoint2 * 0.20;
    return DivorceFilmWidget(
      myLpp: _lppConjoint1,
      partnerLpp: _lppConjoint2,
      annualTaxMarried: taxMarried,
      annualTaxSingle: taxSingle,
      childrenCount: _numberOfChildren,
      // Contribution d'entretien : possible même sans enfants (CC art. 125)
      hasAlimony: _marriageDuration >= 10 || _numberOfChildren > 0,
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
    return MintPremiumSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      formatValue: format,
      onChanged: (v) {
        setState(() {
          onChanged(v);
        });
      },
    );
  }
}
