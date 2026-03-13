import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/widgets/coach/crash_test_budget_widget.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/unemployment_service.dart';
import 'package:mint_mobile/utils/profile_auto_fill_mixin.dart';
import 'package:mint_mobile/widgets/educational/unemployment_timeline_widget.dart';
import 'package:mint_mobile/widgets/coach/unemployment_counter_widget.dart';

// ────────────────────────────────────────────────────────────
//  UNEMPLOYMENT SCREEN — Sprint S19 / Chomage (LACI)
// ────────────────────────────────────────────────────────────
//
// Interactive LACI benefits calculator.
// Inputs: gain assure mensuel, age, months of contribution,
//         children toggle, disability toggle.
// Outputs: taux, indemnite, duration, timeline, checklist.
// ────────────────────────────────────────────────────────────

class UnemploymentScreen extends StatefulWidget {
  const UnemploymentScreen({super.key});

  @override
  State<UnemploymentScreen> createState() => _UnemploymentScreenState();
}

class _UnemploymentScreenState extends State<UnemploymentScreen>
    with ProfileAutoFillMixin {
  double _gainAssure = 6000;
  int _age = 35;
  int _moisCotisation = 18;
  bool _hasChildren = false;
  bool _hasDisability = false;
  UnemploymentResult? _result;

  // Checklist tracking
  final Set<int> _checkedItems = {};

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    autoFillFromProfile(context, (p) {
      final salaireMensuel = p.revenuBrutAnnuel > 0
          ? (p.revenuBrutAnnuel / 12).clamp(1500.0, 12646.0)
          : 6000.0;
      final age = p.age > 0 ? p.age.clamp(18, 65) : 35;
      setState(() {
        _gainAssure = salaireMensuel.roundToDouble();
        _age = age;
      });
      _calculate();
    });
  }

  void _calculate() {
    setState(() {
      _result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: _gainAssure,
        age: _age,
        moisCotisation: _moisCotisation,
        hasChildren: _hasChildren,
        hasDisability: _hasDisability,
      );
    });
  }

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
                _buildGainSlider(),
                const SizedBox(height: 20),
                _buildAgeSlider(),
                const SizedBox(height: 20),
                _buildMoisCotisationSlider(),
                const SizedBox(height: 20),
                _buildToggles(),
                const SizedBox(height: 24),
                if (_result != null) ...[
                  if (!_result!.eligible) ...[
                    _buildNotEligible(),
                    const SizedBox(height: 24),
                  ] else ...[
                    _buildChiffreChoc(),
                    const SizedBox(height: 24),
                    _buildTauxCard(),
                    const SizedBox(height: 24),
                    _buildResultCards(),
                    const SizedBox(height: 24),
                    _buildDurationCard(),
                    const SizedBox(height: 24),
                    UnemploymentCounterWidget(
                      age: _age,
                      monthlyBenefit: _result!.indemniteMensuelle,
                    ),
                    const SizedBox(height: 24),
                    _buildTroisVagues(),
                    const SizedBox(height: 24),
                  ],
                  UnemploymentTimelineWidget(items: _result!.timeline),
                  const SizedBox(height: 24),
                  _buildChecklist(),
                  const SizedBox(height: 24),
                  _buildEducation(),
                  const SizedBox(height: 24),
                  _buildMintCrashTestSection(),
                  const SizedBox(height: 24),
                ],
                _buildDisclaimer(),
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
      expandedHeight: 120,
      backgroundColor: MintColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
        title: Text(
          S.of(context)!.unemploymentTitle,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: MintColors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MintColors.primary,
                MintColors.primary.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
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
          const Icon(Icons.shield_outlined, color: MintColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.unemploymentHeaderDesc,
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

  // ── Sliders ────────────────────────────────────────────────

  Widget _buildGainSlider() {
    return _buildSliderCard(
      title: S.of(context)!.unemploymentGainSliderTitle,
      valueLabel: UnemploymentService.formatChf(_gainAssure),
      minLabel: 'CHF 0',
      maxLabel: "CHF 12'350",
      value: _gainAssure,
      min: 0,
      max: 12350,
      divisions: 247,
      onChanged: (v) {
        _gainAssure = v;
        _calculate();
      },
    );
  }

  Widget _buildAgeSlider() {
    return _buildSliderCard(
      title: S.of(context)!.unemploymentAgeSliderTitle,
      valueLabel: S.of(context)!.unemploymentAgeValue(_age),
      minLabel: S.of(context)!.unemploymentAgeMin,
      maxLabel: S.of(context)!.unemploymentAgeMax,
      value: _age.toDouble(),
      min: 18,
      max: 65,
      divisions: 47,
      onChanged: (v) {
        _age = v.toInt();
        _calculate();
      },
    );
  }

  Widget _buildMoisCotisationSlider() {
    return _buildSliderCard(
      title: S.of(context)!.unemploymentContribTitle,
      valueLabel: S.of(context)!.unemploymentContribValue(_moisCotisation),
      minLabel: '0',
      maxLabel: S.of(context)!.unemploymentContribMax,
      value: _moisCotisation.toDouble(),
      min: 0,
      max: 24,
      divisions: 24,
      onChanged: (v) {
        _moisCotisation = v.toInt();
        _calculate();
      },
    );
  }

  Widget _buildSliderCard({
    required String title,
    required String valueLabel,
    required String minLabel,
    required String maxLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
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
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
              Text(maxLabel,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Toggles ────────────────────────────────────────────────

  Widget _buildToggles() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.unemploymentSituationTitle,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.unemploymentSituationSubtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _buildToggleRow(
            icon: Icons.child_care,
            label: S.of(context)!.unemploymentChildrenToggle,
            value: _hasChildren,
            onChanged: (v) {
              _hasChildren = v;
              _calculate();
            },
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            icon: Icons.accessible,
            label: S.of(context)!.unemploymentDisabilityToggle,
            value: _hasDisability,
            onChanged: (v) {
              _hasDisability = v;
              _calculate();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: MintColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: MintColors.primary,
        ),
      ],
    );
  }

  // ── Not Eligible ───────────────────────────────────────────

  Widget _buildNotEligible() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: MintColors.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.unemploymentNotEligible,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _result!.raisonNonEligible ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Chiffre Choc ───────────────────────────────────────────

  Widget _buildChiffreChoc() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.error,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            UnemploymentService.formatChf(r.perteMensuelle),
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: MintColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            r.chiffreChoc,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Taux Card ──────────────────────────────────────────────

  Widget _buildTauxCard() {
    final r = _result!;
    final tauxPct = (r.tauxIndemnite * 100).toStringAsFixed(0);
    final isEnhanced = r.tauxIndemnite == 0.80;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isEnhanced
                  ? MintColors.success.withValues(alpha: 0.1)
                  : MintColors.info.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$tauxPct%',
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isEnhanced ? MintColors.success : MintColors.info,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.unemploymentCompensationRate,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEnhanced
                      ? S.of(context)!.unemploymentRateEnhanced
                      : S.of(context)!.unemploymentRateStandard,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Result Cards ───────────────────────────────────────────

  Widget _buildResultCards() {
    final r = _result!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.unemploymentDailyBenefit,
                UnemploymentService.formatChf(r.indemniteJournaliere),
                Icons.today_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.unemploymentMonthlyBenefit,
                UnemploymentService.formatChf(r.indemniteMensuelle),
                Icons.calendar_month_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.unemploymentInsuredEarnings,
                UnemploymentService.formatChf(r.gainAssureRetenu),
                Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.unemploymentWaitingPeriod,
                S.of(context)!.unemploymentWaitingDays(r.delaiCarenceJours),
                Icons.hourglass_empty,
                small: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon,
      {bool small = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: MintColors.textMuted),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: small ? 14 : 18,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Duration Card ──────────────────────────────────────────

  Widget _buildDurationCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.unemploymentDurationHeader,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.nombreIndemnites}',
                      style: GoogleFonts.montserrat(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: MintColors.primary,
                      ),
                    ),
                    Text(
                      S.of(context)!.unemploymentDailyBenefits,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: MintColors.lightBorder,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '~${r.dureeMois.toStringAsFixed(0)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: MintColors.primary,
                      ),
                    ),
                    Text(
                      S.of(context)!.unemploymentCoverageMonths,
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
          const SizedBox(height: 16),
          _buildDurationTable(),
        ],
      ),
    );
  }

  Widget _buildDurationTable() {
    // Source : LACI art. 27 al. 2 — durées maximales d'indemnités
    // Miroir de social_insurance.dart (acJoursMinCotisation, acJoursStandard, acJoursSenior)
    final brackets = [
      ('12–17 mois cotis.', '200 indemnités', _moisCotisation >= 12 && _moisCotisation < 18),
      ('18–21 mois cotis.', '260 indemnités', _moisCotisation >= 18 && _moisCotisation < 22),
      ('>= 22 mois, < $acAgeSeuillSenior ans', '400 indemnités', _moisCotisation >= 22 && _age < acAgeSeuillSenior),
      ('>= 22 mois, >= $acAgeSeuillSenior ans', '520 indemnités', _moisCotisation >= 22 && _age >= acAgeSeuillSenior),
    ];

    return Column(
      children: brackets.map((b) {
        final isCurrent = b.$3;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent
                ? MintColors.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isCurrent
                ? Border.all(
                    color: MintColors.primary.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isCurrent)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: MintColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        S.of(context)!.unemploymentYouTag,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: MintColors.white,
                        ),
                      ),
                    ),
                  Text(
                    b.$1,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.w400,
                      color: isCurrent
                          ? MintColors.textPrimary
                          : MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                b.$2,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isCurrent
                      ? MintColors.primary
                      : MintColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Checklist ──────────────────────────────────────────────

  Widget _buildChecklist() {
    final l10n = S.of(context)!;
    final items = [
      l10n.unemploymentCheckItem1,
      l10n.unemploymentCheckItem2,
      l10n.unemploymentCheckItem3,
      l10n.unemploymentCheckItem4,
      l10n.unemploymentCheckItem5,
      l10n.unemploymentCheckItem6,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.unemploymentChecklistHeader,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(items.length, (index) {
            final checked = _checkedItems.contains(index);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (checked) {
                    _checkedItems.remove(index);
                  } else {
                    _checkedItems.add(index);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: checked
                            ? MintColors.success
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: checked
                              ? MintColors.success
                              : MintColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: checked
                          ? const Icon(Icons.check,
                              size: 14, color: MintColors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        items[index],
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: checked
                              ? MintColors.textMuted
                              : MintColors.textPrimary,
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Education ──────────────────────────────────────────────

  Widget _buildEducation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.unemploymentGoodToKnow,
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
        _buildEduCard(
          Icons.timer_outlined,
          S.of(context)!.unemploymentEduFastTitle,
          S.of(context)!.unemploymentEduFastBody,
        ),
        _buildEduCard(
          Icons.savings_outlined,
          S.of(context)!.unemploymentEdu3aTitle,
          S.of(context)!.unemploymentEdu3aBody,
        ),
        _buildEduCard(
          Icons.account_balance_outlined,
          S.of(context)!.unemploymentEduLppTitle,
          S.of(context)!.unemploymentEduLppBody,
        ),
        _buildEduCard(
          Icons.health_and_safety_outlined,
          S.of(context)!.unemploymentEduLamalTitle,
          S.of(context)!.unemploymentEduLamalBody,
        ),
      ],
    );
  }

  Widget _buildEduCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.appleSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MintColors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: MintColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── P7-A : Les 3 vagues — Ton tsunami financier ────────────

  static const _vagues = [
    (
      emoji: '🌊',
      label: 'Vague 1 · L\'urgence administrative',
      color: MintColors.info,
      text: 'Inscription ORP dans les 5 premiers jours. Sinon : perte d\'indemnités. '
          'Chaque jour de retard = indemnité perdue.',
    ),
    (
      emoji: '🌊',
      label: 'Vague 2 · La chute de revenus',
      color: MintColors.scoreAttention,
      text: 'Chute immédiate de CHF/mois. L\'AC ne couvre ni les jours fériés '
          'ni le délai de carence (5–20 jours). Revise ton budget dès J+1.',
    ),
    (
      emoji: '🌊',
      label: 'Vague 3 · Les décisions cachées',
      color: MintColors.scoreCritique,
      text: 'Dans les 30 jours : transférer ton LPP (sinon institution supplétive). '
          'Avant le mois suivant : suspendre le 3a, revoir LAMal. '
          '"La vague la plus dangereuse, c\'est celle que tu n\'as pas vue venir."',
    ),
  ];

  Widget _buildTroisVagues() {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Text('🌊', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.of(context)!.unemploymentTsunamiTitle,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._vagues.map(
            (v) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 56,
                    decoration: BoxDecoration(
                      color: v.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: v.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          v.text,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: MintColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── MINT Coach Widget: Crash Test Budget ───────────────────

  Widget _buildMintCrashTestSection() {
    final survivalIncome = _gainAssure * 0.70; // taux LACI standard

    // Derive budget lines proportionally from gainAssure
    final loyer = (_gainAssure * 0.30).roundToDouble(); // ~30% du revenu
    final lamal = (_gainAssure * 0.075).roundToDouble(); // ~7.5%
    final transport = (_gainAssure * 0.033).roundToDouble(); // ~3.3%
    final loisirs = (_gainAssure * 0.067).roundToDouble(); // ~6.7%
    final epargne3a = (pilier3aPlafondAvecLpp / 12).roundToDouble(); // plafond mensuel

    return CrashTestBudgetWidget(
      monthlyIncome: _gainAssure,
      survivalIncome: survivalIncome,
      lines: [
        BudgetLine(
          label: 'Loyer',
          emoji: '🏠',
          normalAmount: loyer,
          survivalAmount: loyer, // incompressible
          status: BudgetLineStatus.locked,
        ),
        BudgetLine(
          label: 'LAMal',
          emoji: '🏥',
          normalAmount: lamal,
          survivalAmount: lamal, // incompressible
          status: BudgetLineStatus.locked,
        ),
        BudgetLine(
          label: 'Transport',
          emoji: '🚌',
          normalAmount: transport,
          survivalAmount: (transport * 0.50).roundToDouble(),
          status: BudgetLineStatus.cut,
        ),
        BudgetLine(
          label: 'Loisirs',
          emoji: '🎭',
          normalAmount: loisirs,
          survivalAmount: (loisirs * 0.125).roundToDouble(),
          status: BudgetLineStatus.cut,
        ),
        BudgetLine(
          label: 'Épargne 3a',
          emoji: '🏦',
          normalAmount: epargne3a,
          survivalAmount: 0,
          status: BudgetLineStatus.paused,
        ),
      ],
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.scoreAttention.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.scoreAttention.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: MintColors.scoreAttention, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.unemploymentDisclaimer,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.scoreAttention,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
