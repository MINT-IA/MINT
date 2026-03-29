import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/widgets/coach/clause_3a_widget.dart';
import 'package:mint_mobile/widgets/coach/survivor_pension_widget.dart';
import 'package:mint_mobile/widgets/visualizations/marriage_penalty_gauge.dart';
import 'package:mint_mobile/widgets/visualizations/regime_matrimonial_pie.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_signal_row.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/coach/couple_narrative_timeline.dart';

// ────────────────────────────────────────────────────────────
//  MARIAGE SCREEN — Category C (Life Event)
// ────────────────────────────────────────────────────────────
//
// Four-tab interactive screen:
//   Tab 1: "Impots"     — Marriage penalty/bonus calculator
//   Tab 2: "Regime"     — Matrimonial regime comparison
//   Tab 3: "Protection" — Survivor benefits (married vs not)
//   Tab 4: "Checklist"  — Essential steps before/after marriage
//
// Design System: MintTextStyles + MintSpacing tokens.
// AppBar: white standard (Life Event screen).
// Ne constitue pas un conseil fiscal ou juridique (LSFin).
// ────────────────────────────────────────────────────────────

class MariageScreen extends StatefulWidget {
  const MariageScreen({super.key});

  @override
  State<MariageScreen> createState() => _MariageScreenState();
}

class _MariageScreenState extends State<MariageScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: Impots inputs ──────────────────────────────
  double _revenu1 = 80000;
  double _revenu2 = 60000;
  String _canton = 'VD';
  int _nbEnfants = 0;
  Map<String, dynamic>? _fiscalResult;

  // ── Tab 2: Regime inputs ──────────────────────────────
  int _selectedRegime = 0; // 0=participation, 1=separation, 2=communaute
  double _patrimoine1 = 200000;
  double _patrimoine2 = 100000;

  // ── Tab 3: Protection ─────────────────────────────────
  double _renteLpp = 2500;

  // ── Tab 4: Checklist ──────────────────────────────────
  final Set<int> _checkedItems = {};
  final Map<int, bool> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _recalculate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _fiscalResult = FamilyService.compareFiscalMariage(
        revenu1: _revenu1,
        revenu2: _revenu2,
        canton: _canton,
        nbEnfants: _nbEnfants,
      );
    });
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(context, innerBoxIsScrolled),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTab1Impots(),
            _buildTab2Regime(),
            _buildTab3Protection(),
            _buildTab4Checklist(),
          ],
        ),
      ),
    );
  }

  // ── App Bar with Tabs (white standard — Life Event) ──

  Widget _buildAppBar(BuildContext context, bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: 120,
      backgroundColor: MintColors.porcelaine,
      elevation: 0,
      surfaceTintColor: MintColors.porcelaine,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 56, right: MintSpacing.md),
        title: Text(
          S.of(context)!.mariageTitle,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: MintColors.primary,
        indicatorWeight: 2,
        labelColor: MintColors.textPrimary,
        unselectedLabelColor: MintColors.textMuted,
        dividerColor: MintColors.border.withValues(alpha: 0.3),
        labelStyle: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        unselectedLabelStyle: MintTextStyles.bodySmall(color: MintColors.textMuted),
        tabs: [
          Tab(text: S.of(context)!.mariageTabImpots),
          Tab(text: S.of(context)!.mariageTabRegime),
          Tab(text: S.of(context)!.mariageTabProtection),
          Tab(text: S.of(context)!.naissanceTabChecklist),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: IMPOTS — Marriage fiscal impact
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Impots() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Narrative intro
        MintNarrativeCard(
          headline: S.of(context)!.narrativeMarriageHeadline,
          body: S.of(context)!.narrativeMarriageBody,
          tone: MintSurfaceTone.peche,
          badge: S.of(context)!.narrativeMarriageBadge,
        ),
        const SizedBox(height: MintSpacing.xl),

        // Hero: impact fiscal couple (always visible)
        if (_fiscalResult != null) ...[
          _buildFiscalHeroCard(),
          const SizedBox(height: MintSpacing.xl),
        ],
        _buildImpotsInputsCard(),
        const SizedBox(height: MintSpacing.xl),
        if (_fiscalResult != null) ...[
          MarriagePenaltyGauge(
            taxSingles: (_fiscalResult!['totalCelibataires'] as double),
            taxMarried: (_fiscalResult!['totalMarie'] as double),
          ),
          const SizedBox(height: MintSpacing.xl),
          _buildDeductionsBreakdown(),
          const SizedBox(height: MintSpacing.xl),
        ],
        _buildEducationalInsert(
          S.of(context)!.mariageEducationalPenalty,
        ),
        const SizedBox(height: MintSpacing.xl),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildFiscalHeroCard() {
    final result = _fiscalResult!;
    final difference = result['difference'] as double;
    final isPenalite = result['isPenalite'] as bool;
    final totalMarie = result['totalMarie'] as double;

    return MintResultHeroCard(
      eyebrow: S.of(context)!.mariageFiscalComparison,
      primaryValue: '${isPenalite ? "+" : "-"}${FamilyService.formatChf(difference.abs())}',
      primaryLabel: isPenalite
          ? S.of(context)!.mariagePenaltyAmount(FamilyService.formatChf(difference.abs()))
          : S.of(context)!.mariageBonusAmount(FamilyService.formatChf(difference.abs())),
      secondaryValue: FamilyService.formatChf(totalMarie),
      secondaryLabel: S.of(context)!.mariageMaries,
      narrative: isPenalite
          ? S.of(context)!.mariageEducationalPenalty
          : S.of(context)!.mariageEducationalPenalty,
      accentColor: isPenalite ? MintColors.error : MintColors.success,
      tone: MintSurfaceTone.porcelaine,
    );
  }

  Widget _buildImpotsInputsCard() {
    final sortedCodes = FamilyService.sortedCantonCodes;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintAmountField(
            label: S.of(context)!.mariageRevenu1,
            value: _revenu1,
            formatValue: (v) => FamilyService.formatChf(v),
            onChanged: (v) {
              setState(() {
                _revenu1 = v;
                _recalculate();
              });
            },
            min: 0,
            max: 300000,
          ),
          const SizedBox(height: MintSpacing.lg),
          MintAmountField(
            label: S.of(context)!.mariageRevenu2,
            value: _revenu2,
            formatValue: (v) => FamilyService.formatChf(v),
            onChanged: (v) {
              setState(() {
                _revenu2 = v;
                _recalculate();
              });
            },
            min: 0,
            max: 300000,
          ),
          const SizedBox(height: MintSpacing.lg),

          // Canton dropdown
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.mariageCanton,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: MintColors.porcelaine,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _canton,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                    items: sortedCodes.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(
                            '$code — ${FamilyService.cantonNames[code]}'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _canton = v;
                        _recalculate();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          // Children counter
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.mariageEnfants,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ),
              _buildStepper(
                value: _nbEnfants,
                minVal: 0,
                maxVal: 5,
                onChanged: (v) {
                  _nbEnfants = v;
                  _recalculate();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // _buildHeroComparisonCard removed — replaced by MintResultHeroCard in _buildFiscalHeroCard

  Widget _buildDeductionsBreakdown() {
    final result = _fiscalResult!;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.mariageDeductions,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          MintSignalRow(
            label: S.of(context)!.mariageDeductionCouple,
            value: FamilyService.formatChf(result['deductionMarie'] as double),
          ),
          MintSignalRow(
            label: S.of(context)!.mariageDeductionInsurance,
            value: FamilyService.formatChf(result['deductionAssurance'] as double),
          ),
          if ((result['deductionDoubleRevenu'] as double) > 0)
            MintSignalRow(
              label: S.of(context)!.mariageDeductionDualIncome,
              value: FamilyService.formatChf(
                  result['deductionDoubleRevenu'] as double),
            ),
          if ((result['deductionEnfants'] as double) > 0)
            MintSignalRow(
              label: S.of(context)!.mariageDeductionChildren,
              value: FamilyService.formatChf(result['deductionEnfants'] as double),
            ),
          Divider(color: MintColors.border.withValues(alpha: 0.3)),
          MintSignalRow(
            label: S.of(context)!.mariageTotalDeductions,
            value: FamilyService.formatChf(result['totalDeductions'] as double),
            valueColor: MintColors.primary,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: REGIME — Matrimonial regime comparison
  // ════════════════════════════════════════════════════════════

  RegimeMatrimonial _regimeFromIndex(int index) {
    switch (index) {
      case 1:
        return RegimeMatrimonial.separationBiens;
      case 2:
        return RegimeMatrimonial.communauteBiens;
      default:
        return RegimeMatrimonial.participationAcquets;
    }
  }

  Widget _buildTab2Regime() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Regime cards
        Row(
          children: [
            const Icon(Icons.gavel, size: 16, color: MintColors.textMuted),
            const SizedBox(width: MintSpacing.sm),
            Text(
              S.of(context)!.mariageRegimeMatrimonial,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildRegimeCard(
          index: 0,
          icon: Icons.handshake_outlined,
          title: S.of(context)!.mariageParticipation,
          subtitle: S.of(context)!.mariageParticipationSub,
          description: S.of(context)!.mariageParticipationDesc,
        ),
        const SizedBox(height: MintSpacing.sm + 2),
        _buildRegimeCard(
          index: 1,
          icon: Icons.lock_outline,
          title: S.of(context)!.mariageSeparation,
          subtitle: S.of(context)!.mariageSeparationSub,
          description: S.of(context)!.mariageSeparationDesc,
        ),
        const SizedBox(height: MintSpacing.sm + 2),
        _buildRegimeCard(
          index: 2,
          icon: Icons.group_outlined,
          title: S.of(context)!.mariageCommunaute,
          subtitle: S.of(context)!.mariageCommunauteSub,
          description: S.of(context)!.mariageCommunauteDesc,
        ),
        const SizedBox(height: MintSpacing.lg),

        // Patrimoine sliders
        MintSurface(
          tone: MintSurfaceTone.blanc,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MintAmountField(
                label: S.of(context)!.mariagePatrimoine1,
                value: _patrimoine1,
                formatValue: (v) => FamilyService.formatChf(v),
                onChanged: (v) {
                  setState(() {
                    _patrimoine1 = v;
                  });
                },
                min: 0,
                max: 1000000,
              ),
              const SizedBox(height: MintSpacing.lg),
              MintAmountField(
                label: S.of(context)!.mariagePatrimoine2,
                value: _patrimoine2,
                formatValue: (v) => FamilyService.formatChf(v),
                onChanged: (v) {
                  setState(() {
                    _patrimoine2 = v;
                  });
                },
                min: 0,
                max: 1000000,
              ),
            ],
          ),
        ),
        const SizedBox(height: MintSpacing.xl),

        // Pie chart visualization — animated donut per regime
        RegimeMatrimonialPie(
          assetsPersonne1: _patrimoine1,
          assetsPersonne2: _patrimoine2,
          regime: _regimeFromIndex(_selectedRegime),
          onRegimeChanged: (r) => setState(() => _selectedRegime = r.index),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Chiffre choc
        _buildChiffreChocRegime(),
        const SizedBox(height: MintSpacing.lg),

        // ── Couple Narrative Timeline ─────────────────────────
        CoupleNarrativeTimeline(
          partner1Name: S.of(context)!.mariageTimelinePartner1,
          partner2Name: S.of(context)!.mariageTimelinePartner2,
          coachTip: S.of(context)!.mariageTimelineCoachTip,
          acts: [
            CoupleAct(
              number: 1,
              title: S.of(context)!.mariageTimelineAct1Title,
              period: S.of(context)!.mariageTimelineAct1Period,
              monthlyIncome: (_revenu1 + _revenu2) / 12,
              insight: S.of(context)!.mariageTimelineAct1Insight,
            ),
            CoupleAct(
              number: 2,
              title: S.of(context)!.mariageTimelineAct2Title,
              period: S.of(context)!.mariageTimelineAct2Period,
              monthlyIncome: (_revenu1 + _revenu2) / 12 * 1.15,
              deltaPercent: 15,
              insight: S.of(context)!.mariageTimelineAct2Insight,
            ),
            CoupleAct(
              number: 3,
              title: S.of(context)!.mariageTimelineAct3Title,
              period: S.of(context)!.mariageTimelineAct3Period,
              monthlyIncome: (_revenu1 + _revenu2) / 12 * 0.65,
              deltaPercent: -35,
              isDip: true,
              insight: S.of(context)!.mariageTimelineAct3Insight,
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.lg),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildRegimeCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
  }) {
    final isSelected = _selectedRegime == index;

    return Semantics(
      label: title,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedRegime = index);
        },
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? MintColors.primary.withValues(alpha: 0.04)
              : MintColors.craie,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? MintColors.primary.withValues(alpha: 0.1)
                    : MintColors.porcelaine,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color:
                    isSelected ? MintColors.primary : MintColors.textSecondary,
              ),
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: MintSpacing.xs + 2),
                  Text(
                    description,
                    style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: MintColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.check, size: 14, color: MintColors.white),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildChiffreChocRegime() {
    final total = _patrimoine1 + _patrimoine2;
    if (total <= 0) return const SizedBox.shrink();

    double acquetsPartage;
    if (_selectedRegime == 0) {
      // Participation: 50/50 of total
      acquetsPartage = (total / 2 - min(_patrimoine1, _patrimoine2)).abs();
    } else if (_selectedRegime == 2) {
      acquetsPartage = (total / 2 - min(_patrimoine1, _patrimoine2)).abs();
    } else {
      return const SizedBox.shrink();
    }

    if (acquetsPartage <= 0) return const SizedBox.shrink();

    return MintResultHeroCard(
      eyebrow: S.of(context)!.mariageRegimeMatrimonial,
      primaryValue: FamilyService.formatChf(acquetsPartage),
      primaryLabel: _selectedRegime == 0
          ? S.of(context)!.mariageChiffreChocDefault
          : S.of(context)!.mariageChiffreChocCommunaute,
      narrative: _selectedRegime == 0
          ? S.of(context)!.mariageChiffreChocDefault
          : S.of(context)!.mariageChiffreChocCommunaute,
      tone: MintSurfaceTone.peche,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: PROTECTION — Survivor benefits
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Protection() {
    const avsSurvivor = avsRenteMaxMensuelle *
        FamilyService.avsSurvivorFactor;
    final lppSurvivor = _renteLpp * FamilyService.lppSurvivorFactor;
    final totalSurvivor = avsSurvivor + lppSurvivor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Hero: total survivor monthly
        MintResultHeroCard(
          eyebrow: S.of(context)!.mariageTabProtection,
          primaryValue: '${FamilyService.formatChf(totalSurvivor)}/mois',
          primaryLabel: S.of(context)!.mariageSurvivorMonthly,
          narrative: S.of(context)!.mariageProtectionIntro,
          accentColor: MintColors.success,
          tone: MintSurfaceTone.sauge,
        ),
        const SizedBox(height: MintSpacing.xl),

        // LPP slider
        MintSurface(
          tone: MintSurfaceTone.blanc,
          child: MintAmountField(
            label: S.of(context)!.mariageLppRenteLabel,
            value: _renteLpp,
            formatValue: (v) => FamilyService.formatChf(v),
            onChanged: (v) {
              setState(() {
                _renteLpp = v;
              });
            },
            min: 0,
            max: 8000,
          ),
        ),
        const SizedBox(height: MintSpacing.xl),

        // AVS survivor
        _buildSurvivorCard(
          icon: Icons.account_balance_outlined,
          label: S.of(context)!.mariageAvsSurvivor,
          subtitle: S.of(context)!.mariageAvsSurvivorSub,
          value: avsSurvivor,
          footnote: S.of(context)!.mariageAvsSurvivorFootnote,
        ),
        const SizedBox(height: MintSpacing.sm + 4),

        // LPP survivor
        _buildSurvivorCard(
          icon: Icons.savings_outlined,
          label: S.of(context)!.mariageLppSurvivor,
          subtitle: S.of(context)!.mariageLppSurvivorSub,
          value: lppSurvivor,
          footnote: S.of(context)!.mariageLppSurvivorFootnote,
        ),
        const SizedBox(height: MintSpacing.xl),

        // Married vs unmarried comparison
        _buildProtectionComparison(),
        const SizedBox(height: MintSpacing.lg),

        // Protection checklist
        _buildProtectionChecklist(),
        const SizedBox(height: MintSpacing.lg),

        _buildClause3aSection(),
        const SizedBox(height: MintSpacing.lg),
        SurvivorPensionWidget(
          partnerAvsRente: avsRenteMaxMensuelle,
          partnerLppMonthly: _renteLpp,
          isConcubin: false,
        ),
        const SizedBox(height: MintSpacing.lg),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildClause3aSection() {
    final profile = context.read<CoachProfileProvider>().profile;
    final balance = profile?.prevoyance.totalEpargne3a ?? 0;
    // Estimation si pas de donnee : revenu moyen du couple x 5% x 10 ans
    final estimated = balance > 0
        ? balance
        : (_revenu1 + _revenu2) * 0.05 * 10;
    return Clause3aWidget(
      balance3a: estimated,
    );
  }

  Widget _buildSurvivorCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required double value,
    required String footnote,
  }) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MintColors.saugeClaire.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: MintColors.success),
          ),
          const SizedBox(width: MintSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  footnote,
                  style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          Text(
            '${FamilyService.formatChf(value)}/mois',
            style: MintTextStyles.bodyMedium(color: MintColors.success).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionComparison() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare, size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.mariageVsConcubin,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          _buildComparisonRow(S.of(context)!.mariageRenteAvsSurvivor, true, false),
          _buildComparisonRow(S.of(context)!.mariageRenteLppSurvivor, true, false),
          _buildComparisonRow(S.of(context)!.mariageHeritageExonere, true, false),
          _buildComparisonRow(S.of(context)!.mariagePensionAlimentaire, true, false),
          const SizedBox(height: MintSpacing.sm),
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber,
                    size: 18, color: MintColors.error),
                const SizedBox(width: MintSpacing.sm + 2),
                Expanded(
                  child: Text(
                    S.of(context)!.mariageConcubinWarning,
                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, bool married, bool concubin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                married ? Icons.check_circle : Icons.cancel,
                size: 20,
                color: married ? MintColors.success : MintColors.error,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Icon(
                concubin ? Icons.check_circle : Icons.cancel,
                size: 20,
                color: concubin ? MintColors.success : MintColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionChecklist() {
    final items = [
      S.of(context)!.mariageProtectionItem1,
      S.of(context)!.mariageProtectionItem2,
      S.of(context)!.mariageProtectionItem3,
      S.of(context)!.mariageProtectionItem4,
      S.of(context)!.mariageProtectionItem5,
    ];

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.mariageProtectionsEssentielles,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: const BoxDecoration(
                        color: MintColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: MintSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        item,
                        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 4: CHECKLIST — Essential steps before/after marriage
  // ════════════════════════════════════════════════════════════

  Widget _buildTab4Checklist() {
    final items = _buildMariageChecklistItems();
    final nbChecked = _checkedItems.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Intro
        MintSurface(
          tone: MintSurfaceTone.bleu,
          padding: const EdgeInsets.all(MintSpacing.md + 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.checklist_rtl,
                  color: MintColors.info, size: 20),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: Text(
                  S.of(context)!.mariageChecklistIntro,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MintSpacing.xl),

        // Progress bar
        MintSurface(
          tone: MintSurfaceTone.blanc,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.of(context)!.mariageChecklistProgress(nbChecked, items.length),
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(nbChecked / items.length * 100).toStringAsFixed(0)}%',
                    style: MintTextStyles.titleMedium(
                      color: nbChecked == items.length
                          ? MintColors.success
                          : MintColors.primary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: MintSpacing.sm + 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: LinearProgressIndicator(
                    value: items.isNotEmpty ? nbChecked / items.length : 0,
                    backgroundColor: MintColors.porcelaine,
                    color: nbChecked == items.length
                        ? MintColors.success
                        : MintColors.primary,
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MintSpacing.xl),

        // Checklist items
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildChecklistItem(
            index: index,
            title: item['title'] as String,
            description: item['description'] as String,
          );
        }),
        const SizedBox(height: MintSpacing.lg),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildChecklistItem({
    required int index,
    required String title,
    required String description,
  }) {
    final isChecked = _checkedItems.contains(index);
    final isExpanded = _expandedItems[index] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isChecked
              ? MintColors.saugeClaire.withValues(alpha: 0.3)
              : MintColors.craie,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Semantics(
              label: title,
              button: true,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _expandedItems[index] = !isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(MintSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label: title,
                        button: true,
                        toggled: isChecked,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isChecked) {
                                _checkedItems.remove(index);
                              } else {
                                _checkedItems.add(index);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isChecked
                                  ? MintColors.success
                                  : MintColors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: isChecked
                                    ? MintColors.success
                                    : MintColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: isChecked
                                ? const Icon(Icons.check,
                                    size: 15, color: MintColors.white)
                                : null,
                          ),
                        ),
                      ),
                    const SizedBox(width: MintSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        title,
                        style: MintTextStyles.bodyMedium(
                          color: isChecked
                              ? MintColors.textMuted
                              : MintColors.textPrimary,
                        ).copyWith(
                          fontWeight: FontWeight.w600,
                          decoration:
                              isChecked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: MintColors.textMuted,
                    ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                padding: const EdgeInsets.fromLTRB(52, 0, MintSpacing.md, MintSpacing.md),
                child: Text(
                  description,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  // ── Checklist Data ──────────────────────────────────────

  // Checklist data is built dynamically using i18n keys — see _buildMariageChecklistItems()
  List<Map<String, String>> _buildMariageChecklistItems() {
    return [
      {'title': S.of(context)!.mariageChecklistItem1Title, 'description': S.of(context)!.mariageChecklistItem1Desc},
      {'title': S.of(context)!.mariageChecklistItem2Title, 'description': S.of(context)!.mariageChecklistItem2Desc},
      {'title': S.of(context)!.mariageChecklistItem3Title, 'description': S.of(context)!.mariageChecklistItem3Desc},
      {'title': S.of(context)!.mariageChecklistItem4Title, 'description': S.of(context)!.mariageChecklistItem4Desc},
      {'title': S.of(context)!.mariageChecklistItem5Title, 'description': S.of(context)!.mariageChecklistItem5Desc},
      {'title': S.of(context)!.mariageChecklistItem6Title, 'description': S.of(context)!.mariageChecklistItem6Desc},
      {'title': S.of(context)!.mariageChecklistItem7Title, 'description': S.of(context)!.mariageChecklistItem7Desc},
    ];
  }

  // ════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _buildStepper({
    required int value,
    required int minVal,
    required int maxVal,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Semantics(
          label: S.of(context)!.mariageEnfants,
          button: true,
          child: IconButton(
            onPressed: value > minVal
                ? () {
                    setState(() => onChanged(value - 1));
                  }
                : null,
            icon: const Icon(Icons.remove_circle_outline, size: 24),
            color: MintColors.primary,
          ),
        ),
        SizedBox(
          width: MintSpacing.xl,
          child: Text(
            '$value',
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          label: S.of(context)!.mariageEnfants,
          button: true,
          child: IconButton(
            onPressed: value < maxVal
                ? () {
                    setState(() => onChanged(value + 1));
                  }
                : null,
            icon: const Icon(Icons.add_circle_outline, size: 24),
            color: MintColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildEducationalInsert(String text) {
    return MintSurface(
      tone: MintSurfaceTone.bleu,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, size: 18, color: MintColors.info),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.lifeEventDidYouKnow,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  text,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return MintSurface(
      tone: MintSurfaceTone.peche,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.corailDiscret, size: 18),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.mariageDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
