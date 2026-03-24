import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/widgets/coach/crash_test_budget_widget.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/unemployment_service.dart';
import 'package:mint_mobile/utils/profile_auto_fill_mixin.dart';
import 'package:mint_mobile/widgets/educational/unemployment_timeline_widget.dart';
import 'package:mint_mobile/widgets/coach/unemployment_counter_widget.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

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
        if (p.nombreEnfants > 0) {
          _hasChildren = true;
        }
        final annees = p.prevoyance.anneesContribuees;
        if (annees != null && annees > 0) {
          _moisCotisation = (annees * 12).clamp(0, 480);
        }
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
      appBar: AppBar(
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        foregroundColor: MintColors.textPrimary,
        leading: Semantics(
          label: S.of(context)!.semanticsBackButton,
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          S.of(context)!.unemploymentTitle,
          style: MintTextStyles.headlineMedium(color: MintColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg, MintSpacing.md, MintSpacing.lg, MintSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero: chute de revenu (shown when eligible)
            if (_result != null && _result!.eligible) ...[
              _buildChiffreChoc(),
              const SizedBox(height: MintSpacing.xl),
            ] else if (_result != null && !_result!.eligible) ...[
              _buildNotEligible(),
              const SizedBox(height: MintSpacing.xl),
            ] else ...[
              _buildHeader(),
              const SizedBox(height: MintSpacing.xl),
            ],
            MintEntrance(child: _buildGainSlider()),
            const SizedBox(height: MintSpacing.md),
            MintEntrance(delay: const Duration(milliseconds: 100), child: _buildAgeSlider()),
            const SizedBox(height: MintSpacing.md),
            MintEntrance(delay: const Duration(milliseconds: 200), child: _buildMoisCotisationSlider()),
            const SizedBox(height: MintSpacing.md),
            MintEntrance(delay: const Duration(milliseconds: 300), child: _buildToggles()),
            const SizedBox(height: MintSpacing.xl),
            if (_result != null && _result!.eligible) ...[
              _buildTauxCard(),
              const SizedBox(height: MintSpacing.xl),
              _buildResultCards(),
              const SizedBox(height: MintSpacing.xl),
              _buildDurationCard(),
              const SizedBox(height: MintSpacing.xl),
              UnemploymentCounterWidget(
                age: _age,
                monthlyBenefit: _result!.indemniteMensuelle,
              ),
              const SizedBox(height: MintSpacing.xl),
              _buildTroisVagues(),
              const SizedBox(height: MintSpacing.xl),
            ],
            if (_result != null) ...[
              UnemploymentTimelineWidget(items: _result!.timeline),
              const SizedBox(height: MintSpacing.xl),
              _buildChecklist(),
              const SizedBox(height: MintSpacing.xl),
              _buildEducation(),
              const SizedBox(height: MintSpacing.xl),
              _buildMintCrashTestSection(),
              const SizedBox(height: MintSpacing.xl),
            ],
            MintEntrance(delay: const Duration(milliseconds: 400), child: _buildDisclaimer()),
            const SizedBox(height: MintSpacing.xxl + MintSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Semantics(
      header: true,
      child: MintSurface(
        tone: MintSurfaceTone.bleu,
        padding: const EdgeInsets.all(MintSpacing.md + 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: MintColors.info, size: 20),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Text(
                S.of(context)!.unemploymentHeaderDesc,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textSecondary,
                ).copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sliders ────────────────────────────────────────────────

  Widget _buildGainSlider() {
    return _buildSliderCard(
      title: S.of(context)!.unemploymentGainSliderTitle,
      valueLabel: UnemploymentService.formatChf(_gainAssure),
      minLabel: S.of(context)!.unemploymentGainMin,
      maxLabel: S.of(context)!.unemploymentGainMax,
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
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: MintPremiumSlider(
        label: title,
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        formatValue: (_) => valueLabel,
        onChanged: onChanged,
      ),
    );
  }

  // ── Toggles ────────────────────────────────────────────────

  Widget _buildToggles() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.unemploymentSituationTitle,
            style: MintTextStyles.titleMedium(
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.unemploymentSituationSubtitle,
            style: MintTextStyles.labelSmall(
              color: MintColors.textSecondary,
            ).copyWith(fontSize: 12),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildToggleRow(
            icon: Icons.child_care,
            label: S.of(context)!.unemploymentChildrenToggle,
            value: _hasChildren,
            onChanged: (v) {
              _hasChildren = v;
              _calculate();
            },
          ),
          const SizedBox(height: MintSpacing.sm + 4),
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
    return Semantics(
      label: label,
      toggled: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: MintColors.textMuted),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodyMedium(
                color: MintColors.textPrimary,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: MintColors.primary,
          ),
        ],
      ),
    );
  }

  // ── Not Eligible ───────────────────────────────────────────

  Widget _buildNotEligible() {
    return MintSurface(
      tone: MintSurfaceTone.peche,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: MintColors.warning, size: 24),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.unemploymentNotEligible,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  _result!.raisonNonEligible ?? '',
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textSecondary,
                  ).copyWith(height: 1.5),
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
    return MintResultHeroCard(
      eyebrow: S.of(context)!.unemploymentTitle,
      primaryValue: UnemploymentService.formatChf(r.perteMensuelle),
      primaryLabel: S.of(context)!.unemploymentMonthlyBenefit,
      secondaryValue: UnemploymentService.formatChf(r.indemniteMensuelle),
      secondaryLabel: S.of(context)!.unemploymentInsuredEarnings,
      narrative: r.chiffreChoc,
      accentColor: MintColors.error,
      tone: MintSurfaceTone.peche,
    );
  }

  // ── Taux Card ──────────────────────────────────────────────

  Widget _buildTauxCard() {
    final r = _result!;
    final tauxPct = (r.tauxIndemnite * 100).toStringAsFixed(0);
    final isEnhanced = r.tauxIndemnite == 0.80;

    return Semantics(
      label: '${S.of(context)!.unemploymentCompensationRate}\u00a0: $tauxPct%',
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
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
                '$tauxPct\u00a0%',
                style: MintTextStyles.headlineMedium(
                  color: isEnhanced ? MintColors.success : MintColors.info,
                ),
              ),
            ),
            const SizedBox(width: MintSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context)!.unemploymentCompensationRate,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    isEnhanced
                        ? S.of(context)!.unemploymentRateEnhanced
                        : S.of(context)!.unemploymentRateStandard,
                    style: MintTextStyles.labelSmall(
                      color: MintColors.textSecondary,
                    ).copyWith(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.unemploymentMonthlyBenefit,
                UnemploymentService.formatChf(r.indemniteMensuelle),
                Icons.calendar_month_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.unemploymentInsuredEarnings,
                UnemploymentService.formatChf(r.gainAssureRetenu),
                Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: MintSpacing.sm + 4),
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
    return Semantics(
      label: '$label\u00a0: $value',
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: MintColors.textMuted),
            const SizedBox(height: MintSpacing.sm),
            Text(
              value,
              style: MintTextStyles.headlineMedium(
                color: MintColors.textPrimary,
              ).copyWith(fontSize: small ? 14 : 18),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              label,
              style: MintTextStyles.labelSmall(
                color: MintColors.textSecondary,
              ).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ── Duration Card ──────────────────────────────────────────

  Widget _buildDurationCard() {
    final r = _result!;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.unemploymentDurationHeader,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: MintSpacing.md),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: '${r.nombreIndemnites} ${S.of(context)!.unemploymentDailyBenefits}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.nombreIndemnites}',
                        style: MintTextStyles.displayMedium(
                          color: MintColors.primary,
                        ),
                      ),
                      Text(
                        S.of(context)!.unemploymentDailyBenefits,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: MintColors.border,
              ),
              const SizedBox(width: MintSpacing.md + 4),
              Expanded(
                child: Semantics(
                  label: '~${r.dureeMois.toStringAsFixed(0)} ${S.of(context)!.unemploymentCoverageMonths}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '~${r.dureeMois.toStringAsFixed(0)}',
                        style: MintTextStyles.displayMedium(
                          color: MintColors.primary,
                        ),
                      ),
                      Text(
                        S.of(context)!.unemploymentCoverageMonths,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          _buildDurationTable(),
        ],
      ),
    );
  }

  Widget _buildDurationTable() {
    // Source : LACI art. 27 al. 2 — durées maximales d'indemnités
    // Miroir de social_insurance.dart (acJoursMinCotisation, acJoursStandard, acJoursSenior)
    final l10n = S.of(context)!;
    final brackets = [
      (l10n.unemploymentBracket1, l10n.unemploymentBracket1Value, _moisCotisation >= 12 && _moisCotisation < 18),
      (l10n.unemploymentBracket2, l10n.unemploymentBracket2Value, _moisCotisation >= 18 && _moisCotisation < 22),
      (l10n.unemploymentBracket3(acAgeSeuillSenior), l10n.unemploymentBracket3Value, _moisCotisation >= 22 && _age < acAgeSeuillSenior),
      (l10n.unemploymentBracket4(acAgeSeuillSenior), l10n.unemploymentBracket4Value, _moisCotisation >= 22 && _age >= acAgeSeuillSenior),
    ];

    return Column(
      children: brackets.map((b) {
        final isCurrent = b.$3;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm + 4, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent
                ? MintColors.primary.withValues(alpha: 0.06)
                : MintColors.transparent,
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
                      margin: const EdgeInsets.only(right: MintSpacing.sm),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: MintColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        S.of(context)!.unemploymentYouTag,
                        style: MintTextStyles.labelSmall(
                          color: MintColors.white,
                        ).copyWith(fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  Text(
                    b.$1,
                    style: MintTextStyles.labelSmall(
                      color: isCurrent
                          ? MintColors.textPrimary
                          : MintColors.textSecondary,
                    ).copyWith(
                      fontSize: 12,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              Text(
                b.$2,
                style: MintTextStyles.labelSmall(
                  color: isCurrent
                      ? MintColors.primary
                      : MintColors.textSecondary,
                ).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
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

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.unemploymentChecklistHeader,
            style: MintTextStyles.labelSmall(
              color: MintColors.textMuted,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: MintSpacing.md),
          ...List.generate(items.length, (index) {
            final checked = _checkedItems.contains(index);
            return Semantics(
              label: items[index],
              toggled: checked,
              child: GestureDetector(
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
                            : MintColors.transparent,
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
                    const SizedBox(width: MintSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        items[index],
                        style: MintTextStyles.bodyMedium(
                          color: checked
                              ? MintColors.textMuted
                              : MintColors.textPrimary,
                        ).copyWith(
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
            const SizedBox(width: MintSpacing.sm),
            Text(
              S.of(context)!.unemploymentGoodToKnow,
              style: MintTextStyles.labelSmall(
                color: MintColors.textMuted,
              ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),
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
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
      child: MintSurface(
        tone: MintSurfaceTone.bleu,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: MintColors.primary),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    body,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ).copyWith(height: 1.5),
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

  Widget _buildTroisVagues() {
    final l10n = S.of(context)!;
    final vagues = [
      (
        label: l10n.unemploymentVague1Label,
        color: MintColors.info,
        text: l10n.unemploymentVague1Text,
      ),
      (
        label: l10n.unemploymentVague2Label,
        color: MintColors.warning,
        text: l10n.unemploymentVague2Text,
      ),
      (
        label: l10n.unemploymentVague3Label,
        color: MintColors.error,
        text: l10n.unemploymentVague3Text,
      ),
    ];

    return MintSurface(
      tone: MintSurfaceTone.bleu,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(MintSpacing.md, MintSpacing.md, MintSpacing.md, MintSpacing.sm + 4),
            child: Row(
              children: [
                const Icon(Icons.waves, size: 22, color: MintColors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.unemploymentTsunamiTitle,
                    style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...vagues.map(
            (v) => Padding(
              padding: const EdgeInsets.fromLTRB(MintSpacing.md, MintSpacing.sm + 4, MintSpacing.md, MintSpacing.xs),
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
                  const SizedBox(width: MintSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.label,
                          style: MintTextStyles.bodySmall(
                            color: v.color,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: MintSpacing.xs),
                        Text(
                          v.text,
                          style: MintTextStyles.labelSmall(
                            color: MintColors.textSecondary,
                          ).copyWith(fontSize: 12, height: 1.5),
                        ),
                        const SizedBox(height: MintSpacing.sm),
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
    final l10n = S.of(context)!;
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
          label: l10n.unemploymentBudgetLoyer,
          emoji: '🏠',
          normalAmount: loyer,
          survivalAmount: loyer, // incompressible
          status: BudgetLineStatus.locked,
        ),
        BudgetLine(
          label: l10n.unemploymentBudgetLamal,
          emoji: '🏥',
          normalAmount: lamal,
          survivalAmount: lamal, // incompressible
          status: BudgetLineStatus.locked,
        ),
        BudgetLine(
          label: l10n.unemploymentBudgetTransport,
          emoji: '🚌',
          normalAmount: transport,
          survivalAmount: (transport * 0.50).roundToDouble(),
          status: BudgetLineStatus.cut,
        ),
        BudgetLine(
          label: l10n.unemploymentBudgetLoisirs,
          emoji: '🎭',
          normalAmount: loisirs,
          survivalAmount: (loisirs * 0.125).roundToDouble(),
          status: BudgetLineStatus.cut,
        ),
        BudgetLine(
          label: l10n.unemploymentBudgetEpargne3a,
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
    return Semantics(
      label: S.of(context)!.unemploymentDisclaimer,
      child: MintSurface(
        tone: MintSurfaceTone.peche,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: MintColors.corailDiscret, size: 18),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Text(
                S.of(context)!.unemploymentDisclaimer,
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
}
