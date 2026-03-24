import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/expat_service.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

// ────────────────────────────────────────────────────────────
//  FRONTALIER SCREEN — Sprint S23 / Expatriation + Frontaliers
// ────────────────────────────────────────────────────────────
//
// Three-tab interactive screen for cross-border workers:
//   Tab 1: "Impots"   — Source tax calculator (Bareme C)
//   Tab 2: "90 jours" — Home office 90-day rule gauge
//   Tab 3: "Charges"  — Social security comparison CH vs abroad
//
// Category C — Life Event (DESIGN_SYSTEM §2C).
// ────────────────────────────────────────────────────────────

class FrontalierScreen extends StatefulWidget {
  const FrontalierScreen({super.key});

  @override
  State<FrontalierScreen> createState() => _FrontalierScreenState();
}

class _FrontalierScreenState extends State<FrontalierScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: Impots inputs ──────────────────────────────
  String _taxCanton = 'GE';
  double _taxSalary = 7000;
  int _taxMaritalStatus = 0; // 0=Celibataire, 1=Marie(e)
  int _taxChildren = 0;
  Map<String, dynamic>? _taxResult;

  // ── Tab 2: 90 jours inputs ────────────────────────────
  int _bureauDays = 180;
  int _homeOfficeDays = 40;
  Map<String, dynamic>? _ruleResult;

  // ── Tab 3: Charges inputs ─────────────────────────────
  double _chargesSalary = 7000;
  String _chargesCountry = 'France';
  Map<String, dynamic>? _chargesResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
    });
    _recalculateTax();
    _recalculate90Day();
    _recalculateCharges();
  }

  void _initializeFromProfile() {
    try {
      final provider = context.read<CoachProfileProvider>();
      if (!provider.hasProfile) return;
      final profile = provider.profile!;
      setState(() {
        if (profile.canton.isNotEmpty) {
          _taxCanton = profile.canton;
        }
        if (profile.salaireBrutMensuel > 0) {
          _taxSalary = profile.salaireBrutMensuel;
          _chargesSalary = profile.salaireBrutMensuel;
        }
        if (profile.nombreEnfants > 0) {
          _taxChildren = profile.nombreEnfants;
        }
        if (profile.etatCivil == CoachCivilStatus.marie) {
          _taxMaritalStatus = 1;
        }
      });
      _recalculateTax();
      _recalculateCharges();
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _recalculateTax() {
    setState(() {
      _taxResult = ExpatService.calculateSourceTax(
        salary: _taxSalary,
        canton: _taxCanton,
        isMarried: _taxMaritalStatus == 1,
        children: _taxChildren,
      );
    });
  }

  void _recalculate90Day() {
    setState(() {
      _ruleResult = ExpatService.simulate90DayRule(
        homeOfficeDays: _homeOfficeDays,
        commuteDays: _bureauDays,
      );
    });
  }

  void _recalculateCharges() {
    setState(() {
      _chargesResult = ExpatService.compareSocialCharges(
        salary: _chargesSalary,
        residenceCountry: _chargesCountry,
      );
    });
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(context, innerBoxIsScrolled),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTab1Impots(),
            _buildTab290Jours(),
            _buildTab3Charges(),
          ],
        ),
      ),
    );
  }

  // ── App Bar with Tabs (white standard per DESIGN_SYSTEM §4.5) ──

  Widget _buildAppBar(BuildContext context, bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: Semantics(
        label: S.of(context)!.semanticsBackButton,
        button: true,
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      title: Text(
        S.of(context)!.frontalierAppBarTitle,
        style: MintTextStyles.headlineMedium(),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: MintColors.primary,
        indicatorWeight: 3,
        labelColor: MintColors.textPrimary,
        unselectedLabelColor: MintColors.textMuted,
        labelStyle: MintTextStyles.bodySmall(color: MintColors.textPrimary)
            .copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: MintTextStyles.bodySmall(),
        tabs: [
          Tab(text: S.of(context)!.frontalierTabImpots),
          Tab(text: S.of(context)!.frontalierTab90Jours),
          Tab(text: S.of(context)!.frontalierTabCharges),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: IMPOTS — Source Tax Calculator
  // ════════════════════════════════════════════════════════════

  Widget _buildTab1Impots() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        MintEntrance(child: _buildTaxInputsCard()),
        const SizedBox(height: MintSpacing.md + 4),
        if (_taxResult != null) ...[
          _buildTaxResultCard(),
          const SizedBox(height: MintSpacing.md + 4),
          if (_taxCanton == 'GE') _buildQuasiResidentBadge(),
          if (_taxCanton == 'GE') const SizedBox(height: MintSpacing.md + 4),
          if (_taxResult!['isTessin'] == true) _buildTessinNote(),
          if (_taxResult!['isTessin'] == true)
            const SizedBox(height: MintSpacing.md + 4),
        ],
        MintEntrance(delay: Duration(milliseconds: 100), child: _buildEducationalInsert(
          S.of(context)!.frontalierEducationalTax,
        )),
        const SizedBox(height: MintSpacing.md + 4),
        MintEntrance(delay: Duration(milliseconds: 200), child: _buildDisclaimer()),
      ],
    );
  }

  Widget _buildTaxInputsCard() {
    final sortedCodes = ExpatService.sortedCantonCodes;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Canton dropdown
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.frontalierCantonTravail,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary),
                ),
              ),
              Semantics(
                label: S.of(context)!.frontalierCantonTravail,
                button: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.sm + 4),
                  decoration: BoxDecoration(
                    color: MintColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _taxCanton,
                      style: MintTextStyles.bodyMedium(
                          color: MintColors.textPrimary),
                      items: sortedCodes.map((code) {
                        return DropdownMenuItem(
                          value: code,
                          child: Text(
                              '$code — ${ExpatService.cantonNames[code]}'),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          _taxCanton = v;
                          _recalculateTax();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md + 4),

          // Salary slider
          _buildSlider(
            label: S.of(context)!.frontalierSalaireBrut,
            value: _taxSalary,
            min: 3000,
            max: 25000,
            step: 500,
            onChanged: (v) {
              _taxSalary = v;
              _recalculateTax();
            },
          ),
          const SizedBox(height: MintSpacing.md + 4),

          // Marital status segmented button
          Text(
            S.of(context)!.frontalierEtatCivil,
            style:
                MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: S.of(context)!.frontalierCelibataire,
                  button: true,
                  selected: _taxMaritalStatus == 0,
                  child: GestureDetector(
                    onTap: () {
                      _taxMaritalStatus = 0;
                      _recalculateTax();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          vertical: MintSpacing.sm + 4),
                      decoration: BoxDecoration(
                        color: _taxMaritalStatus == 0
                            ? MintColors.primary
                            : MintColors.surface,
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(12)),
                        border: Border.all(
                          color: _taxMaritalStatus == 0
                              ? MintColors.primary
                              : MintColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          S.of(context)!.frontalierCelibataire,
                          style: MintTextStyles.bodySmall(
                            color: _taxMaritalStatus == 0
                                ? MintColors.white
                                : MintColors.textSecondary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  label: S.of(context)!.frontalierMarie,
                  button: true,
                  selected: _taxMaritalStatus == 1,
                  child: GestureDetector(
                    onTap: () {
                      _taxMaritalStatus = 1;
                      _recalculateTax();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          vertical: MintSpacing.sm + 4),
                      decoration: BoxDecoration(
                        color: _taxMaritalStatus == 1
                            ? MintColors.primary
                            : MintColors.surface,
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(12)),
                        border: Border.all(
                          color: _taxMaritalStatus == 1
                              ? MintColors.primary
                              : MintColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          S.of(context)!.frontalierMarie,
                          style: MintTextStyles.bodySmall(
                            color: _taxMaritalStatus == 1
                                ? MintColors.white
                                : MintColors.textSecondary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md + 4),

          // Children stepper
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.frontalierEnfantsCharge,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary),
                ),
              ),
              _buildStepper(
                value: _taxChildren,
                minVal: 0,
                maxVal: 5,
                onChanged: (v) {
                  _taxChildren = v;
                  _recalculateTax();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxResultCard() {
    final result = _taxResult!;
    final isTessin = result['isTessin'] as bool;
    if (isTessin) return const SizedBox.shrink();

    final monthlyTax = result['monthlyTax'] as double;
    final effectiveRate = result['effectiveRate'] as double;
    final annualTax = result['annualTax'] as double;
    final cantonNom = result['cantonNom'] as String;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  '${S.of(context)!.frontalierTabImpots} — $cantonNom'
                      .toUpperCase(),
                  style: MintTextStyles.labelSmall(),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md + 4),

          // Monthly tax hero
          Center(
            child: Column(
              children: [
                Text(
                  ExpatService.formatChf(monthlyTax),
                  style: MintTextStyles.displayMedium(),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  S.of(context)!.frontalierParMois,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.md + 4),

          // Effective rate progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.frontalierTauxEffectif,
                style: MintTextStyles.bodySmall(
                    color: MintColors.textSecondary),
              ),
              Text(
                ExpatService.formatPercent(effectiveRate * 100),
                style: MintTextStyles.bodyMedium(color: MintColors.primary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: min(1.0, effectiveRate / 0.20),
              backgroundColor: MintColors.border.withValues(alpha: 0.3),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(MintColors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: MintSpacing.md),

          // Annual total
          Container(
            padding: const EdgeInsets.all(MintSpacing.md),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context)!.frontalierTotalAnnuel,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondary),
                ),
                Text(
                  ExpatService.formatChf(annualTax),
                  style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuasiResidentBadge() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.gavel, size: 18, color: MintColors.info),
          ),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.frontalierQuasiResidentTitle,
                  style: MintTextStyles.bodyMedium(color: MintColors.info)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  S.of(context)!.frontalierQuasiResidentDesc,
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTessinNote() {
    final note = _taxResult!['note'] as String;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber,
              size: 20, color: MintColors.warning),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.frontalierTessinTitle,
                  style: MintTextStyles.bodyMedium(color: MintColors.warning)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  note,
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: 90 JOURS — Home Office Rule
  // ════════════════════════════════════════════════════════════

  Widget _buildTab290Jours() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        MintEntrance(child: _build90DayInputCard()),
        const SizedBox(height: MintSpacing.md + 4),
        if (_ruleResult != null) ...[
          _build90DayGauge(),
          const SizedBox(height: MintSpacing.md + 4),
          _build90DayRecommendation(),
          const SizedBox(height: MintSpacing.md + 4),
          _build90DayLegalRef(),
          const SizedBox(height: MintSpacing.md + 4),
        ],
        MintEntrance(delay: Duration(milliseconds: 100), child: _buildEducationalInsert(
          S.of(context)!.frontalierEducational90Days,
        )),
        const SizedBox(height: MintSpacing.md + 4),
        MintEntrance(delay: Duration(milliseconds: 200), child: _buildDisclaimer()),
      ],
    );
  }

  Widget _build90DayInputCard() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSlider(
            label: S.of(context)!.frontalierJoursBureau,
            value: _bureauDays.toDouble(),
            min: 0,
            max: 250,
            step: 5,
            onChanged: (v) {
              _bureauDays = v.round();
              _recalculate90Day();
            },
            formatAsInt: true,
            suffix: S.of(context)!.frontalierJoursSuffix,
          ),
          const SizedBox(height: MintSpacing.md + 4),
          _buildSlider(
            label: S.of(context)!.frontalierJoursHomeOffice,
            value: _homeOfficeDays.toDouble(),
            min: 0,
            max: 250,
            step: 5,
            onChanged: (v) {
              _homeOfficeDays = v.round();
              _recalculate90Day();
            },
            formatAsInt: true,
            suffix: S.of(context)!.frontalierJoursSuffix,
          ),
        ],
      ),
    );
  }

  Widget _build90DayGauge() {
    final result = _ruleResult!;
    final riskDays = result['riskDays'] as int;
    final riskLevel = result['riskLevel'] as String;
    final daysRemaining = result['daysRemaining'] as int;

    Color gaugeColor;
    String statusLabel;
    IconData statusIcon;

    switch (riskLevel) {
      case 'low':
        gaugeColor = MintColors.success;
        statusLabel = S.of(context)!.frontalierRiskLow;
        statusIcon = Icons.check_circle;
        break;
      case 'medium':
        gaugeColor = MintColors.warning;
        statusLabel = S.of(context)!.frontalierRiskMedium;
        statusIcon = Icons.warning_amber;
        break;
      case 'high':
      default:
        gaugeColor = MintColors.error;
        statusLabel = S.of(context)!.frontalierRiskHigh;
        statusIcon = Icons.dangerous;
        break;
    }

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.speed, size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.frontalierJaugeRisque,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md + 4),

          // Big number
          Text(
            '$riskDays',
            style: MintTextStyles.displayLarge(color: gaugeColor),
          ),
          Text(
            S.of(context)!.frontalierJoursHomeOfficeLabel,
            style: MintTextStyles.bodyMedium(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md + 4),

          // Multi-color gauge bar
          _buildMultiColorGauge(riskDays),
          const SizedBox(height: MintSpacing.sm + 4),

          // Scale labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: MintTextStyles.labelSmall()),
              Text('70', style: MintTextStyles.labelSmall()),
              Text('90',
                  style: MintTextStyles.labelSmall(color: MintColors.error)
                      .copyWith(fontWeight: FontWeight.w700)),
              Text('120', style: MintTextStyles.labelSmall()),
            ],
          ),
          const SizedBox(height: MintSpacing.md + 4),

          // Status badge
          Semantics(
            label: statusLabel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.md + 4,
                  vertical: MintSpacing.sm + 4),
              decoration: BoxDecoration(
                color: gaugeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: gaugeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(statusIcon, size: 20, color: gaugeColor),
                  const SizedBox(width: MintSpacing.sm),
                  Flexible(
                    child: Text(
                      statusLabel,
                      style: MintTextStyles.bodyMedium(color: gaugeColor)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (riskLevel != 'high') ...[
            const SizedBox(height: MintSpacing.sm + 4),
            Text(
              S.of(context)!.frontalierDaysRemaining(daysRemaining),
              style:
                  MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiColorGauge(int riskDays) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final greenWidth = totalWidth * (70 / 120);
        final orangeWidth = totalWidth * (20 / 120);
        final redWidth = totalWidth * (30 / 120);

        final indicatorPos = min(1.0, riskDays / 120.0) * totalWidth;

        return SizedBox(
          height: 24,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  Container(
                    width: greenWidth,
                    height: 8,
                    decoration: BoxDecoration(
                      color: MintColors.success.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(4)),
                    ),
                  ),
                  Container(
                    width: orangeWidth,
                    height: 8,
                    color: MintColors.warning.withValues(alpha: 0.3),
                  ),
                  Container(
                    width: redWidth,
                    height: 8,
                    decoration: BoxDecoration(
                      color: MintColors.error.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(4)),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: min(indicatorPos, greenWidth),
                    height: 8,
                    decoration: BoxDecoration(
                      color: MintColors.success,
                      borderRadius: indicatorPos <= greenWidth
                          ? BorderRadius.circular(4)
                          : const BorderRadius.horizontal(
                              left: Radius.circular(4)),
                    ),
                  ),
                  if (indicatorPos > greenWidth)
                    Container(
                      width: min(indicatorPos - greenWidth, orangeWidth),
                      height: 8,
                      color: MintColors.warning,
                    ),
                  if (indicatorPos > greenWidth + orangeWidth)
                    Container(
                      width: min(
                          indicatorPos - greenWidth - orangeWidth, redWidth),
                      height: 8,
                      decoration: const BoxDecoration(
                        color: MintColors.error,
                        borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(4)),
                      ),
                    ),
                ],
              ),
              Positioned(
                left: indicatorPos - 6,
                top: 10,
                child: CustomPaint(
                  size: const Size(12, 10),
                  painter: _TrianglePainter(
                    color: riskDays < 70
                        ? MintColors.success
                        : riskDays < 90
                            ? MintColors.warning
                            : MintColors.error,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _build90DayRecommendation() {
    final result = _ruleResult!;
    final recommendation = result['recommendation'] as String;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.frontalierRecommandation,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            recommendation,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _build90DayLegalRef() {
    final result = _ruleResult!;
    final legalRef = result['legalReference'] as String;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.sm + 4),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.menu_book, size: 16, color: MintColors.textMuted),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              legalRef,
              style: MintTextStyles.labelSmall(),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: CHARGES — Social Security Comparison
  // ════════════════════════════════════════════════════════════

  Widget _buildTab3Charges() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.lg, MintSpacing.lg, 100),
      children: [
        MintEntrance(child: _buildChargesInputCard()),
        const SizedBox(height: MintSpacing.md + 4),
        if (_chargesResult != null) ...[
          _buildChargesComparison(),
          const SizedBox(height: MintSpacing.md + 4),
          _buildChargesDifferenceBadge(),
          const SizedBox(height: MintSpacing.md + 4),
          _buildLamalSection(),
          const SizedBox(height: MintSpacing.md + 4),
        ],
        MintEntrance(delay: Duration(milliseconds: 100), child: _buildEducationalInsert(
          S.of(context)!.frontalierEducationalCharges,
        )),
        const SizedBox(height: MintSpacing.md + 4),
        MintEntrance(delay: Duration(milliseconds: 200), child: _buildDisclaimer()),
      ],
    );
  }

  Widget _buildChargesInputCard() {
    final countries = ExpatService.countryLabels.keys.toList();

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSlider(
            label: S.of(context)!.frontalierSalaireBrut,
            value: _chargesSalary,
            min: 3000,
            max: 25000,
            step: 500,
            onChanged: (v) {
              _chargesSalary = v;
              _recalculateCharges();
            },
          ),
          const SizedBox(height: MintSpacing.md + 4),

          Text(
            S.of(context)!.frontalierPaysResidence,
            style:
                MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: countries.map((country) {
                final isSelected = _chargesCountry == country;
                return Padding(
                  padding: const EdgeInsets.only(right: MintSpacing.sm),
                  child: Semantics(
                    label: country,
                    button: true,
                    selected: isSelected,
                    child: GestureDetector(
                      onTap: () {
                        _chargesCountry = country;
                        _recalculateCharges();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: MintSpacing.md,
                            vertical: MintSpacing.sm + 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? MintColors.primary
                              : MintColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? MintColors.primary
                                : MintColors.border,
                          ),
                        ),
                        child: Text(
                          country,
                          style: MintTextStyles.bodySmall(
                            color: isSelected
                                ? MintColors.white
                                : MintColors.textSecondary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargesComparison() {
    final result = _chargesResult!;
    final ch = result['ch'] as Map<String, dynamic>;
    final foreign = result['foreign'] as Map<String, dynamic>;
    final country = result['residenceCountry'] as String;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: MintSurface(
            tone: MintSurfaceTone.blanc,
            padding: const EdgeInsets.all(MintSpacing.md),
            radius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.frontalierChargesCh,
                  style: MintTextStyles.bodySmall(
                          color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.sm + 4),
                _buildChargeRow('AVS/AI/APG', ch['avs_ai_apg'] as double),
                _buildChargeRow('AC', ch['ac'] as double),
                _buildChargeRow('LPP (est.)', ch['lpp'] as double),
                const Divider(height: MintSpacing.md),
                _buildChargeRow(S.of(context)!.frontalierChargesTotal,
                    ch['total'] as double,
                    bold: true),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  S.of(context)!.frontalierDuSalaire(
                      ((ch['totalRate'] as double) * 100)
                          .toStringAsFixed(1)),
                  style: MintTextStyles.labelSmall(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: MintSpacing.sm + 4),
        Expanded(
          child: MintSurface(
            tone: MintSurfaceTone.blanc,
            padding: const EdgeInsets.all(MintSpacing.md),
            radius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.frontalierChargesCountry(country),
                  style: MintTextStyles.bodySmall(
                          color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.sm + 4),
                ..._buildForeignChargeRows(foreign),
                const Divider(height: MintSpacing.md),
                _buildChargeRow(S.of(context)!.frontalierChargesTotal,
                    foreign['total'] as double,
                    bold: true),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  S.of(context)!.frontalierDuSalaire(
                      ((foreign['totalRate'] as double) * 100)
                          .toStringAsFixed(1)),
                  style: MintTextStyles.labelSmall(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildForeignChargeRows(Map<String, dynamic> foreign) {
    final details = foreign['details'] as Map<String, dynamic>;
    final annualSalary = _chargesSalary * 12;
    final entries =
        details.entries.where((e) => e.key != 'total').toList();

    return entries.map((e) {
      final label = e.key
          .replaceAll('_', ' ')
          .replaceFirst(e.key[0], e.key[0].toUpperCase());
      final amount = annualSalary * (e.value as double);
      return _buildChargeRow(label, amount);
    }).toList();
  }

  Widget _buildChargeRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.xs + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: bold
                  ? MintTextStyles.bodySmall(color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700)
                  : MintTextStyles.labelSmall(
                      color: MintColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: MintSpacing.xs),
          Text(
            ExpatService.formatChf(value),
            style: bold
                ? MintTextStyles.bodySmall(color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700)
                : MintTextStyles.labelSmall(color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildChargesDifferenceBadge() {
    final result = _chargesResult!;
    final difference = result['difference'] as double;
    final chLessCostly = result['chLessCostly'] as bool;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.md + 4, vertical: MintSpacing.sm + 6),
      decoration: BoxDecoration(
        color: chLessCostly
            ? MintColors.success.withValues(alpha: 0.06)
            : MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: chLessCostly
              ? MintColors.success.withValues(alpha: 0.15)
              : MintColors.warning.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            chLessCostly ? Icons.trending_down : Icons.trending_up,
            size: 20,
            color: chLessCostly ? MintColors.success : MintColors.warning,
          ),
          const SizedBox(width: MintSpacing.sm),
          Flexible(
            child: Text(
              chLessCostly
                  ? S.of(context)!.frontalierChargesChMoins(
                      ExpatService.formatChf(difference.abs()))
                  : S.of(context)!.frontalierChargesChPlus(
                      ExpatService.formatChf(difference.abs())),
              style: MintTextStyles.bodyMedium(
                color:
                    chLessCostly ? MintColors.success : MintColors.warning,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLamalSection() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_hospital,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.frontalierAssuranceMaladie,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          _buildLamalOptionRow(
            S.of(context)!.frontalierLamalTitle,
            S.of(context)!.frontalierLamalDesc,
            Icons.shield_outlined,
          ),
          const SizedBox(height: MintSpacing.sm + 2),
          _buildLamalOptionRow(
            S.of(context)!.frontalierCmuTitle,
            S.of(context)!.frontalierCmuDesc,
            Icons.health_and_safety_outlined,
          ),
          const SizedBox(height: MintSpacing.sm + 2),
          _buildLamalOptionRow(
            S.of(context)!.frontalierAssurancePriveeTitle,
            S.of(context)!.frontalierAssurancePriveeDesc,
            Icons.security_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildLamalOptionRow(String title, String desc, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(MintSpacing.sm),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: MintColors.textSecondary),
        ),
        const SizedBox(width: MintSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: MintTextStyles.bodySmall(
                        color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: MintTextStyles.labelSmall(
                    color: MintColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required ValueChanged<double> onChanged,
    bool formatAsInt = false,
    String? suffix,
  }) {
    final divisions = ((max - min) / step).round();

    String displayValue;
    if (formatAsInt) {
      displayValue = '${value.round()}${suffix != null ? ' $suffix' : ''}';
    } else {
      displayValue = ExpatService.formatChf(value);
    }

    return MintPremiumSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions > 0 ? divisions : 1,
      formatValue: (_) => displayValue,
      onChanged: (v) {
        setState(() {
          onChanged((v / step).round() * step);
        });
      },
    );
  }

  Widget _buildStepper({
    required int value,
    required int minVal,
    required int maxVal,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Semantics(
          label: S.of(context)!.semanticsDecrement,
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
          width: 32,
          child: Text(
            '$value',
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        Semantics(
          label: S.of(context)!.semanticsIncrement,
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
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(MintSpacing.xs + 2),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lightbulb_outline,
                size: 18, color: MintColors.info),
          ),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.frontalierLeSavaisTu,
                  style: MintTextStyles.bodySmall(color: MintColors.info)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  text,
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.frontalierDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Triangle Painter for gauge indicator ─────────────────────

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
