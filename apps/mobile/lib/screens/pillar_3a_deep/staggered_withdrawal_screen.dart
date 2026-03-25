import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/pillar_3a_deep_service.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/models/screen_return.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Ecran de simulation du retrait 3a echelonne multi-comptes.
///
/// Permet de comparer l'impot en bloc vs echelonne et d'identifier
/// le nombre optimal de comptes 3a.
/// Base legale : OPP3, LIFD art. 38.
class StaggeredWithdrawalScreen extends StatefulWidget {
  const StaggeredWithdrawalScreen({super.key});

  @override
  State<StaggeredWithdrawalScreen> createState() =>
      _StaggeredWithdrawalScreenState();
}

class _StaggeredWithdrawalScreenState extends State<StaggeredWithdrawalScreen> {
  double _avoirTotal = 300000;
  int _nbComptes = 3;
  String _canton = 'VD';
  double _revenuImposable = 120000;
  int _ageRetraitDebut = 60;
  int _ageRetraitFin = 64;

  @override
  void initState() {
    super.initState();
    _emitScreenReturn();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
    });
  }

  void _initializeFromProfile() {
    try {
      final provider = context.read<CoachProfileProvider>();
      if (!provider.hasProfile) return;
      final profile = provider.profile!;
      setState(() {
        final avoir3a = profile.prevoyance.totalEpargne3a;
        if (avoir3a > 0) {
          _avoirTotal = avoir3a;
        }
        final nb3a = profile.prevoyance.nombre3a;
        if (nb3a > 0 && nb3a <= 5) {
          _nbComptes = nb3a;
        }
        if (cantonFullNames.containsKey(profile.canton)) {
          _canton = profile.canton;
        }
        final revenu = profile.revenuBrutAnnuel;
        if (revenu > 0) {
          _revenuImposable = revenu;
        }
        final targetAge = profile.targetRetirementAge ?? 65;
        // Withdrawal typically starts 5 years before retirement
        final computedDebut = (targetAge - 5).clamp(60, 65);
        _ageRetraitDebut = computedDebut;
        _ageRetraitFin = targetAge.clamp(computedDebut, 65);
      });
    } catch (_) {
      // Provider not in tree (tests) — keep defaults
    }
  }

  StaggeredWithdrawalResult get _result =>
      StaggeredWithdrawalSimulator.simulate(
        avoirTotal: _avoirTotal,
        nbComptes: _nbComptes,
        canton: _canton,
        revenuImposable: _revenuImposable,
        ageRetraitDebut: _ageRetraitDebut,
        ageRetraitFin: _ageRetraitFin,
      );

  // _emitScreenReturn is called from primary initState above
  // (merged with profile initialization)

  void _emitScreenReturn() {
    final plan = '${_nbComptes}x_$_ageRetraitDebut-$_ageRetraitFin';
    final screenReturn = ScreenReturn.changedInputs(
      route: '/3a-deep/staggered-withdrawal',
      updatedFields: {'staggeredPlan': plan},
      confidenceDelta: 0.03,
    );
    ScreenCompletionTracker.markCompletedWithReturn(
      'staggered_withdrawal',
      screenReturn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.surface,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.white,
            surfaceTintColor: MintColors.white,
            foregroundColor: MintColors.textPrimary,
            title: Text(
              l.staggered3aTitle,
              style: MintTextStyles.headlineMedium(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(MintSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Chiffre choc
                _buildChiffreChoc(result, l),
                const SizedBox(height: MintSpacing.lg),

                // Introduction
                _buildIntroCard(l),
                const SizedBox(height: MintSpacing.lg),

                // Sliders
                _buildSlidersSection(l),
                const SizedBox(height: MintSpacing.lg),

                // Resultat comparaison
                _buildComparisonSection(result, l),
                const SizedBox(height: MintSpacing.lg),

                // Plan annuel
                if (result.planAnnuel.isNotEmpty) ...[
                  _buildYearlyPlanTable(result, l),
                  const SizedBox(height: MintSpacing.lg),
                ],

                // Disclaimer
                _buildDisclaimer(result.disclaimer),
                const SizedBox(height: MintSpacing.xxl),
              ]),
            ),
          ),
        ],
      ))),
    );
  }

  Widget _buildChiffreChoc(StaggeredWithdrawalResult result, S l) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: result.economie > 0
            ? MintColors.successBg
            : MintColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: result.economie > 0
              ? MintColors.greenLight
              : MintColors.orangeSpice,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            l.staggered3aEconomie,
            style: MintTextStyles.bodySmall(
              color: result.economie > 0
                  ? MintColors.greenForest
                  : MintColors.deepOrange,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            'CHF ${formatChf(result.economie)}',
            style: MintTextStyles.displayMedium(
              color: result.economie > 0
                  ? MintColors.greenDark
                  : MintColors.warning,
            ),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            '${l.staggered3aEconomie.toLowerCase()} — $_nbComptes ${l.staggered3aAns}',
            style: MintTextStyles.labelSmall(
              color: result.economie > 0
                  ? MintColors.categoryGreen
                  : MintColors.warning,
            ),
          ),
          if (result.nbComptesOptimal != _nbComptes) ...[
            const SizedBox(height: MintSpacing.sm),
            Text(
              '${result.nbComptesOptimal} comptes',
              style: MintTextStyles.labelSmall(color: MintColors.info).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntroCard(S l) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.staggered3aIntroTitle, style: MintTextStyles.titleMedium()),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l.staggered3aIntroBody,
            style: MintTextStyles.bodyMedium().copyWith(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidersSection(S l) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintEntrance(child: Text(l.staggered3aParametres, style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5))),
          const SizedBox(height: MintSpacing.md),

          MintEntrance(delay: const Duration(milliseconds: 100), child: _buildSliderRow(label: l.staggered3aAvoirTotal, value: _avoirTotal, min: 0, max: 1000000, divisions: 200, format: 'CHF ${formatChf(_avoirTotal)}', onChanged: (v) => setState(() => _avoirTotal = v))),
          const SizedBox(height: MintSpacing.sm + 4),

          MintEntrance(delay: const Duration(milliseconds: 200), child: _buildSliderRow(label: l.staggered3aNbComptes, value: _nbComptes.toDouble(), min: 1, max: 5, divisions: 4, format: '$_nbComptes', onChanged: (v) { setState(() => _nbComptes = v.round()); _emitScreenReturn(); })),
          const SizedBox(height: MintSpacing.sm + 4),

          MintEntrance(delay: const Duration(milliseconds: 300), child: _buildCantonDropdown(l)),
          const SizedBox(height: MintSpacing.sm + 4),

          MintEntrance(delay: const Duration(milliseconds: 400), child: _buildSliderRow(label: l.staggered3aRevenuImposable, value: _revenuImposable, min: 30000, max: 300000, divisions: 54, format: 'CHF ${formatChf(_revenuImposable)}', onChanged: (v) => setState(() => _revenuImposable = v))),
          const SizedBox(height: MintSpacing.sm + 4),

          _buildSliderRow(label: l.staggered3aAgeDebut, value: _ageRetraitDebut.toDouble(), min: 60, max: 65, divisions: 5, format: '$_ageRetraitDebut ${l.staggered3aAns}', onChanged: (v) { setState(() { _ageRetraitDebut = v.round(); if (_ageRetraitFin < _ageRetraitDebut) _ageRetraitFin = _ageRetraitDebut; }); _emitScreenReturn(); }),
          const SizedBox(height: MintSpacing.sm + 4),

          _buildSliderRow(label: l.staggered3aAgeFin, value: _ageRetraitFin.toDouble(), min: _ageRetraitDebut.toDouble(), max: 65, divisions: (65 - _ageRetraitDebut).clamp(1, 6), format: '$_ageRetraitFin ${l.staggered3aAns}', onChanged: (v) { setState(() => _ageRetraitFin = v.round()); _emitScreenReturn(); }),
        ],
      ),
    );
  }

  Widget _buildCantonDropdown(S l) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l.staggered3aCanton, style: MintTextStyles.bodySmall(color: MintColors.textPrimary)),
        Semantics(
          label: l.staggered3aCanton,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: MintColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _canton,
                isDense: true,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                items: StaggeredWithdrawalSimulator.cantons
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _canton = v);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String format,
    required ValueChanged<double> onChanged,
  }) {
    return MintPremiumSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      formatValue: (_) => format,
      onChanged: onChanged,
    );
  }

  Widget _buildComparisonSection(StaggeredWithdrawalResult result, S l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.staggered3aResultat, style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: MintSpacing.sm + 4),
        Row(
          children: [
            Expanded(child: _buildComparisonCard(title: l.staggered3aEnBloc, subtitle: l.staggered3aRetraitUnique, amount: result.impotBloc, color: MintColors.warning, isWinner: false)),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(child: _buildComparisonCard(title: l.staggered3aEchelonneLabel, subtitle: '$_nbComptes ${l.staggered3aRetrait.toLowerCase()}s', amount: result.impotEchelonne, color: MintColors.success, isWinner: result.economie > 0)),
          ],
        ),
        if (result.economie > 0) ...[
          const SizedBox(height: MintSpacing.sm + 4),
          Container(
            padding: const EdgeInsets.all(MintSpacing.md),
            decoration: BoxDecoration(
              color: MintColors.successBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.greenLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings, color: MintColors.greenDark, size: 24),
                const SizedBox(width: MintSpacing.sm + 4),
                Expanded(
                  child: Text(
                    'CHF ${formatChf(result.economie)}',
                    style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w600, color: MintColors.greenForest),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required String subtitle,
    required double amount,
    required Color color,
    required bool isWinner,
  }) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: MintSpacing.xs),
          Text(subtitle, style: MintTextStyles.bodyMedium().copyWith(fontSize: 12)),
          const SizedBox(height: MintSpacing.sm + 4),
          Text('CHF ${formatChf(amount)}', style: MintTextStyles.displayMedium(color: color).copyWith(fontSize: 22)),
          const SizedBox(height: MintSpacing.xs),
          Text(S.of(context)!.staggered3aImpotEstime, style: MintTextStyles.labelSmall()),
        ],
      ),
    );
  }

  Widget _buildYearlyPlanTable(StaggeredWithdrawalResult result, S l) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.staggered3aPlanAnnuel, style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: MintSpacing.md),

          Row(
            children: [
              SizedBox(width: 40, child: Text(l.staggered3aAge, style: MintTextStyles.labelSmall().copyWith(fontWeight: FontWeight.bold))),
              Expanded(child: Text(l.staggered3aRetrait, style: MintTextStyles.labelSmall().copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              Expanded(child: Text(l.staggered3aImpot, style: MintTextStyles.labelSmall().copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              Expanded(child: Text(l.staggered3aNet, style: MintTextStyles.labelSmall().copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
            ],
          ),
          const Divider(height: MintSpacing.md),

          for (final year in result.planAnnuel)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 40, child: Text('${year.ageRetrait}', style: MintTextStyles.bodyMedium().copyWith(fontSize: 12))),
                  Expanded(child: Text('CHF ${formatChf(year.montantRetire)}', style: MintTextStyles.bodyMedium().copyWith(fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(child: Text('CHF ${formatChf(year.impotEstime)}', style: MintTextStyles.bodyMedium().copyWith(fontSize: 12, color: MintColors.error, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                  Expanded(child: Text('CHF ${formatChf(year.montantNet)}', style: MintTextStyles.bodyMedium().copyWith(fontSize: 12, color: MintColors.greenDark, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                ],
              ),
            ),

          const Divider(height: MintSpacing.md),

          Row(
            children: [
              SizedBox(width: 40, child: Text(l.staggered3aTotal, style: MintTextStyles.bodyMedium().copyWith(fontSize: 12, fontWeight: FontWeight.bold))),
              Expanded(child: Text('CHF ${formatChf(_avoirTotal)}', style: MintTextStyles.bodyMedium().copyWith(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              Expanded(child: Text('CHF ${formatChf(result.impotEchelonne)}', style: MintTextStyles.bodyMedium().copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: MintColors.error), textAlign: TextAlign.right)),
              Expanded(child: Text('CHF ${formatChf(_avoirTotal - result.impotEchelonne)}', style: MintTextStyles.bodyMedium().copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: MintColors.greenDark), textAlign: TextAlign.right)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(disclaimer, style: MintTextStyles.micro(color: MintColors.deepOrange).copyWith(height: 1.4)),
          ),
        ],
      ),
    );
  }
}
