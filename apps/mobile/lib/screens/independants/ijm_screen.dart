import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/independants_service.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

class IjmScreen extends StatefulWidget {
  const IjmScreen({super.key});

  @override
  State<IjmScreen> createState() => _IjmScreenState();
}

class _IjmScreenState extends State<IjmScreen> {
  double _revenuMensuel = 6000;
  int _age = 40;
  int _delaiCarence = 30;
  IjmResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
    });
    _calculate();
  }

  void _initializeFromProfile() {
    try {
      final profile = context.read<CoachProfileProvider>().profile;
      if (profile == null) return;
      bool changed = false;
      if (profile.salaireBrutMensuel > 0) {
        _revenuMensuel = profile.salaireBrutMensuel.clamp(0, 20000);
        changed = true;
      }
      final age = profile.age;
      if (age >= 18 && age <= 65) {
        _age = age;
        changed = true;
      }
      if (changed) _calculate();
    } catch (_) {
      // Provider not available
    }
  }

  void _calculate() {
    setState(() {
      _result = IndependantsService.calculateIjm(_revenuMensuel, _age, _delaiCarence);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(s.ijmTitle, style: MintTextStyles.headlineMedium()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: MintSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MintEntrance(child: _buildHeader(s)),
            const SizedBox(height: MintSpacing.xl),
            MintEntrance(delay: Duration(milliseconds: 100), child: _buildSliderCard(title: s.ijmRevenuMensuel, valueLabel: IndependantsService.formatChf(_revenuMensuel), minLabel: s.ijmSliderMinChf0, maxLabel: s.ijmSliderMax20k, value: _revenuMensuel, min: 0, max: 20000, divisions: 200, onChanged: (v) { _revenuMensuel = v; _calculate(); })),
            const SizedBox(height: MintSpacing.md + 4),
            MintEntrance(delay: Duration(milliseconds: 200), child: _buildSliderCard(title: s.ijmTonAge, valueLabel: '$_age ans', minLabel: s.ijmAgeMin, maxLabel: s.ijmAgeMax, value: _age.toDouble(), min: 18, max: 65, divisions: 47, onChanged: (v) { _age = v.toInt(); _calculate(); })),
            const SizedBox(height: MintSpacing.md + 4),
            MintEntrance(delay: Duration(milliseconds: 300), child: _buildCarenceToggle(s)),
            const SizedBox(height: MintSpacing.lg),
            if (_result != null) ...[
              _buildChiffreChoc(s),
              const SizedBox(height: MintSpacing.lg),
              if (_result!.isHighRisk) ...[
                _buildHighRiskWarning(s),
                const SizedBox(height: MintSpacing.md + 4),
              ],
              _buildResultCards(s),
              const SizedBox(height: MintSpacing.lg),
              _buildCoverageTimeline(s),
              const SizedBox(height: MintSpacing.lg),
              _buildEducation(s),
              const SizedBox(height: MintSpacing.lg),
            ],
            MintEntrance(delay: Duration(milliseconds: 400), child: _buildDisclaimer(s)),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(S s) {
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
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(child: Text(s.ijmHeaderInfo, style: MintTextStyles.bodySmall(color: MintColors.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildSliderCard({required String title, required String valueLabel, required String minLabel, required String maxLabel, required double value, required double min, required double max, required int divisions, required ValueChanged<double> onChanged}) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
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

  Widget _buildCarenceToggle(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.ijmDelaiCarence, style: MintTextStyles.titleMedium()),
          const SizedBox(height: MintSpacing.xs),
          Text(s.ijmDelaiCarenceDesc, style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
          const SizedBox(height: MintSpacing.md),
          Row(
            children: [
              _buildCarenceChip(s, 30),
              const SizedBox(width: MintSpacing.sm),
              _buildCarenceChip(s, 60),
              const SizedBox(width: MintSpacing.sm),
              _buildCarenceChip(s, 90),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarenceChip(S s, int jours) {
    final isSelected = _delaiCarence == jours;
    return Expanded(
      child: Semantics(
        label: s.ijmJoursCarenceLabel(jours),
        button: true,
        selected: isSelected,
        child: GestureDetector(
          onTap: () { _delaiCarence = jours; _calculate(); },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? MintColors.primary : MintColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? MintColors.primary : MintColors.border, width: isSelected ? 2 : 1),
            ),
            child: Column(
              children: [
                Text('$jours j', style: MintTextStyles.titleMedium(color: isSelected ? MintColors.white : MintColors.textPrimary).copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: MintSpacing.xs / 2),
                Text(s.ijmJours, style: MintTextStyles.labelSmall(color: isSelected ? MintColors.white.withValues(alpha: 0.8) : MintColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChiffreChoc(S s) {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(color: MintColors.error, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(IndependantsService.formatChf(r.perteCarence), style: MintTextStyles.displayMedium(color: MintColors.white)),
          const SizedBox(height: MintSpacing.sm),
          Text(s.ijmChiffreChocCaption(IndependantsService.formatChf(r.perteCarence), r.delaiCarence), style: MintTextStyles.bodyMedium(color: MintColors.white.withValues(alpha: 0.9)), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHighRiskWarning(S s) {
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
          const Icon(Icons.warning_amber_rounded, color: MintColors.warning, size: 22),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.ijmHighRiskTitle, style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: MintSpacing.xs),
                Text(s.ijmHighRiskBody, style: MintTextStyles.bodySmall(color: MintColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCards(S s) {
    final r = _result!;
    return Column(
      children: [
        Row(children: [
          Expanded(child: _buildResultCard(s.ijmPrimeMois, IndependantsService.formatChf(r.primeMensuelle), Icons.payment_outlined)),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(child: _buildResultCard(s.ijmPrimeAn, IndependantsService.formatChf(r.primeAnnuelle), Icons.calendar_month_outlined)),
        ]),
        const SizedBox(height: MintSpacing.sm + 4),
        Row(children: [
          Expanded(child: _buildResultCard(s.ijmIndemniteJour, IndependantsService.formatChf(r.indemniteJournaliere), Icons.today_outlined)),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(child: _buildResultCard(s.ijmTrancheAge, r.ageBandLabel, Icons.person_outline, small: true)),
        ]),
      ],
    );
  }

  Widget _buildResultCard(String label, String value, IconData icon, {bool small = false}) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(color: MintColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: MintColors.border.withValues(alpha: 0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: MintColors.textMuted),
          const SizedBox(height: MintSpacing.sm),
          Text(value, style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: small ? 14 : 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: MintSpacing.xs),
          Text(label, style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCoverageTimeline(S s) {
    final r = _result!;
    const totalDays = 180;
    final carenceRatio = r.delaiCarence / totalDays;
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(color: MintColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: MintColors.border.withValues(alpha: 0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.ijmTimelineTitle, style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: MintSpacing.md + 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(children: [
              Expanded(
                flex: (carenceRatio * 100).toInt().clamp(1, 99),
                child: Container(height: 32, color: MintColors.error.withValues(alpha: 0.2), alignment: Alignment.center, child: Text('${r.delaiCarence}j', style: MintTextStyles.labelSmall(color: MintColors.error).copyWith(fontWeight: FontWeight.w600))),
              ),
              Expanded(
                flex: (100 - carenceRatio * 100).toInt().clamp(1, 99),
                child: Container(height: 32, color: MintColors.success.withValues(alpha: 0.2), alignment: Alignment.center, child: Text(s.ijmTimelineCouvert, style: MintTextStyles.labelSmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600))),
              ),
            ]),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Row(children: [
            _buildLegendDot(MintColors.error, s.ijmTimelineNoCoverage),
            const SizedBox(width: MintSpacing.md),
            _buildLegendDot(MintColors.success, s.ijmTimelineCoverageIjm),
          ]),
          const SizedBox(height: MintSpacing.md),
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            decoration: BoxDecoration(color: MintColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Text(s.ijmTimelineSummary(r.delaiCarence, IndependantsService.formatChf(r.indemniteJournaliere)), style: MintTextStyles.bodySmall(color: MintColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color.withValues(alpha: 0.3), shape: BoxShape.circle, border: Border.all(color: color, width: 1.5))),
      const SizedBox(width: MintSpacing.xs + 2),
      Text(label, style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
    ]);
  }

  Widget _buildEducation(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.ijmStrategies, style: MintTextStyles.bodySmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildEduCard(Icons.savings_outlined, s.ijmEduFondsTitle, s.ijmEduFondsBody),
        _buildEduCard(Icons.compare_arrows, s.ijmEduComparerTitle, s.ijmEduComparerBody),
        _buildEduCard(Icons.shield_outlined, s.ijmEduLamalTitle, s.ijmEduLamalBody),
      ],
    );
  }

  Widget _buildEduCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(color: MintColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(MintSpacing.sm), decoration: BoxDecoration(color: MintColors.white, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: MintColors.primary)),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: MintSpacing.xs),
                Text(body, style: MintTextStyles.bodySmall(color: MintColors.textSecondary)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer(S s) {
    return Text(s.ijmDisclaimer, style: MintTextStyles.micro());
  }
}
