import 'dart:math';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/widgets/coach/baby_cost_widget.dart';
import 'package:mint_mobile/widgets/coach/budget_bebe_widget.dart';
import 'package:mint_mobile/widgets/coach/clause_3a_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/visualizations/fiscal_impact_waterfall.dart';

// ────────────────────────────────────────────────────────────
//  NAISSANCE SCREEN — Category C (Life Event)
// ────────────────────────────────────────────────────────────
//
// Four-tab interactive screen:
//   Tab 1: "Conge"       — Parental leave APG calculator
//   Tab 2: "Allocations" — Family allowances by canton
//   Tab 3: "Impact"      — Financial impact of having children
//   Tab 4: "Checklist"   — Essential steps for new parents
//
// Design System: MintTextStyles + MintSpacing tokens.
// AppBar: white standard (Life Event screen).
// Ne constitue pas un conseil en prevoyance (LSFin).
// ────────────────────────────────────────────────────────────

class NaissanceScreen extends StatefulWidget {
  const NaissanceScreen({super.key});

  @override
  State<NaissanceScreen> createState() => _NaissanceScreenState();
}

class _NaissanceScreenState extends State<NaissanceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: Conge inputs ───────────────────────────────
  bool _isMother = true;
  double _salaireMensuel = 6000;
  Map<String, dynamic>? _congeResult;

  // ── Tab 2: Allocations inputs ─────────────────────────
  String _cantonAlloc = 'VD';
  int _nbEnfantsAlloc = 1;
  Map<String, dynamic>? _allocResult;
  List<Map<String, dynamic>> _allocRanking = [];

  // ── Tab 3: Impact inputs ──────────────────────────────
  double _revenuImpact = 80000;
  int _nbEnfantsImpact = 1;
  double _fraisGarde = 1500;

  // ── Tab 4: Checklist state ──────────────────────────────
  final Set<int> _checkedItems = {};
  final Map<int, bool> _expandedItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _recalculateAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _recalculateAll() {
    setState(() {
      _recalculateConge();
      _recalculateAlloc();
    });
  }

  void _recalculateConge() {
    _congeResult = FamilyService.simulateCongeParental(
      salaireMensuel: _salaireMensuel,
      isMother: _isMother,
    );
  }

  void _recalculateAlloc() {
    _allocResult = FamilyService.estimateAllocations(
      canton: _cantonAlloc,
      nbEnfants: _nbEnfantsAlloc,
    );
    _allocRanking = FamilyService.getAllocationsRanking(
      nbEnfants: _nbEnfantsAlloc,
    );
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
            _buildTab1Conge(),
            _buildTab2Allocations(),
            _buildTab3Impact(),
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
        onPressed: () => safePop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 56, right: MintSpacing.md),
        title: Text(
          S.of(context)!.naissanceTitle,
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
          Tab(text: S.of(context)!.naissanceTabConge),
          Tab(text: S.of(context)!.naissanceTabAllocations),
          Tab(text: S.of(context)!.naissanceTabImpact),
          Tab(text: S.of(context)!.naissanceTabChecklist),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: CONGE — Parental leave calculator
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Conge() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Narrative intro
        MintNarrativeCard(
          headline: S.of(context)!.narrativeBirthHeadline,
          body: S.of(context)!.narrativeBirthBody,
          tone: MintSurfaceTone.peche,
          badge: S.of(context)!.narrativeBirthBadge,
        ),
        const SizedBox(height: MintSpacing.xl),

        // Hero: premier éclairage APG
        if (_congeResult != null) ...[
          _buildCongePremierEclairage(),
          const SizedBox(height: MintSpacing.xl),
        ],

        // Toggle + salary
        _buildCongeInputsCard(),
        const SizedBox(height: MintSpacing.xl),

        if (_congeResult != null) ...[
          _buildCongeTimeline(),
          const SizedBox(height: MintSpacing.xl),
          _buildCongeBreakdown(),
          const SizedBox(height: MintSpacing.xl),
        ],

        _buildEducationalInsert(
          S.of(context)!.naissanceCongeEducational,
        ),
        const SizedBox(height: MintSpacing.xl),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildCongeInputsCard() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mother/Father toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.naissanceLeaveType,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ),
              SegmentedButton<bool>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: MintColors.primary,
                  selectedForegroundColor: MintColors.white,
                  textStyle: MintTextStyles.labelMedium(color: MintColors.textPrimary),
                ),
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(S.of(context)!.naissanceMother),
                    icon: const Icon(Icons.woman, size: 16),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(S.of(context)!.naissanceFather),
                    icon: const Icon(Icons.man, size: 16),
                  ),
                ],
                selected: {_isMother},
                onSelectionChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isMother = v.first;
                    _recalculateConge();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.lg),

          // Salary input
          MintAmountField(
            label: S.of(context)!.naissanceMonthlySalary,
            value: _salaireMensuel,
            formatValue: (v) => FamilyService.formatChf(v),
            onChanged: (v) {
              setState(() {
                _salaireMensuel = v;
                _recalculateConge();
              });
            },
            min: 2000,
            max: 15000,
          ),
        ],
      ),
    );
  }

  Widget _buildCongeTimeline() {
    final result = _congeResult!;
    final weeks = result['dureeSemaines'] as int;
    final apgDaily = result['apgJournalier'] as double;
    final totalApg = result['totalApg'] as double;
    final isCapped = result['isCapped'] as bool;
    final type = result['type'] as String;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.naissanceCongeLabel(type),
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),

          // Timeline bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _isMother
                    ? MintColors.info.withValues(alpha: 0.15)
                    : MintColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isMother ? MintColors.info : MintColors.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        S.of(context)!.naissanceWeeks(weeks),
                        style: MintTextStyles.bodyMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.md),

          // Details
          _buildResultRow(
            S.of(context)!.naissanceApgPerDay,
            FamilyService.formatChf(apgDaily),
          ),
          const SizedBox(height: MintSpacing.sm),
          _buildResultRow(
            S.of(context)!.naissanceTotalApg,
            FamilyService.formatChf(totalApg),
          ),
          if (isCapped) ...[
            const SizedBox(height: MintSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm, vertical: MintSpacing.xs),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                S.of(context)!.naissanceCappedAt(FamilyService.apgDailyMax.toStringAsFixed(0)),
                style: MintTextStyles.labelSmall(color: MintColors.warning).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCongeBreakdown() {
    final result = _congeResult!;
    final salaireJour = result['salaireJournalier'] as double;
    final apgJour = result['apgJournalier'] as double;
    final perte = result['perteSalaire'] as double;
    final diffJour = salaireJour - apgJour;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.naissanceDailyDetail,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildBarComparison(
            label: S.of(context)!.naissanceSalaryPerDay,
            value: salaireJour,
            maxValue: max(salaireJour, apgJour),
            color: MintColors.primary,
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          _buildBarComparison(
            label: S.of(context)!.naissanceApgDay,
            value: apgJour,
            maxValue: max(salaireJour, apgJour),
            color: MintColors.success,
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Divider(color: MintColors.border.withValues(alpha: 0.5)),
          const SizedBox(height: MintSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                diffJour > 0 ? S.of(context)!.naissanceDiffPerDay : S.of(context)!.naissanceNoLoss,
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
              ),
              if (diffJour > 0)
                Text(
                  '-${FamilyService.formatChf(diffJour)}',
                  style: MintTextStyles.titleMedium(color: MintColors.error).copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          if (perte > 0) ...[
            const SizedBox(height: MintSpacing.sm),
            Text(
              S.of(context)!.naissanceTotalLossEstimated(FamilyService.formatChf(perte)),
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCongePremierEclairage() {
    final result = _congeResult!;
    final totalApg = result['totalApg'] as double;
    final weeks = result['dureeSemaines'] as int;
    final typeLabel = _isMother
        ? S.of(context)!.naissanceMaternite
        : S.of(context)!.naissancePaternite;

    return MintResultHeroCard(
      eyebrow: typeLabel,
      primaryValue: FamilyService.formatChf(totalApg),
      primaryLabel: S.of(context)!.naissanceTotalApg,
      secondaryValue: S.of(context)!.naissanceWeeks(weeks),
      secondaryLabel: S.of(context)!.naissanceCongeLabel(typeLabel),
      narrative: S.of(context)!.naissancePremierEclairageText(typeLabel, FamilyService.formatChf(totalApg), weeks),
      tone: MintSurfaceTone.peche,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: ALLOCATIONS — Family allowances by canton
  // ════════════════════════════════════════════════════════════

  Widget _buildTab2Allocations() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Inputs
        _buildAllocInputsCard(),
        const SizedBox(height: MintSpacing.lg),

        if (_allocResult != null) ...[
          // Hero card
          _buildAllocHeroCard(),
          const SizedBox(height: MintSpacing.lg),

          // Canton ranking
          _buildAllocRanking(),
          const SizedBox(height: MintSpacing.lg),

          // Chiffre choc
          _buildAllocPremierEclairage(),
          const SizedBox(height: MintSpacing.lg),
        ],

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildAllocInputsCard() {
    final sortedCodes = FamilyService.sortedCantonCodes;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        children: [
          // Canton dropdown
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.naissanceCanton,
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
                    value: _cantonAlloc,
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
                        setState(() {
                          _cantonAlloc = v;
                          _recalculateAlloc();
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          // Children stepper
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.naissanceNbEnfants,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ),
              _buildStepper(
                value: _nbEnfantsAlloc,
                minVal: 1,
                maxVal: 5,
                onChanged: (v) {
                  _nbEnfantsAlloc = v;
                  _recalculateAlloc();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllocHeroCard() {
    final result = _allocResult!;
    final mensuel = result['mensuelTotal'] as double;
    final annuel = result['annuelTotal'] as double;
    final cantonNom = FamilyService.cantonNames[_cantonAlloc] ?? _cantonAlloc;
    final plural = _nbEnfantsAlloc > 1 ? 's' : '';

    return MintResultHeroCard(
      eyebrow: S.of(context)!.naissanceTabAllocations,
      primaryValue: '${FamilyService.formatChf(mensuel)}/mois',
      primaryLabel: '${FamilyService.formatChf(annuel)}/an',
      narrative: S.of(context)!.naissanceAllocForCanton(cantonNom, _nbEnfantsAlloc, plural),
      accentColor: MintColors.success,
      tone: MintSurfaceTone.sauge,
    );
  }

  Widget _buildAllocRanking() {
    if (_allocRanking.isEmpty) return const SizedBox.shrink();

    final maxMensuel = _allocRanking.first['mensuelTotal'] as double;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.sm, MintSpacing.lg, MintSpacing.sm + 4),
            child: Text(
              S.of(context)!.naissanceRanking26,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
          ),
          ..._allocRanking.map((c) {
            final canton = c['canton'] as String;
            final mensuel = c['mensuelTotal'] as double;
            final isHighlighted = canton == _cantonAlloc;
            final ratio = maxMensuel > 0 ? mensuel / maxMensuel : 0.0;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: MintSpacing.xs + 2),
              color: isHighlighted
                  ? MintColors.primary.withValues(alpha: 0.06)
                  : null,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${c['rank']}',
                      style: MintTextStyles.labelSmall(
                        color: isHighlighted
                            ? MintColors.primary
                            : MintColors.textMuted,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      canton,
                      style: MintTextStyles.bodySmall(
                        color: isHighlighted
                            ? MintColors.primary
                            : MintColors.textPrimary,
                      ).copyWith(
                        fontWeight:
                            isHighlighted ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: MintColors.appleSurface,
                        color: isHighlighted
                            ? MintColors.primary
                            : MintColors.border,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: MintSpacing.sm + 2),
                  SizedBox(
                    width: 70,
                    child: Text(
                      FamilyService.formatChf(mensuel),
                      style: MintTextStyles.labelSmall(
                        color: isHighlighted
                            ? MintColors.primary
                            : MintColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                      textAlign: TextAlign.right,
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

  Widget _buildAllocPremierEclairage() {
    final result = _allocResult!;
    final diff = result['differenceVsBest'] as double;
    final bestCanton = result['bestCantonNom'] as String;
    final cantonNom = result['cantonNom'] as String;

    if (diff <= 0) {
      return Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: MintColors.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined,
                size: 20, color: MintColors.success),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Text(
                S.of(context)!.naissanceBestCanton(cantonNom),
                style: MintTextStyles.bodySmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return _buildEducationalInsert(
      S.of(context)!.naissanceAllocDiff(bestCanton, cantonNom, FamilyService.formatChf(diff)),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: IMPACT — Financial impact of having children
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Impact() {
    final tauxMarginal = 0.15 + (_revenuImpact / 1000000);
    final fiscalResult = FamilyService.calculateImpactFiscalEnfant(
      revenuImposable: _revenuImpact,
      tauxMarginal: tauxMarginal,
      nbEnfants: _nbEnfantsImpact,
      fraisGarde: _fraisGarde,
    );

    final allocResult = FamilyService.estimateAllocations(
      canton: _cantonAlloc,
      nbEnfants: _nbEnfantsImpact,
    );
    final allocAnnuel = allocResult['annuelTotal'] as double;

    final economieFiscale = fiscalResult['economieFiscale'] as double;
    final coutEstime = 1500.0 * _nbEnfantsImpact * 12;
    final fraisGardeAnnuel = _fraisGarde * 12 * _nbEnfantsImpact;
    final coutTotal = coutEstime + fraisGardeAnnuel;
    final netImpact = economieFiscale + allocAnnuel - coutTotal;

    // Career gap LPP projection
    final interruptionMois = _isMother ? 12 : 2;
    final lppPerteEstimee = _revenuImpact * 0.07 * interruptionMois / 12;

    final cantonNom = FamilyService.cantonNames[_cantonAlloc] ?? _cantonAlloc;
    final plural = _nbEnfantsImpact > 1 ? 's' : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        // Inputs
        MintSurface(
          tone: MintSurfaceTone.blanc,
          child: Column(
            children: [
              MintAmountField(
                label: S.of(context)!.naissanceRevenuAnnuel,
                value: _revenuImpact,
                formatValue: (v) => FamilyService.formatChf(v),
                onChanged: (v) {
                  setState(() {
                    _revenuImpact = v;
                  });
                },
                min: 30000,
                max: 200000,
              ),
              const SizedBox(height: MintSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      S.of(context)!.naissanceNbEnfants,
                      style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                    ),
                  ),
                  _buildStepper(
                    value: _nbEnfantsImpact,
                    minVal: 1,
                    maxVal: 5,
                    onChanged: (v) {
                      setState(() {
                        _nbEnfantsImpact = v;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: MintSpacing.lg),
              MintAmountField(
                label: S.of(context)!.naissanceFraisGarde,
                value: _fraisGarde,
                formatValue: (v) => FamilyService.formatChf(v),
                onChanged: (v) {
                  setState(() {
                    _fraisGarde = v;
                  });
                },
                min: 0,
                max: 3000,
              ),
            ],
          ),
        ),
        const SizedBox(height: MintSpacing.xl),

        // 1. Tax savings
        _buildImpactSection(
          icon: Icons.savings_outlined,
          title: S.of(context)!.naissanceTaxSavings,
          color: MintColors.success,
          children: [
            _buildResultRow(
              S.of(context)!.naissanceDeductionPerChild,
              '$_nbEnfantsImpact x ${FamilyService.formatChf(FamilyService.deductionParEnfant)}',
            ),
            const SizedBox(height: MintSpacing.xs + 2),
            _buildResultRow(
              S.of(context)!.naissanceDeductionChildcare,
              FamilyService.formatChf(
                  fiscalResult['deductionGarde'] as double),
            ),
            const SizedBox(height: MintSpacing.xs + 2),
            _buildResultRow(
              S.of(context)!.naissanceEstimatedTaxSaving,
              FamilyService.formatChf(economieFiscale),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),

        // 2. Allocations income
        _buildImpactSection(
          icon: Icons.child_care,
          title: S.of(context)!.naissanceAllowanceIncome,
          color: MintColors.success,
          children: [
            _buildResultRow(
              S.of(context)!.naissanceAnnualAllowances,
              FamilyService.formatChf(allocAnnuel),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              S.of(context)!.naissanceAllocContextNote(cantonNom, _nbEnfantsImpact, plural),
              style: MintTextStyles.labelMedium(color: MintColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),

        // 3. Career gap warning
        _buildImpactSection(
          icon: Icons.warning_amber_outlined,
          title: S.of(context)!.naissanceCareerImpact,
          color: MintColors.warning,
          children: [
            _buildResultRow(
              S.of(context)!.naissanceEstimatedInterruption,
              S.of(context)!.naissanceMonths(interruptionMois),
            ),
            const SizedBox(height: MintSpacing.xs + 2),
            _buildResultRow(
              S.of(context)!.naissanceLppLossEstimated,
              '-${FamilyService.formatChf(lppPerteEstimee)}',
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              S.of(context)!.naissanceLppLessContributions,
              style: MintTextStyles.labelMedium(color: MintColors.textMuted).copyWith(height: 1.4),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.lg),

        // Net impact
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(MintSpacing.lg),
          decoration: BoxDecoration(
            color: netImpact >= 0
                ? MintColors.success.withValues(alpha: 0.08)
                : MintColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: netImpact >= 0
                  ? MintColors.success.withValues(alpha: 0.3)
                  : MintColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                S.of(context)!.naissanceNetAnnualImpact,
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: MintSpacing.sm),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  '${netImpact >= 0 ? "+" : ""}${FamilyService.formatChf(netImpact)}',
                  key: ValueKey(netImpact),
                  style: MintTextStyles.displaySmall(
                    color: netImpact >= 0
                        ? MintColors.success
                        : MintColors.error,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                S.of(context)!.naissanceNetFormula,
                style: MintTextStyles.labelMedium(color: MintColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: MintSpacing.lg),

        // Waterfall — fiscal impact breakdown (child tax deductions)
        FiscalImpactWaterfall(
          steps: [
            WaterfallStep(
              label: S.of(context)!.naissanceWaterfallRevenu,
              amount: _revenuImpact,
              isTotal: true,
            ),
            WaterfallStep(
              label: S.of(context)!.naissanceTaxSavings,
              amount: economieFiscale,
            ),
            WaterfallStep(
              label: S.of(context)!.naissanceWaterfallAlloc,
              amount: allocAnnuel,
            ),
            WaterfallStep(
              label: S.of(context)!.naissanceWaterfallCosts,
              amount: -coutEstime,
            ),
            WaterfallStep(
              label: S.of(context)!.naissanceWaterfallChildcare,
              amount: -fraisGardeAnnuel,
            ),
            WaterfallStep(
              label: S.of(context)!.naissanceWaterfallAfter,
              amount: _revenuImpact + netImpact,
              isTotal: true,
            ),
          ],
          totalSavings: economieFiscale + allocAnnuel,
        ),
        const SizedBox(height: MintSpacing.lg),

        _buildEducationalInsert(
          S.of(context)!.naissanceChildCostEducational,
        ),
        const SizedBox(height: MintSpacing.lg),

        BudgetBebeWidget(
          monthlyIncome: _revenuImpact / 12,
          costPerChild: 1200,
        ),
        const SizedBox(height: MintSpacing.lg),

        // ── P9-A : Cout du bonheur — decomposition mensuelle ──
        BabyCostWidget(
          yearsOfDependency: 25,
          items: [
            BabyCostItem(
              label: S.of(context)!.naissanceBabyCostCreche,
              emoji: '\u{1F3EB}',
              monthlyCost: 1800,
              note: S.of(context)!.naissanceBabyCostCrecheNote,
            ),
            BabyCostItem(
              label: S.of(context)!.naissanceBabyCostAlimentation,
              emoji: '\u{1F37C}',
              monthlyCost: 250,
            ),
            BabyCostItem(
              label: S.of(context)!.naissanceBabyCostVetements,
              emoji: '\u{1F455}',
              monthlyCost: 150,
            ),
            BabyCostItem(
              label: S.of(context)!.naissanceBabyCostLamal,
              emoji: '\u{1F3E5}',
              monthlyCost: 120,
              note: S.of(context)!.naissanceBabyCostLamalNote,
            ),
            BabyCostItem(
              label: S.of(context)!.naissanceBabyCostActivites,
              emoji: '\u26BD',
              monthlyCost: 100,
            ),
            BabyCostItem(
              label: S.of(context)!.naissanceBabyCostDivers,
              emoji: '\u{1F381}',
              monthlyCost: 80,
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.lg),

        // ── P8-C : Clause 3a beneficiaire (OPP3 art. 2) ──
        Clause3aWidget(
          balance3a: _revenuImpact * 0.3, // DECISION: known approximation (~30% du revenu). Accurate 3a projection requires full profile data not available in birth-event context. Acceptable for educational illustration (OPP3).
          hasClause: false,
        ),
        const SizedBox(height: MintSpacing.lg),

        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildImpactSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: MintSpacing.sm + 2),
              Text(
                title,
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          ...children,
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 4: CHECKLIST — Essential steps for new parents
  // ════════════════════════════════════════════════════════════

  Widget _buildTab4Checklist() {
    final items = _buildNaissanceChecklistItems();
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
              const Icon(Icons.child_care,
                  color: MintColors.info, size: 20),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: Text(
                  S.of(context)!.naissanceChecklistIntro,
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
                    S.of(context)!.naissanceStepsCompleted(nbChecked, items.length),
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

  List<Map<String, String>> _buildNaissanceChecklistItems() {
    return [
      {'title': S.of(context)!.naissanceChecklistItem1Title, 'description': S.of(context)!.naissanceChecklistItem1Desc},
      {'title': S.of(context)!.naissanceChecklistItem2Title, 'description': S.of(context)!.naissanceChecklistItem2Desc},
      {'title': S.of(context)!.naissanceChecklistItem3Title, 'description': S.of(context)!.naissanceChecklistItem3Desc},
      {'title': S.of(context)!.naissanceChecklistItem4Title, 'description': S.of(context)!.naissanceChecklistItem4Desc},
      {'title': S.of(context)!.naissanceChecklistItem5Title, 'description': S.of(context)!.naissanceChecklistItem5Desc},
      {'title': S.of(context)!.naissanceChecklistItem6Title, 'description': S.of(context)!.naissanceChecklistItem6Desc},
      {'title': S.of(context)!.naissanceChecklistItem7Title, 'description': S.of(context)!.naissanceChecklistItem7Desc},
      {'title': S.of(context)!.naissanceChecklistItem8Title, 'description': S.of(context)!.naissanceChecklistItem8Desc},
      {'title': S.of(context)!.naissanceChecklistItem9Title, 'description': S.of(context)!.naissanceChecklistItem9Desc},
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
          label: S.of(context)!.naissanceNbEnfants,
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
            style: MintTextStyles.titleLarge(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          label: S.of(context)!.naissanceNbEnfants,
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

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        Text(
          value,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildBarComparison({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
  }) {
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            Text(
              FamilyService.formatChf(value),
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.xs + 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: MintColors.appleSurface,
            color: color,
            minHeight: 8,
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
                  S.of(context)!.naissanceDidYouKnow,
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
              S.of(context)!.naissanceDisclaimer,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
